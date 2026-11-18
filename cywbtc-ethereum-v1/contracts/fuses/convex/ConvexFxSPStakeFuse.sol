// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFuseCommon} from "../IFuseCommon.sol";

interface IFxSPForConvex {
    function deposit(address receiver, address tokenIn, uint256 amount, uint256 minSharesOut)
        external returns (uint256 shares);
    function requestRedeem(uint256 shares) external;
    function redeem(address receiver, uint256 shares) external returns (uint256 fxusdOut, uint256 usdcOut);
}
interface IConvexPid37Registry {
    function vaultMap(uint256 pid, address account) external view returns (address);
    function poolInfo(uint256 pid) external view returns (
        address implementation, address gauge, address stakingToken, address rewards, uint8 active
    );
}
interface IConvexPid37Booster {
    function createVault(uint256 pid) external returns (address);
}
interface IConvexPersonalVault {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
}
interface IRouterForFxSP {
    function easyswap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256);
}

/// @notice Exactly one strategy: fxUSD -> fxSP -> Convex f(x) PID 37, and reversible scheduled exits.
/// @dev Runs by delegatecall in PlasmaVault. No allocator, NFT management, LTV logic or local position state.
contract ConvexFxSPStakeFuse is IFuseCommon {
    using SafeERC20 for IERC20;

    uint256 public constant MARKET_ID = 17;
    uint256 public constant PID = 37;
    address public immutable VERSION;
    address public immutable BOOSTER;
    address public immutable REGISTRY;
    address public immutable FXSP;
    address public immutable FXUSD;
    address public immutable USDC;
    address public immutable ROUTER;

    error InvalidMarket();
    error MissingPersonalVault();
    error NoDeposit();

    constructor(address booster_, address registry_, address fxsp_, address fxusd_, address usdc_, address router_) {
        if (booster_ == address(0) || registry_ == address(0) || fxsp_ == address(0) ||
            fxusd_ == address(0) || usdc_ == address(0) || router_ == address(0)) revert InvalidMarket();
        (, , address stakingToken, , uint8 active) = IConvexPid37Registry(registry_).poolInfo(PID);
        if (active != 1 || stakingToken != fxsp_) revert InvalidMarket();
        VERSION = address(this);
        BOOSTER = booster_;
        REGISTRY = registry_;
        FXSP = fxsp_;
        FXUSD = fxusd_;
        USDC = usdc_;
        ROUTER = router_;
    }

    /// @notice Invest borrowed fxUSD in fxSP and stake the resulting shares in this vault's personal PID37 vault.
    /// @dev Booster creates that personal vault exactly once; thereafter the existing registry entry is reused.
    function enter(uint256 fxusdAmount, uint256 minFxspSharesOut) external returns (uint256 stakedShares) {
        if (fxusdAmount == 0) revert NoDeposit();
        address personal = IConvexPid37Registry(REGISTRY).vaultMap(PID, address(this));
        if (personal == address(0)) personal = IConvexPid37Booster(BOOSTER).createVault(PID);
        uint256 prior = IERC20(FXSP).balanceOf(address(this));
        IERC20(FXUSD).forceApprove(FXSP, fxusdAmount);
        IFxSPForConvex(FXSP).deposit(address(this), FXUSD, fxusdAmount, minFxspSharesOut);
        stakedShares = IERC20(FXSP).balanceOf(address(this)) - prior;
        if (stakedShares == 0) revert NoDeposit();
        IERC20(FXSP).forceApprove(personal, stakedShares);
        IConvexPersonalVault(personal).deposit(stakedShares);
    }

    /// @notice Return staked fxSP shares to PlasmaVault without redeeming them.
    function exit(uint256 shares) external {
        IConvexPersonalVault(_personal()).withdraw(shares);
    }

    /// @notice Unstake exact shares and begin their actual fxSP 3600s cooldown.
    function requestExit(uint256 shares) external {
        IConvexPersonalVault(_personal()).withdraw(shares);
        IFxSPForConvex(FXSP).requestRedeem(shares);
    }

    /// @notice Redeem matured fxSP and swap the USDC output to fxUSD once through the existing router.
    function finalizeExit(uint256 shares) external {
        (, uint256 usdcOut) = IFxSPForConvex(FXSP).redeem(address(this), shares);
        if (usdcOut != 0) {
            IERC20(USDC).forceApprove(ROUTER, usdcOut);
            IRouterForFxSP(ROUTER).easyswap(USDC, FXUSD, usdcOut);
        }
    }

    function _personal() private view returns (address account) {
        account = IConvexPid37Registry(REGISTRY).vaultMap(PID, address(this));
        if (account == address(0)) revert MissingPersonalVault();
    }
}
