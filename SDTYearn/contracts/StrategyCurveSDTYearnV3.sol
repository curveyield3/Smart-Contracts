// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StrategyCurveSDTYearnV3
 * @notice Ethereum SDT -> Curve SDT/WETH TwoCrypto LP -> a constructor-fixed ERC4626 Yearn vault.
 * @dev Designed for the EXACT, UNMODIFIED BeefyVaultV7FixedV2 contract from the
 *      supplied BoostHub Contract Stack v57. No substitute vault or modified accounting.
 *
 *      The parent requests its full gross SDT NAV claim from withdraw(), THEN deducts
 *      its immutable 50 bps withdrawal fee. Accordingly, balanceOf() MUST NOT gross
 *      up the Curve/Yearn exit quote by 10000/9950: that can make full withdrawals
 *      impossible. Instead it reports the currently quoted, net-redeemable SDT.
 *
 *      Normal withdrawals are fail-closed against a decrease in the remaining vault's
 *      reported PPS. The parent calls lockVaultProfit() after paying the user and
 *      admin and returning its retained 70% fee. This strategy locks as much of that
 *      fee as possible without consuming the cushion needed to keep PPS nondecreasing.
 *      Deposits rely on the unmodified parent's actual-NAV-delta share-mint formula.
 *
 *      The invariant is transaction-level. Market changes, Yearn losses, and oracle/
 *      pool repricing BETWEEN operations can change reported PPS. No strategy can
 *      prevent those external events by modifying only strategy code.
 */

import "@openzeppelin-4/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-4/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin-4/contracts/utils/math/Math.sol";

interface ICurveSDTWethV3 {
    function coins(uint256 i) external view returns (address);
    function calc_token_amount(uint256[2] calldata amounts, bool isDeposit) external view returns (uint256);
    function calc_withdraw_one_coin(uint256 shares, uint256 i) external view returns (uint256);
    function add_liquidity(uint256[2] calldata amounts, uint256 minLp) external returns (uint256);
    function remove_liquidity_one_coin(uint256 shares, uint256 i, uint256 minSdt) external returns (uint256);
}

interface IYearnCurveLPV3 is IERC20 {
    function asset() external view returns (address);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
}

interface IOriginalBeefyVaultV7 {
    function balance() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function withdrawalFeeBps() external view returns (uint256);
    function ADMIN_FEE_SHARE_BPS() external view returns (uint256);
    function adminFeeReceiver() external view returns (address);
    function underlying() external view returns (address);
    function strategy() external view returns (address);
}

contract StrategyCurveSDTYearnV3 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public constant CURVE_POOL = 0xA19bf6fBf05624282cb6ed498f4761f22e084Edd;
    address public constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 public constant WITHDRAWAL_TAX_BPS = 50;
    uint256 public constant ADMIN_FEE_SHARE_BPS = 3_000;
    uint256 private constant BPS = 10_000;
    uint256 private constant SDT_COIN_INDEX = 1;
    uint256 private constant QUOTE_TOLERANCE_BPS = 10;
    uint256 private constant LP_SEARCH_STEPS = 32;
    uint256 public constant PROFIT_LOCK_DURATION = 3 days;

    address public immutable vault;
    address public immutable want;
    IOriginalBeefyVaultV7 private immutable parent;
    ICurveSDTWethV3 public immutable curve;
    IYearnCurveLPV3 public immutable yearn;
    IERC20 private immutable sdt;
    IERC20 private immutable lp;

    // Only newly returned withdrawal fees are locked; earlier fees unlock linearly.
    // Locked SDT remains idle and is never used for ordinary withdrawals.
    uint256 public totalLocked;
    uint256 public lastHarvest;

    // A normal withdrawal is one atomic parent call: withdraw -> pay -> lockVaultProfit.
    // The pre-burn share supply cannot be queried (the parent already burned shares),
    // but preserving pre-withdraw reported assets minus the parent's GROSS claim is a
    // stronger sufficient condition for preserving PPS, independent of rounding.
    uint256 private pendingBeforeAssets;
    uint256 private pendingGrossClaim;
    uint256 private pendingRetainedFee;
    bool private pendingLock;

    event Invested(uint256 sdtIn, uint256 curveLpIn, uint256 yearnSharesOut);
    event Redeemed(uint256 grossRequested, uint256 sdtReturned, uint256 curveLpBurnt, uint256 yearnSharesBurnt);
    event WithdrawalFeeLocked(uint256 received, uint256 newlyLocked, uint256 unlockedToCoverCost);
    event FinalSurplusSentToAdmin(uint256 sdtAmount);

    error NotVault();
    error InvalidDependency();
    error InvalidVaultFee();
    error InsufficientLiquidity();
    error OutputBelowQuote();
    error PricePerShareWouldFall();
    error UnexpectedFeeCallback();

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault();
        _;
    }

    /**
     * @param parentVault_ Precomputed address of the unmodified BeefyVaultV7FixedV2.
     * @param yearnVault_ ERC4626 vault whose asset() is precisely the Curve LP token.
     * @dev The strategy must be deployed before the parent because the original parent
     *      checks strategy.vault() == address(this) in its constructor.
     */
    constructor(address parentVault_, address yearnVault_) {
        if (block.chainid != 1 || parentVault_ == address(0) || yearnVault_.code.length == 0) {
            revert InvalidDependency();
        }
        if (CURVE_POOL.code.length == 0) revert InvalidDependency();
        ICurveSDTWethV3 pool = ICurveSDTWethV3(CURVE_POOL);
        if (pool.coins(0) != WETH || pool.coins(SDT_COIN_INDEX) != SDT) revert InvalidDependency();
        if (IYearnCurveLPV3(yearnVault_).asset() != CURVE_POOL) revert InvalidDependency();

        vault = parentVault_;
        want = SDT;
        parent = IOriginalBeefyVaultV7(parentVault_);
        curve = pool;
        yearn = IYearnCurveLPV3(yearnVault_);
        sdt = IERC20(SDT);
        lp = IERC20(CURVE_POOL);

        sdt.forceApprove(CURVE_POOL, type(uint256).max);
        lp.forceApprove(yearnVault_, type(uint256).max);
    }

    function _checkParent() internal view {
        if (parent.withdrawalFeeBps() != WITHDRAWAL_TAX_BPS ||
            parent.ADMIN_FEE_SHARE_BPS() != ADMIN_FEE_SHARE_BPS) revert InvalidVaultFee();
        if (parent.underlying() != SDT || parent.strategy() != address(this)) revert InvalidDependency();
    }

    function lockedProfit() public view returns (uint256) {
        uint256 elapsed = block.timestamp - lastHarvest;
        if (elapsed >= PROFIT_LOCK_DURATION) return 0;
        return Math.mulDiv(totalLocked, PROFIT_LOCK_DURATION - elapsed, PROFIT_LOCK_DURATION);
    }

    function _totalLp() internal view returns (uint256) {
        uint256 shares = yearn.balanceOf(address(this));
        return lp.balanceOf(address(this)) + (shares == 0 ? 0 : yearn.previewRedeem(shares));
    }

    /**
     * @notice Current SDT redemption quote for all assets, including liquidity exit fees.
     * @dev This is a state-dependent quote, not a guarantee that later transactions execute
     *      at the same exchange rate, and not a fee-free WETH-denominated LP mark.
     */
    function redeemableSDT() public view returns (uint256) {
        uint256 lpAssets = _totalLp();
        return sdt.balanceOf(address(this)) +
            (lpAssets == 0 ? 0 : curve.calc_withdraw_one_coin(lpAssets, SDT_COIN_INDEX));
    }

    /**
     * @notice Vault NAV in SDT: conservative relative to gross-up, net of currently
     *         unvested retained withdrawal fees, and based on current Curve exit quote.
     */
    function balanceOf() public view returns (uint256) {
        uint256 total = redeemableSDT();
        uint256 locked = lockedProfit();
        return total > locked ? total - locked : 0;
    }

    function deposit() external onlyVault nonReentrant {
        _checkParent();
        if (pendingLock) revert UnexpectedFeeCallback();
        uint256 locked = lockedProfit();
        uint256 idle = sdt.balanceOf(address(this));
        // Never invest the retained withdrawal fee while it remains time-locked.
        if (idle <= locked) return;
        uint256 amount = idle - locked;

        uint256[2] memory amounts = [uint256(0), amount];
        uint256 quote = curve.calc_token_amount(amounts, true);
        if (quote == 0) revert OutputBelowQuote();
        uint256 minLp = Math.mulDiv(quote, BPS - QUOTE_TOLERANCE_BPS, BPS);
        uint256 lpBefore = lp.balanceOf(address(this));
        curve.add_liquidity(amounts, minLp);
        uint256 obtained = lp.balanceOf(address(this)) - lpBefore;
        if (obtained == 0 || obtained < minLp) revert OutputBelowQuote();
        uint256 yearnBefore = yearn.balanceOf(address(this));
        yearn.deposit(obtained, address(this));
        uint256 newShares = yearn.balanceOf(address(this)) - yearnBefore;
        if (newShares == 0) revert OutputBelowQuote();
        emit Invested(amount, obtained, newShares);
    }

    /** @dev Upper bound on LP required for `amount` SDT; at most 32 Curve quote calls. */
    function _lpForSdt(uint256 amount, uint256 maxLp) private view returns (uint256) {
        if (maxLp == 0 || curve.calc_withdraw_one_coin(maxLp, SDT_COIN_INDEX) < amount) {
            revert InsufficientLiquidity();
        }
        uint256 lo;
        uint256 hi = maxLp;
        for (uint256 i; i < LP_SEARCH_STEPS && hi - lo > 1; ++i) {
            uint256 mid = lo + (hi - lo) / 2;
            if (curve.calc_withdraw_one_coin(mid, SDT_COIN_INDEX) >= amount) hi = mid;
            else lo = mid;
        }
        return hi;
    }

    function withdraw(uint256 grossAmount) external onlyVault nonReentrant {
        _withdraw(grossAmount);
    }

    /// @notice Preserve original parent's emergency selector; no alternate fee bypass.
    function emergencyWithdraw(uint256 grossAmount) external onlyVault nonReentrant {
        _withdraw(grossAmount);
    }

    function _withdraw(uint256 amount) private {
        _checkParent();
        if (pendingLock) revert UnexpectedFeeCallback();
        if (amount == 0) return;

        uint256 beforeNav = parent.balance();
        uint256 vaultIdle = sdt.balanceOf(vault);
        uint256 grossClaim = amount + vaultIdle;
        bool finalShareholder = parent.totalSupply() == 0; // The parent burns first.
        uint256 fee = Math.mulDiv(grossClaim, WITHDRAWAL_TAX_BPS, BPS);
        uint256 retainedFee = finalShareholder ? 0 : fee - Math.mulDiv(fee, ADMIN_FEE_SHARE_BPS, BPS);
        uint256 locked = lockedProfit();
        uint256 idle = sdt.balanceOf(address(this));
        uint256 liquidIdle = finalShareholder ? idle : (idle > locked ? idle - locked : 0);
        uint256 sharesBurnt;
        uint256 lpBurnt;

        if (finalShareholder) {
            sharesBurnt = yearn.balanceOf(address(this));
            if (sharesBurnt != 0) yearn.redeem(sharesBurnt, address(this), address(this));
            lpBurnt = lp.balanceOf(address(this));
            if (lpBurnt != 0) curve.remove_liquidity_one_coin(lpBurnt, SDT_COIN_INDEX, 0);
        } else if (liquidIdle < amount) {
            uint256 missing = amount - liquidIdle;
            lpBurnt = _lpForSdt(missing, _totalLp());
            uint256 localLp = lp.balanceOf(address(this));
            if (lpBurnt > localLp) {
                uint256 toTakeFromYearn = lpBurnt - localLp;
                uint256 beforeLp = lp.balanceOf(address(this));
                sharesBurnt = yearn.withdraw(toTakeFromYearn, address(this), address(this));
                if (lp.balanceOf(address(this)) - beforeLp < toTakeFromYearn) revert InsufficientLiquidity();
            }
            if (lp.balanceOf(address(this)) < lpBurnt) revert InsufficientLiquidity();
            curve.remove_liquidity_one_coin(lpBurnt, SDT_COIN_INDEX, missing);
        }

        uint256 sdtAvailable = sdt.balanceOf(address(this));
        if (sdtAvailable < amount + (finalShareholder ? 0 : locked)) revert InsufficientLiquidity();
        sdt.safeTransfer(vault, amount);

        if (finalShareholder) {
            // The original parent sends its entire final withdrawal fee to admin.
            // With zero shares left, also settle any unrepresented profit/locked dust
            // to that SAME configured receiver; never strand unowned assets.
            totalLocked = 0;
            lastHarvest = 0;
            uint256 surplus = sdt.balanceOf(address(this));
            if (surplus != 0) {
                sdt.safeTransfer(parent.adminFeeReceiver(), surplus);
                emit FinalSurplusSentToAdmin(surplus);
            }
        } else {
            uint256 nowNav = parent.balance(); // Before parent pays out its gross claim.
            if (nowNav + retainedFee < beforeNav) revert PricePerShareWouldFall();
            if (retainedFee != 0) {
                pendingBeforeAssets = beforeNav;
                pendingGrossClaim = grossClaim;
                pendingRetainedFee = retainedFee;
                pendingLock = true;
            }
        }
        emit Redeemed(amount, amount, lpBurnt, sharesBurnt);
    }

    /**
     * @notice The UNMODIFIED parent returns 70% of its withdrawal fee here.
     * @dev The last transfer has already happened. We lock only the part of the
     *      returned SDT that is surplus to the exact pre-withdraw PPS floor. If
     *      losses consume the entire fee, the call reverts instead of diluting.
     *      If no strategy withdrawal occurred (parent had sufficient idle SDT),
     *      the full returned amount can be locked as in the original strategy.
     */
    function lockVaultProfit(uint256 amount) external onlyVault nonReentrant {
        _checkParent();
        uint256 oldLocked = lockedProfit();
        if (sdt.balanceOf(address(this)) < oldLocked + amount) revert InsufficientLiquidity();
        uint256 newLock = amount;
        if (pendingLock) {
            if (amount != pendingRetainedFee) revert UnexpectedFeeCallback();
            uint256 afterAssets = parent.balance(); // Includes returned fee, before new lock.
            uint256 needed = pendingBeforeAssets > pendingGrossClaim
                ? pendingBeforeAssets - pendingGrossClaim : 0;
            if (afterAssets < needed) revert PricePerShareWouldFall();
            uint256 excess = afterAssets - needed;
            if (newLock > excess) newLock = excess;
            pendingBeforeAssets = 0;
            pendingGrossClaim = 0;
            pendingRetainedFee = 0;
            pendingLock = false;
        }
        if (newLock != 0) {
            totalLocked = oldLocked + newLock;
            lastHarvest = block.timestamp;
        }
        emit WithdrawalFeeLocked(amount, newLock, amount - newLock);
    }
}