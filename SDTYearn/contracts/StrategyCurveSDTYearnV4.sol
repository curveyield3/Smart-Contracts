// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StrategyCurveSDTYearnV4
 * @notice SDT -> Curve SDT/WETH LP -> constructor-selected Yearn ERC4626 vault.
 * @dev Compatible with the UNMODIFIED BeefyVaultV7FixedV2 (BoostHub v57).
 *
 * Strategy fee routing: deploy the original vault with _adminFeeReceiver set
 * to THIS strategy, and a withdrawal fee of 50 bps. The original vault sends
 * 30% of each nonfinal fee here and calls lockVaultProfit() with the other 70%.
 * This strategy then pays 10% of the TOTAL withdrawal fee to realAdminReceiver,
 * reserving the remaining 90% for future conversion-loss coverage. No vault
 * code modification is required.
 *
 * On the last share withdrawal, the original vault pays 100% of the fee to the
 * configured fee receiver and calls no hook. The strategy records this pending
 * final fee, from which 10% is paid to the real administrator on permissionless
 * settlement. The other 90% remains in the excluded conversion reserve.
 * A subsequent new-cycle deposit first settles the pending final fee.
 *
 * This strategy charges a dynamic reserve fee on incoming deposits and
 * applies that non-NAV reserve against the cost of future withdrawals. It also
 * recycles all but 10% of the original vault withdrawal tax through its fee
 * receiver callback. The original vault's user payout remains immutable; this
 * extra charge is collected on deposits, NOT deducted from withdrawing users.
 * Yearn illiquidity or losses exceeding the reserve can still prevent settlement
 * or reduce PPS. There is no discretionary PPS-loss revert in this strategy.
 */

import "@openzeppelin-4/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-4/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin-4/contracts/utils/math/Math.sol";

interface ICurveSDTWethV4 {
    function coins(uint256 i) external view returns (address);
    function calc_token_amount(uint256[2] calldata amounts, bool deposit) external view returns (uint256);
    function calc_withdraw_one_coin(uint256 tokenAmount, uint256 i) external view returns (uint256);
    function add_liquidity(uint256[2] calldata amounts, uint256 minMintAmount) external returns (uint256);
    function remove_liquidity_one_coin(uint256 tokenAmount, uint256 i, uint256 minAmount) external returns (uint256);
}

interface IYearnCurveLPV4 is IERC20 {
    function asset() external view returns (address);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
}

interface IBeefyVaultUnmodifiedV57 {
    function balance() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function withdrawalFeeBps() external view returns (uint256);
    function ADMIN_FEE_SHARE_BPS() external view returns (uint256);
    function adminFeeReceiver() external view returns (address);
    function underlying() external view returns (address);
    function strategy() external view returns (address);
}

contract StrategyCurveSDTYearnV4 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public constant CURVE_POOL = 0xA19bf6fBf05624282cb6ed498f4761f22e084Edd;
    address public constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 public constant MIN_VAULT_WITHDRAWAL_FEE_BPS = 50; // 0.50% at vault construction
    uint256 public constant REAL_ADMIN_SHARE_BPS = 1_000;      // 10% of whole fee
    uint256 public constant VAULT_ADMIN_SHARE_BPS = 3_000;     // Original vault's internal split
    uint256 private constant BPS = 10_000;
    uint256 private constant SDT_INDEX = 1;
    uint256 private constant DEPOSIT_QUOTE_TOLERANCE_BPS = 10;
    uint256 private constant LP_SEARCH_STEPS = 32;
    uint256 public constant MIN_STRATEGY_RESERVE_BPS = 10; // 0.10%
    uint256 public constant RESERVE_QUOTE_MARGIN_BPS = 5; // 0.05%

    address public immutable vault;
    address public immutable want;
    address public immutable realAdminReceiver;
    IBeefyVaultUnmodifiedV57 public immutable parent;
    ICurveSDTWethV4 public immutable curve;
    IYearnCurveLPV4 public immutable yearn;
    IERC20 private immutable sdt;
    IERC20 private immutable lp;

    // Recorded only when the original vault has already burned the last shares;
    // its full final fee is transferred to this strategy AFTER withdraw() returns.
    uint256 public pendingFinalFee;
    // Separate from Beefy NAV; funded by a dynamic strategy entry charge.
    uint256 public reserveSDT;
    uint256 public unrecoveredCost;
    // Ordinary strategy.withdraw() is followed atomically by lockVaultProfit().
    // For idle-only vault withdrawals, the strategy has no advance callback.
    uint256 private pendingOrdinaryFee;
    bool private pendingOrdinary;

    event Invested(uint256 sdtIn, uint256 curveLpMinted, uint256 yearnSharesMinted);
    event Redeemed(uint256 sdtRequested, uint256 sdtReturned, uint256 curveLpBurned, uint256 yearnSharesBurned);
    event WithdrawalFeeRecycled(uint256 totalFee, uint256 realAdminFee, uint256 retainedAsStrategyAssets);
    event FinalWithdrawalFeeSettled(uint256 paidToAdmin);
    event StrategyReserveFeeCharged(uint256 deposit, uint256 fee);
    event ReserveApplied(uint256 amount);
    event UncoveredConversionCost(uint256 amount);
    event FeeReceiverMisconfigured(address feeReceiver);

    error NotVault();
    error InvalidDependency();
    error InsufficientLiquidity();
    error OutputBelowQuote();

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault();
        _;
    }

    /**
     * @param parentVault_ Precomputed CREATE2 or nonce-derived address of ORIGINAL vault.
     * @param yearnVault_ Yearn ERC4626 vault holding the exact Curve SDT/WETH LP.
     * @param realAdmin_ Actual treasury fee recipient (distinct from this strategy).
     */
    constructor(address parentVault_, address yearnVault_, address realAdmin_) {
        if (block.chainid != 1 || parentVault_ == address(0) || yearnVault_.code.length == 0 ||
            realAdmin_ == address(0) || realAdmin_ == parentVault_ || realAdmin_ == address(this)) {
            revert InvalidDependency();
        }
        if (CURVE_POOL.code.length == 0) revert InvalidDependency();
        ICurveSDTWethV4 pool = ICurveSDTWethV4(CURVE_POOL);
        if (pool.coins(0) != WETH || pool.coins(SDT_INDEX) != SDT) revert InvalidDependency();
        if (IYearnCurveLPV4(yearnVault_).asset() != CURVE_POOL) revert InvalidDependency();

        vault = parentVault_;
        want = SDT;
        realAdminReceiver = realAdmin_;
        parent = IBeefyVaultUnmodifiedV57(parentVault_);
        curve = pool;
        yearn = IYearnCurveLPV4(yearnVault_);
        sdt = IERC20(SDT);
        lp = IERC20(CURVE_POOL);
        sdt.forceApprove(CURVE_POOL, type(uint256).max);
        lp.forceApprove(yearnVault_, type(uint256).max);
    }

    /**
     * @notice Reports whether the original vault is deployed with required fee routing.
     * @dev A misconfigured fee receiver no longer automatically freezes redemptions;
     *      the administered 30% would go elsewhere, leaving less subsidy for losses.
     */
    function feeRoutingConfigured() public view returns (bool) {
        if (vault.code.length == 0) return false;
        return parent.adminFeeReceiver() == address(this) &&
            parent.withdrawalFeeBps() >= MIN_VAULT_WITHDRAWAL_FEE_BPS &&
            parent.ADMIN_FEE_SHARE_BPS() == VAULT_ADMIN_SHARE_BPS &&
            parent.underlying() == SDT && parent.strategy() == address(this);
    }

    function _totalLp() private view returns (uint256) {
        uint256 shares = yearn.balanceOf(address(this));
        return lp.balanceOf(address(this)) + (shares == 0 ? 0 : yearn.previewRedeem(shares));
    }

    /** @notice SDT redeemable at live Curve exit quote, net of Curve's exit fee. */
    function redeemableSDT() public view returns (uint256) {
        uint256 lpTotal = _totalLp();
        return sdt.balanceOf(address(this)) +
            (lpTotal == 0 ? 0 : curve.calc_withdraw_one_coin(lpTotal, SDT_INDEX));
    }

    /** @notice SDT value net of Curve exit conversion costs and reserved fees. */
    function balanceOf() public view returns (uint256) {
        uint256 held = sdt.balanceOf(address(this));
        uint256 excluded = reserveSDT + pendingFinalFee;
        uint256 managed = held > excluded ? held - excluded : 0;
        uint256 lpTotal = _totalLp();
        return managed + (lpTotal == 0 ? 0 : curve.calc_withdraw_one_coin(lpTotal, SDT_INDEX));
    }

    /**
     * @notice Additional strategy fee reserved at deposit to protect later exits.
     * @dev Two quotes against the current state are only an estimate; this does
     *      NOT guarantee future Yearn/Curve execution or an upper bound on loss.
     */
    function strategyReserveFee(uint256 inputSDT) public view returns (uint256) {
        if (inputSDT == 0) return 0;
        uint256[2] memory amounts = [uint256(0), inputSDT];
        uint256 quotedLp = curve.calc_token_amount(amounts, true);
        uint256 quotedSDT = quotedLp == 0 ? 0 : curve.calc_withdraw_one_coin(quotedLp, SDT_INDEX);
        uint256 loss = inputSDT > quotedSDT ? inputSDT - quotedSDT : 0;
        uint256 fee = loss + Math.mulDiv(inputSDT, RESERVE_QUOTE_MARGIN_BPS, BPS);
        uint256 floorFee = Math.mulDiv(inputSDT, MIN_STRATEGY_RESERVE_BPS, BPS);
        if (fee < floorFee) fee = floorFee;
        return fee >= inputSDT ? inputSDT - 1 : fee;
    }

    /** @notice Pay only 10% of the original final fee to actual admin. */
    function settleFinalFee() external nonReentrant {
        if (parent.totalSupply() != 0) return;
        _settleFinalFee();
    }

    function _settleFinalFee() private {
        uint256 fee = pendingFinalFee;
        if (fee == 0) return;
        uint256 idle = sdt.balanceOf(address(this));
        uint256 available = idle > reserveSDT ? idle - reserveSDT : 0;
        if (fee > available) fee = available;
        pendingFinalFee -= fee;
        uint256 adminCut = Math.mulDiv(fee, REAL_ADMIN_SHARE_BPS, BPS);
        if (adminCut != 0) sdt.safeTransfer(realAdminReceiver, adminCut);
        reserveSDT += fee - adminCut;
        emit FinalWithdrawalFeeSettled(adminCut);
    }

    function deposit() external onlyVault nonReentrant {
        // On the first mint of a new cycle, the original vault still has no shares.
        if (parent.totalSupply() == 0) _settleFinalFee();
        uint256 held = sdt.balanceOf(address(this));
        uint256 excluded = reserveSDT + pendingFinalFee;
        if (held <= excluded) return;
        uint256 freshSDT = held - excluded;
        uint256 levy = strategyReserveFee(freshSDT);
        if (levy != 0) {
            reserveSDT += levy;
            emit StrategyReserveFeeCharged(freshSDT, levy);
        }
        uint256 invest = freshSDT - levy;
        if (invest == 0) return;
        uint256[2] memory amounts = [uint256(0), invest];
        uint256 quote = curve.calc_token_amount(amounts, true);
        if (quote == 0) revert OutputBelowQuote();
        uint256 minLp = Math.mulDiv(quote, BPS - DEPOSIT_QUOTE_TOLERANCE_BPS, BPS);
        uint256 lpBefore = lp.balanceOf(address(this));
        curve.add_liquidity(amounts, minLp);
        uint256 received = lp.balanceOf(address(this)) - lpBefore;
        if (received == 0 || received < minLp) revert OutputBelowQuote();
        uint256 beforeShares = yearn.balanceOf(address(this));
        yearn.deposit(received, address(this));
        uint256 newShares = yearn.balanceOf(address(this)) - beforeShares;
        if (newShares == 0) revert OutputBelowQuote();
        emit Invested(invest, received, newShares);
    }

    /** @dev Binary search LP needed to cover an exact gross SDT request at Curve quote. */
    function _lpForSdt(uint256 amount, uint256 maxLp) private view returns (uint256) {
        if (maxLp == 0 || curve.calc_withdraw_one_coin(maxLp, SDT_INDEX) < amount) {
            revert InsufficientLiquidity();
        }
        uint256 lo;
        uint256 hi = maxLp;
        for (uint256 i; i < LP_SEARCH_STEPS && hi - lo > 1; ++i) {
            uint256 mid = lo + (hi - lo) / 2;
            if (curve.calc_withdraw_one_coin(mid, SDT_INDEX) >= amount) hi = mid;
            else lo = mid;
        }
        return hi;
    }

    function withdraw(uint256 amount) external onlyVault nonReentrant { _withdraw(amount); }

    /** @notice The original vault's emergency entrypoint has the same gross-settlement obligation. */
    function emergencyWithdraw(uint256 amount) external onlyVault nonReentrant { _withdraw(amount); }

    function _withdraw(uint256 amount) private {
        if (amount == 0) return;
        uint256 navBefore = balanceOf();
        uint256 vaultIdle = sdt.balanceOf(vault);
        uint256 grossClaim = vaultIdle + amount;
        bool isFinal = parent.totalSupply() == 0;
        uint256 fee = Math.mulDiv(grossClaim, parent.withdrawalFeeBps(), BPS);
        uint256 held = sdt.balanceOf(address(this));
        uint256 exclusion = reserveSDT + pendingFinalFee;
        uint256 managedIdle = held > exclusion ? held - exclusion : 0;
        uint256 sharesBurnt;
        uint256 lpBurnt;

        if (isFinal) {
            sharesBurnt = yearn.balanceOf(address(this));
            if (sharesBurnt != 0) yearn.redeem(sharesBurnt, address(this), address(this));
            lpBurnt = lp.balanceOf(address(this));
            if (lpBurnt != 0) curve.remove_liquidity_one_coin(lpBurnt, SDT_INDEX, 0);
        } else if (managedIdle < amount) {
            uint256 missing = amount - managedIdle;
            uint256 lpTotal = _totalLp();
            if (lpTotal != 0) {
                uint256 maximumSDT = curve.calc_withdraw_one_coin(lpTotal, SDT_INDEX);
                // Redeem all when the conversion reserve must cover a shortfall.
                lpBurnt = maximumSDT < missing ? lpTotal : _lpForSdt(missing, lpTotal);
                uint256 localLp = lp.balanceOf(address(this));
                if (lpBurnt > localLp) {
                    uint256 neededLp = lpBurnt - localLp;
                    uint256 oldLp = localLp;
                    sharesBurnt = yearn.withdraw(neededLp, address(this), address(this));
                    if (lp.balanceOf(address(this)) - oldLp < neededLp) revert InsufficientLiquidity();
                }
                curve.remove_liquidity_one_coin(lpBurnt, SDT_INDEX, 0);
            }
        }

        uint256 available = sdt.balanceOf(address(this));
        if (available < amount) revert InsufficientLiquidity();
        uint256 excluded = reserveSDT + pendingFinalFee;
        uint256 managedAvailable = available > excluded ? available - excluded : 0;
        if (managedAvailable < amount) {
            uint256 consumed = amount - managedAvailable;
            if (consumed > reserveSDT) consumed = reserveSDT;
            reserveSDT -= consumed;
            emit ReserveApplied(consumed);
        }
        sdt.safeTransfer(vault, amount);
        if (isFinal) {
            // Entire prior ownership has been burned; ringfence any leftover SDT.
            reserveSDT = sdt.balanceOf(address(this));
            pendingFinalFee += fee; // received after strategy.withdraw returns
        } else {
            uint256 afterNav = balanceOf();
            uint256 expectedNav = navBefore > amount ? navBefore - amount : 0;
            if (afterNav < expectedNav) {
                uint256 shortfall = expectedNav - afterNav;
                uint256 consumed = shortfall < reserveSDT ? shortfall : reserveSDT;
                reserveSDT -= consumed;
                if (consumed != 0) emit ReserveApplied(consumed);
                unrecoveredCost = shortfall - consumed;
                if (unrecoveredCost != 0) emit UncoveredConversionCost(unrecoveredCost);
            } else {
                unrecoveredCost = 0;
            }
            pendingOrdinaryFee = fee;
            pendingOrdinary = true;
        }
        emit Redeemed(amount, amount, lpBurnt, sharesBurnt);
    }

    /**
     * @notice The UNMODIFIED vault calls this after sending the 30% admin fee
     *         (to this strategy) and the retained 70% fee (also to this strategy).
     * @dev No artificial PPS-lock and no optional PPS-loss reverts. Fee income
     *      immediately offsets withdrawal conversion cost and becomes strategy NAV.
     *      A 10% slice of the TOTAL fee is paid to the actual administrator.
     */
    function lockVaultProfit(uint256 retainedAmount) external onlyVault nonReentrant {
        uint256 fee;
        if (pendingOrdinary) {
            fee = pendingOrdinaryFee;
            pendingOrdinary = false;
            pendingOrdinaryFee = 0;
        } else {
            // An idle-vault redemption does not trigger strategy.withdraw().
            fee = Math.mulDiv(retainedAmount, BPS, BPS - VAULT_ADMIN_SHARE_BPS);
        }
        uint256 admin = Math.mulDiv(fee, REAL_ADMIN_SHARE_BPS, BPS);
        uint256 held = sdt.balanceOf(address(this));
        if (admin > held) admin = held;
        if (admin != 0) sdt.safeTransfer(realAdminReceiver, admin);
        uint256 net = fee > admin ? fee - admin : 0;
        uint256 recovery = net < unrecoveredCost ? net : unrecoveredCost;
        unrecoveredCost -= recovery;
        reserveSDT += net - recovery;
        emit WithdrawalFeeRecycled(fee, admin, net);
    }
}