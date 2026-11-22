// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StrategyCurveSDTYearnV6
 * @notice SDT -> Curve SDT/WETH LP -> constructor-selected Yearn ERC4626 vault.
 * @dev Uses the ORIGINAL, unmodified BeefyVaultV7FixedV2 from BoostHub v57.
 *      The Beefy vault mints shares against the actual NAV change after deposit(),
 *      so the depositor bears the entry conversion cost, not existing shareholders.
 *      balanceOf() quotes the SDT obtainable by redeeming held LP and Yearn shares;
 *      this already includes Curve's one-sided exit fee in the share value.
 *
 *      The original vault independently charges its immutable withdrawal fee
 *      (deploy with 50 bps) and pays its original 30/70 admin/shareholder split.
 *      No synthetic NAV markup, levy, insurance reserve, or orphan reassignment.
 *
 *      External Yearn redemption liquidity, Curve execution and asset price
 *      changes remain beyond the strategy's control. The original vault itself
 *      reverts on any gross SDT withdrawal shortfall, zero-share deposit, etc.
 */
import "@openzeppelin-4/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-4/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin-4/contracts/utils/math/Math.sol";

interface ICurveSDTWETHV6 {
    function coins(uint256 i) external view returns (address);
    function calc_token_amount(uint256[2] calldata amounts, bool deposit) external view returns (uint256);
    function calc_withdraw_one_coin(uint256 lpShares, uint256 i) external view returns (uint256);
    function add_liquidity(uint256[2] calldata amounts, uint256 minLp) external returns (uint256);
    function remove_liquidity_one_coin(uint256 lpShares, uint256 i, uint256 minSDT) external returns (uint256);
}

interface IYearnSDTLPV6 is IERC20 {
    function asset() external view returns (address);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
}

interface IBeefySDTVaultV6 {
    function totalSupply() external view returns (uint256);
    function withdrawalFeeBps() external view returns (uint256);
    function adminFeeReceiver() external view returns (address);
}

contract StrategyCurveSDTYearnV6 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant CURVE_LP = 0xA19bf6fBf05624282cb6ed498f4761f22e084Edd;
    uint256 private constant SDT_INDEX = 1;
    uint256 private constant BPS = 10_000;
    uint256 private constant MAX_DEPOSIT_QUOTE_DRIFT_BPS = 50;
    uint256 private constant LP_SEARCH_STEPS = 48;

    address public immutable vault;
    address public immutable want;
    ICurveSDTWETHV6 public immutable curve;
    IYearnSDTLPV6 public immutable yearn;
    IERC20 private immutable sdt;
    IERC20 private immutable lp;

    event Invested(uint256 sdtIn, uint256 curveLpOut, uint256 yearnSharesOut);
    event Withdrawn(uint256 grossSDT, uint256 lpBurned, uint256 yearnSharesBurned);
    event InvestmentDeferred(uint8 reason);

    error NotVault();
    error BadDependency();
    error InsufficientRedemptionLiquidity();

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault();
        _;
    }

    /// @param vault_ Expected address of the ORIGINAL BeefyVaultV7FixedV2 (deploy strategy first).
    /// @param yearn_ ERC4626 Yearn vault whose asset() is the specified Curve LP token.
    constructor(address vault_, address yearn_) {
        if (block.chainid != 1 || vault_ == address(0) || yearn_.code.length == 0 || CURVE_LP.code.length == 0) {
            revert BadDependency();
        }
        ICurveSDTWETHV6 pool = ICurveSDTWETHV6(CURVE_LP);
        if (pool.coins(0) != WETH || pool.coins(SDT_INDEX) != SDT || IYearnSDTLPV6(yearn_).asset() != CURVE_LP) {
            revert BadDependency();
        }
        vault = vault_;
        want = SDT;
        curve = pool;
        yearn = IYearnSDTLPV6(yearn_);
        sdt = IERC20(SDT);
        lp = IERC20(CURVE_LP);
        sdt.forceApprove(CURVE_LP, type(uint256).max);
        lp.forceApprove(yearn_, type(uint256).max);
    }

    function totalCurveLp() public view returns (uint256) {
        uint256 shares = yearn.balanceOf(address(this));
        return lp.balanceOf(address(this)) + (shares == 0 ? 0 : yearn.previewRedeem(shares));
    }

    /** @notice Realizable SDT quote for the entire position, including one-sided Curve exit fees. */
    function balanceOf() public view returns (uint256) {
        uint256 lpAssets = totalCurveLp();
        return sdt.balanceOf(address(this)) +
            (lpAssets == 0 ? 0 : curve.calc_withdraw_one_coin(lpAssets, SDT_INDEX));
    }

    /// @notice The parent's post-investment delta NAV share minting charges entry costs to the depositor.
    /// @dev If Curve or Yearn refuses an investment, keep the transferred asset as idle SDT / LP.
    ///      Idle funds remain fully included in balanceOf; there is no synthetic fee or NAV haircut.
    function deposit() external onlyVault nonReentrant {
        uint256 amount = sdt.balanceOf(address(this));
        if (amount != 0) {
            uint256[2] memory amounts = [uint256(0), amount];
            uint256 quote;
            try curve.calc_token_amount(amounts, true) returns (uint256 q) {
                quote = q;
            } catch {
                emit InvestmentDeferred(1);
                return;
            }
            if (quote == 0) {
                emit InvestmentDeferred(1);
                return;
            }
            uint256 minLp = Math.mulDiv(quote, BPS - MAX_DEPOSIT_QUOTE_DRIFT_BPS, BPS);
            try curve.add_liquidity(amounts, minLp) returns (uint256) {
                // Continue with actual LP balance, not the return value alone.
            } catch {
                emit InvestmentDeferred(2);
                return;
            }
        }
        uint256 availableLp = lp.balanceOf(address(this));
        if (availableLp == 0) return;
        uint256 sharesBefore = yearn.balanceOf(address(this));
        try yearn.deposit(availableLp, address(this)) returns (uint256) {
            emit Invested(amount, availableLp, yearn.balanceOf(address(this)) - sharesBefore);
        } catch {
            emit InvestmentDeferred(3);
        }
    }

    /// @dev Smallest approximate LP burn giving at least requested SDT under live Curve quote.
    function _lpForSDT(uint256 requiredSDT, uint256 maxLp) private view returns (uint256) {
        if (maxLp == 0 || curve.calc_withdraw_one_coin(maxLp, SDT_INDEX) < requiredSDT) {
            revert InsufficientRedemptionLiquidity();
        }
        uint256 low;
        uint256 high = maxLp;
        for (uint256 i; i < LP_SEARCH_STEPS && high - low > 1; ++i) {
            uint256 mid = low + (high - low) / 2;
            if (curve.calc_withdraw_one_coin(mid, SDT_INDEX) >= requiredSDT) high = mid;
            else low = mid;
        }
        return high;
    }

    function withdraw(uint256 grossSDT) external onlyVault nonReentrant {
        _withdraw(grossSDT);
    }

    /// @notice Compatible with the original vault's emergencyWithdraw selector.
    function emergencyWithdraw(uint256 grossSDT) external onlyVault nonReentrant {
        _withdraw(grossSDT);
    }

    function _withdraw(uint256 grossSDT) private {
        if (grossSDT == 0) return;
        uint256 held = sdt.balanceOf(address(this));
        uint256 redeemedLp;
        uint256 redeemedYearn;
        bool finalExit = IBeefySDTVaultV6(vault).totalSupply() == 0;
        if (finalExit) {
            // Fully unwind on the last share exit, including an already-idle SDT balance.
            redeemedYearn = yearn.balanceOf(address(this));
            if (redeemedYearn != 0) yearn.redeem(redeemedYearn, address(this), address(this));
            redeemedLp = lp.balanceOf(address(this));
            if (redeemedLp != 0) curve.remove_liquidity_one_coin(redeemedLp, SDT_INDEX, 0);
        } else if (held < grossSDT) {
            uint256 missing = grossSDT - held;
            uint256 localLp = lp.balanceOf(address(this));
            redeemedLp = _lpForSDT(missing, totalCurveLp());
            if (redeemedLp > localLp) {
                uint256 needLp = redeemedLp - localLp;
                redeemedYearn = yearn.withdraw(needLp, address(this), address(this));
            }
            if (redeemedLp != 0) curve.remove_liquidity_one_coin(redeemedLp, SDT_INDEX, missing);
        }
        if (sdt.balanceOf(address(this)) < grossSDT) revert InsufficientRedemptionLiquidity();
        sdt.safeTransfer(vault, grossSDT);
        emit Withdrawn(grossSDT, redeemedLp, redeemedYearn);
    }

    /** @notice The unchanged vault sends its 70% shareholder share here automatically.
     * @dev No lock or fee manipulation: incoming SDT directly increases residual shareholder NAV.
     */
    function lockVaultProfit(uint256) external onlyVault nonReentrant {}
}