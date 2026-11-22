// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StrategyCurveSDTYearnV2
 * @notice SDT -> Curve TwoCrypto SDT/WETH LP -> a constructor-bound Yearn ERC4626 vault.
 * @dev This strategy is only a capital converter, not a reward harvester. The corresponding
 *      BeefyVaultSDTYearnV1 treats its 50 bps exit tax as a conversion-cost allowance.
 *      The reported strategy NAV deliberately grosses up a current all-SDT exit quote
 *      by 10000/9950. It must NOT be paired with an unmodified BeefyVaultV7FixedV2,
 *      whose withdrawals request the full (grossed-up) claim from the strategy.
 *      External loss, liquidity or price movement can make an operation revert;
 *      neither an ERC4626 share conversion nor a Curve quotation guarantees execution.
 */

import "@openzeppelin-4/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-4/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin-4/contracts/utils/math/Math.sol";

interface ICurveSDTWethPoolV1 {
    function coins(uint256 index) external view returns (address);
    function calc_token_amount(uint256[2] calldata amounts, bool deposit) external view returns (uint256);
    function calc_withdraw_one_coin(uint256 lpAmount, uint256 tokenIndex) external view returns (uint256);
    function add_liquidity(uint256[2] calldata amounts, uint256 minLP) external returns (uint256);
    function remove_liquidity_one_coin(uint256 lpAmount, uint256 tokenIndex, uint256 minSDT) external returns (uint256);
}

interface IYearnSDTLPVaultV1 is IERC20 {
    function asset() external view returns (address);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}

interface ISDTYearnParentV1 {
    function totalSupply() external view returns (uint256);
}

contract StrategyCurveSDTYearnV2 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public constant CURVE_POOL = 0xA19bf6fBf05624282cb6ed498f4761f22e084Edd;
    uint256 public constant TAX_BPS = 50;
    uint256 private constant BPS = 10_000;
    uint256 private constant SDT_INDEX = 1;
    uint256 private constant MAX_LP_SEARCH_STEPS = 24;
    // 10 bps quote-difference allowance. The parent's PPS floor is the final guard.
    uint256 private constant DEPOSIT_QUOTE_TOLERANCE_BPS = 10;

    address public immutable vault;
    address public immutable want;
    ICurveSDTWethPoolV1 public immutable curve;
    IYearnSDTLPVaultV1 public immutable yearn;
    IERC20 private immutable sdt;
    IERC20 private immutable lp;

    event Invested(uint256 sdtSpent, uint256 lpMinted, uint256 yearnShares);
    event Redeemed(uint256 requestedSDT, uint256 sentSDT, uint256 lpBurned, uint256 yearnSharesBurned);

    error NotVault();
    error InsufficientLiquidity();
    error InvalidDependency();
    error InsufficientOutput();

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault();
        _;
    }

    constructor(address vault_, address yearnVault_) {
        if (block.chainid != 1 || vault_ == address(0) || yearnVault_.code.length == 0) {
            revert InvalidDependency();
        }
        vault = vault_;
        curve = ICurveSDTWethPoolV1(CURVE_POOL);
        if (CURVE_POOL.code.length == 0 || curve.coins(0) != 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) {
            revert InvalidDependency();
        }
        address sdt_ = curve.coins(SDT_INDEX);
        if (sdt_ != 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F) revert InvalidDependency();
        if (IYearnSDTLPVaultV1(yearnVault_).asset() != CURVE_POOL) revert InvalidDependency();

        yearn = IYearnSDTLPVaultV1(yearnVault_);
        want = sdt_;
        sdt = IERC20(sdt_);
        lp = IERC20(CURVE_POOL);
        sdt.forceApprove(CURVE_POOL, type(uint256).max);
        lp.forceApprove(yearnVault_, type(uint256).max);
    }

    /// @notice Estimate the strategy's total available SDT value after exiting the Curve LP.
    /// @dev The Yearn share -> LP part is ERC4626 previewRedeem; Curve's one-coin exit quote
    ///      includes its current fee. These are *quotes* and may differ after actual swaps.
    function redeemableSDT() public view returns (uint256) {
        uint256 totalLP = lp.balanceOf(address(this));
        uint256 shares = yearn.balanceOf(address(this));
        if (shares != 0) totalLP += yearn.previewRedeem(shares);
        return sdt.balanceOf(address(this)) + (totalLP == 0 ? 0 : curve.calc_withdraw_one_coin(totalLP, SDT_INDEX));
    }

    /// @notice Vault accounting value, grossed up so the fixed 0.50% tax maps back
    ///         to the current executable-quote SDT amount: gross * 9950/10000 <= net.
    /// @dev Only the invested LP component is grossed up; idle SDT is counted at par.
    function balanceOf() external view returns (uint256) {
        uint256 totalLP = lp.balanceOf(address(this));
        uint256 shares = yearn.balanceOf(address(this));
        if (shares != 0) totalLP += yearn.previewRedeem(shares);
        uint256 lpNetSDT = totalLP == 0 ? 0 : curve.calc_withdraw_one_coin(totalLP, SDT_INDEX);
        return sdt.balanceOf(address(this)) + Math.mulDiv(lpNetSDT, BPS, BPS - TAX_BPS);
    }

    function deposit() external onlyVault nonReentrant {
        uint256 amount = sdt.balanceOf(address(this));
        if (amount == 0) return;

        uint256[2] memory amounts = [uint256(0), amount];
        uint256 expectedLP = curve.calc_token_amount(amounts, true);
        if (expectedLP == 0) revert InsufficientOutput();
        uint256 minLP = Math.mulDiv(expectedLP, BPS - DEPOSIT_QUOTE_TOLERANCE_BPS, BPS);
        uint256 beforeLP = lp.balanceOf(address(this));
        curve.add_liquidity(amounts, minLP);
        uint256 mintedLP = lp.balanceOf(address(this)) - beforeLP;
        if (mintedLP < minLP || mintedLP == 0) revert InsufficientOutput();
        uint256 mintedShares = yearn.deposit(mintedLP, address(this));
        if (mintedShares == 0) revert InsufficientOutput();
        emit Invested(amount, mintedLP, mintedShares);
    }

    /// @dev Conservative bounded binary search. The final LP count is an upper bound
    ///      of the exact amount needed, and Curve itself enforces the SDT minimum.
    ///      Upper bound is the strategy's entire LP exposure (including Yearn shares).
    function _lpForSDT(uint256 need, uint256 maxLP) internal view returns (uint256) {
        if (maxLP == 0 || curve.calc_withdraw_one_coin(maxLP, SDT_INDEX) < need) {
            revert InsufficientLiquidity();
        }
        uint256 lo;
        uint256 hi = maxLP;
        for (uint256 i; i < MAX_LP_SEARCH_STEPS && hi - lo > 1; ++i) {
            uint256 mid = lo + (hi - lo) / 2;
            if (curve.calc_withdraw_one_coin(mid, SDT_INDEX) >= need) hi = mid;
            else lo = mid;
        }
        return hi;
    }

    /// @notice Deliver a *net* amount of SDT, not a grossed-up NAV claim.
    /// @dev Parent burns shares before calling this function. For a final shareholder,
    ///      unwind all Yearn shares and all LP so no position is permanently stranded.
    function withdraw(uint256 amount) external onlyVault nonReentrant {
        uint256 beforeSDT = sdt.balanceOf(address(this));
        bool finalWithdrawal = ISDTYearnParentV1(vault).totalSupply() == 0;
        uint256 burntShares;
        uint256 burntLP;

        if (finalWithdrawal) {
            burntShares = yearn.balanceOf(address(this));
            if (burntShares != 0) yearn.redeem(burntShares, address(this), address(this));
            burntLP = lp.balanceOf(address(this));
            if (burntLP != 0) curve.remove_liquidity_one_coin(burntLP, SDT_INDEX, 0);
        } else if (beforeSDT < amount) {
            uint256 need = amount - beforeSDT;
            uint256 localLP = lp.balanceOf(address(this));
            uint256 yrnShares = yearn.balanceOf(address(this));
            uint256 maxLP = localLP + (yrnShares == 0 ? 0 : yearn.previewRedeem(yrnShares));
            burntLP = _lpForSDT(need, maxLP);

            if (burntLP > localLP) {
                uint256 shortLP = burntLP - localLP;
                burntShares = yearn.previewWithdraw(shortLP);
                if (burntShares > yrnShares) burntShares = yrnShares;
                if (burntShares == 0) revert InsufficientLiquidity();
                yearn.redeem(burntShares, address(this), address(this));
            }
            if (lp.balanceOf(address(this)) < burntLP) revert InsufficientLiquidity();
            curve.remove_liquidity_one_coin(burntLP, SDT_INDEX, need);
        }

        uint256 paid = sdt.balanceOf(address(this));
        if (paid < amount) revert InsufficientOutput();
        // Return all SDT only on the final withdrawal; for other withdrawals,
        // retained idle SDT belongs to continuing shareholders.
        uint256 toSend = finalWithdrawal ? paid : amount;
        sdt.safeTransfer(vault, toSend);
        emit Redeemed(amount, toSend, burntLP, burntShares);
    }
}