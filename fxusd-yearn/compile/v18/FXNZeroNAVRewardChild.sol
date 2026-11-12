// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import {BaseStrategy} from "./YearnBaseStrategyFXUSD_v1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IFXNCurveTwoCoinPool {
    function coins(uint256) external view returns (address);
    function calc_token_amount(uint256[2] calldata amounts, bool deposit) external view returns (uint256);
    function calc_withdraw_one_coin(uint256 lpAmount, int128 index) external view returns (uint256);
    function get_dy(int128 i, int128 j, uint256 amount) external view returns (uint256);
    function add_liquidity(uint256[2] calldata amounts, uint256 minMint) external returns (uint256);
    function remove_liquidity_one_coin(uint256 lpAmount, int128 index, uint256 minOut) external returns (uint256);
    function exchange(int128 i, int128 j, uint256 amount, uint256 minOut) external returns (uint256);
}
interface IConvexFXNRegistry {
    function poolInfo(uint256 pid) external view returns (address, address gauge, address stakingToken, address rewards, uint8 active);
    function vaultMap(uint256 pid, address owner) external view returns (address);
}
interface IConvexFXNBooster { function createVault(uint256 pid) external returns (address); }
interface IConvexFXNProxy {
    function owner() external view returns (address);
    function gaugeAddress() external view returns (address);
    function stakingToken() external view returns (address);
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
}
interface IBoostHubStaking {
    struct PoolView { address asset; address gauge; bool active; uint256 totalStaked; address[] rewardTokens; }
    function poolInfo(uint256 pid) external view returns (PoolView memory);
    function balanceOf(uint256 pid, address staker) external view returns (uint256);
    function deposit(uint256 pid, uint256 amount) external;
    function withdraw(uint256 pid, uint256 amount) external;
    function harvest(uint256 pid) external returns (address[] memory tokens, uint256[] memory amounts);
    function claim(uint256 pid, address receiver) external returns (address[] memory tokens, uint256[] memory amounts);
}
interface IFXNRewardConverter {
    function convert(address tokenIn, address tokenOut, uint256 amount, uint256 minOut)
        external returns (uint256);
}

/// @notice Third economic child: no fxUSD principal, no Yearn shares, ZERO reported NAV.
/// @dev The master funds it exclusively with a configurable portion of harvested FXN;
///      economic returns are distributed by the master to its two NAV-bearing children.
///      This position is deliberately *excluded* from master child allocation/withdrawal.
contract FXNZeroNAVRewardChild is BaseStrategy {
    using SafeERC20 for IERC20;

    uint256 private constant BPS = 10_000;
    uint256 public constant CONVEX_PID = 8;
    IERC20 public immutable FXUSD;
    IERC20 public immutable FXN;
    IERC20 public immutable SDFXN;
    IERC20 public immutable CURVE_LP;
    address public immutable MASTER;
    address public immutable GOVERNANCE;
    IFXNCurveTwoCoinPool public immutable CURVE;
    IConvexFXNRegistry public immutable REGISTRY;
    IConvexFXNBooster public immutable BOOSTER;
    address public immutable GAUGE;
    IBoostHubStaking public immutable BOOSTHUB;
    uint256 public immutable BOOSTHUB_PID;

    uint16 public compoundBps = 3_000; // 30%; owner-bound to 10%-50%
    uint16 public curveSlippageBps = 150; // 1.5%, owner can tighten
    mapping(address => address) public rewardConverter;
    bool private entered;

    error NotAuthorized();
    error InvalidConfiguration();
    error InsufficientOutput();
    error Reentrant();
    event FXNInvested(uint256 fxnIn, uint256 lpStaked);
    event OptimizedToBoostHub(uint256 lpRemoved, uint256 sdFXNStaked);
    event OptimizedToConvex(uint256 sdFXNWithdrawn, uint256 lpStaked);
    event YieldProcessed(uint256 fxnYield, uint256 fxnCompounded, uint256 fxnSentToMaster);
    event CompoundBpsUpdated(uint16 oldBps, uint16 newBps);
    event SlippageUpdated(uint16 oldBps, uint16 newBps);
    event RewardConverterUpdated(address indexed token, address indexed converter);

    modifier onlyMaster() { if (msg.sender != MASTER) revert NotAuthorized(); _; }
    modifier onlyGovernance() { if (msg.sender != GOVERNANCE) revert NotAuthorized(); _; }
    modifier locked() {
        if (entered) revert Reentrant();
        entered = true;
        _;
        entered = false;
    }

    constructor(
        address fxusd, address fxn, address sdfxn, address master,
        address governance, address convexBooster, address convexRegistry,
        address convexGauge, address sdFXNCurve, address boostHub,
        uint256 boostHubPid, address tokenizedStrategy
    ) BaseStrategy(fxusd, "CurveYield FXN Zero-NAV Economic Child", tokenizedStrategy) {
        if (fxusd == address(0) || fxn == address(0) || sdfxn == address(0) ||
            master == address(0) || governance == address(0) ||
            convexBooster.code.length == 0 || convexRegistry.code.length == 0 ||
            convexGauge.code.length == 0 || sdFXNCurve.code.length == 0 ||
            boostHub.code.length == 0) revert InvalidConfiguration();
        FXUSD = IERC20(fxusd);
        FXN = IERC20(fxn);
        SDFXN = IERC20(sdfxn);
        CURVE_LP = IERC20(sdFXNCurve);
        MASTER = master;
        GOVERNANCE = governance;
        BOOSTER = IConvexFXNBooster(convexBooster);
        REGISTRY = IConvexFXNRegistry(convexRegistry);
        GAUGE = convexGauge;
        CURVE = IFXNCurveTwoCoinPool(sdFXNCurve);
        BOOSTHUB = IBoostHubStaking(boostHub);
        BOOSTHUB_PID = boostHubPid;
        if (CURVE.coins(0) != fxn || CURVE.coins(1) != sdfxn) revert InvalidConfiguration();
        (,address gauge,address lp,,uint8 active) = REGISTRY.poolInfo(CONVEX_PID);
        if (active == 0 || gauge != convexGauge || lp != sdFXNCurve) revert InvalidConfiguration();
        IBoostHubStaking.PoolView memory pool = BOOSTHUB.poolInfo(boostHubPid);
        if (!pool.active || pool.asset != sdfxn) revert InvalidConfiguration();
    }

    // NEVER issue shares or report LP/BoostHub principal as vault-redeemable fxUSD.
    function availableDepositLimit(address) public pure override returns (uint256) { return 0; }
    function availableWithdrawLimit(address) public pure override returns (uint256) { return 0; }
    function _deployFunds(uint256) internal pure override { revert InvalidConfiguration(); }
    function _freeFunds(uint256) internal pure override { revert InvalidConfiguration(); }
    function _emergencyWithdraw(uint256) internal pure override { revert InvalidConfiguration(); }
    function _harvestAndReport() internal pure override returns (uint256) { return 0; }
    function reportedNAV() external pure returns (uint256) { return 0; }

    function setCompoundBps(uint16 bps) external onlyGovernance {
        if (bps < 1_000 || bps > 5_000) revert InvalidConfiguration();
        emit CompoundBpsUpdated(compoundBps, bps);
        compoundBps = bps;
    }
    function setCurveSlippageBps(uint16 bps) external onlyGovernance {
        if (bps > 2_000) revert InvalidConfiguration();
        emit SlippageUpdated(curveSlippageBps, bps);
        curveSlippageBps = bps;
    }
    function setRewardConverter(address token, address converter) external onlyGovernance {
        if (token == address(FXN) || token == address(SDFXN) || token == address(CURVE_LP) ||
            token == address(FXUSD) || token == address(0) ||
            (converter != address(0) && converter.code.length == 0))
            revert InvalidConfiguration();
        rewardConverter[token] = converter;
        emit RewardConverterUpdated(token, converter);
    }

    function convexLPStaked() public view returns (uint256) {
        address vault = REGISTRY.vaultMap(CONVEX_PID, address(this));
        if (vault == address(0)) return 0;
        _validateProxy(vault);
        return IERC20(GAUGE).balanceOf(vault);
    }
    function boostHubSDfxnStaked() external view returns (uint256) {
        return BOOSTHUB.balanceOf(BOOSTHUB_PID, address(this));
    }

    function _validateProxy(address proxy) internal view {
        if (IConvexFXNProxy(proxy).owner() != address(this) ||
            IConvexFXNProxy(proxy).stakingToken() != address(CURVE_LP) ||
            IConvexFXNProxy(proxy).gaugeAddress() != GAUGE) revert InvalidConfiguration();
    }
    function _proxy(bool create) internal returns (address vault) {
        vault = REGISTRY.vaultMap(CONVEX_PID, address(this));
        if (vault == address(0) && create) {
            vault = BOOSTER.createVault(CONVEX_PID);
            if (REGISTRY.vaultMap(CONVEX_PID, address(this)) != vault) revert InvalidConfiguration();
        }
        if (vault != address(0)) _validateProxy(vault);
    }
    function _stakeLP(uint256 amount) internal {
        if (amount == 0) return;
        address proxy = _proxy(true);
        uint256 before = IERC20(GAUGE).balanceOf(proxy);
        CURVE_LP.forceApprove(proxy, amount);
        IConvexFXNProxy(proxy).deposit(amount);
        CURVE_LP.forceApprove(proxy, 0);
        if (IERC20(GAUGE).balanceOf(proxy) < before + amount) revert InsufficientOutput();
    }
    function _addLiquidity(uint256 fxnAmount, uint256 sdFXNAmount, uint256 minLP)
        internal returns (uint256 minted)
    {
        if (fxnAmount == 0 && sdFXNAmount == 0) return 0;
        uint256[2] memory amounts = [fxnAmount, sdFXNAmount];
        uint256 quote = CURVE.calc_token_amount(amounts, true);
        uint256 expectedMin = Math.mulDiv(quote, BPS - curveSlippageBps, BPS);
        if (minLP < expectedMin || minLP == 0) minLP = expectedMin;
        if (minLP == 0) revert InsufficientOutput();
        if (fxnAmount != 0) FXN.forceApprove(address(CURVE), fxnAmount);
        if (sdFXNAmount != 0) SDFXN.forceApprove(address(CURVE), sdFXNAmount);
        uint256 before = CURVE_LP.balanceOf(address(this));
        CURVE.add_liquidity(amounts, minLP);
        minted = CURVE_LP.balanceOf(address(this)) - before;
        if (minted < minLP) revert InsufficientOutput();
        if (fxnAmount != 0) FXN.forceApprove(address(CURVE), 0);
        if (sdFXNAmount != 0) SDFXN.forceApprove(address(CURVE), 0);
        _stakeLP(minted);
    }
    function _stakeBoostHub(uint256 amount, uint256 minCredit) internal returns (uint256 credited) {
        uint256 before = BOOSTHUB.balanceOf(BOOSTHUB_PID, address(this));
        SDFXN.forceApprove(address(BOOSTHUB), amount);
        BOOSTHUB.deposit(BOOSTHUB_PID, amount);
        SDFXN.forceApprove(address(BOOSTHUB), 0);
        credited = BOOSTHUB.balanceOf(BOOSTHUB_PID, address(this)) - before;
        if (credited < minCredit) revert InsufficientOutput();
    }

    /// @dev Master transfers actual FXN before calling; no Yearn vault shares.
    function investFromMaster(uint256 fxnAmount) external onlyMaster locked {
        if (fxnAmount == 0 || FXN.balanceOf(address(this)) < fxnAmount) revert InvalidConfiguration();
        uint256 lp = _addLiquidity(fxnAmount, 0, 0);
        emit FXNInvested(fxnAmount, lp);
    }

    /// @notice Owner-directed move of Convex's Curve-LP position to BoostHub sdFXN stake.
    /// @dev Single-coin LP exit obtains sdFXN, not a direct LP->sdFXN transfer.
    function optimizeConvexToBoostHub(uint256 lpAmount, uint256 minSdFXNOut, uint256 minBoostCredit)
        external onlyGovernance locked returns (uint256 actualSdFXN)
    {
        if (lpAmount == 0 || lpAmount > convexLPStaked() || minSdFXNOut == 0)
            revert InvalidConfiguration();
        address proxy = _proxy(false);
        IConvexFXNProxy(proxy).withdraw(lpAmount);
        uint256 before = SDFXN.balanceOf(address(this));
        uint256 oracleQuote = CURVE.calc_withdraw_one_coin(lpAmount, 1);
        uint256 bounded = Math.mulDiv(oracleQuote, BPS - curveSlippageBps, BPS);
        if (bounded > minSdFXNOut) minSdFXNOut = bounded;
        CURVE.remove_liquidity_one_coin(lpAmount, 1, minSdFXNOut);
        actualSdFXN = SDFXN.balanceOf(address(this)) - before;
        if (actualSdFXN < minSdFXNOut) revert InsufficientOutput();
        _stakeBoostHub(actualSdFXN, minBoostCredit);
        emit OptimizedToBoostHub(lpAmount, actualSdFXN);
    }

    /// @notice Reverse the position allocation (not FXN principal redemption).
    /// @dev The user-stated BoostHub may impose withdrawal delays or fees;
    ///      a failed BoostHub withdrawal reverts the entire atomic migration.
    function optimizeBoostHubToConvex(uint256 sdFXNAmount, uint256 minReceived, uint256 minLP)
        external onlyGovernance locked returns (uint256 lpMinted)
    {
        if (sdFXNAmount == 0 || minReceived == 0) revert InvalidConfiguration();
        uint256 before = SDFXN.balanceOf(address(this));
        BOOSTHUB.withdraw(BOOSTHUB_PID, sdFXNAmount);
        uint256 received = SDFXN.balanceOf(address(this)) - before;
        if (received < minReceived) revert InsufficientOutput();
        lpMinted = _addLiquidity(0, received, minLP);
        emit OptimizedToConvex(received, lpMinted);
    }

    /// @notice Converts rewards to FXN, compounds 10-50%, returns rest to master.
    /// @dev Additional reward tokens can use governance-approved, exact-spend FXN
    ///      converters. Unsupported reward tokens remain held, never silently sold.
    function harvestToMaster(
        address[] calldata conversionTokens, uint256[] calldata minimumFXNOut, uint256 minSdFXNToFXN
    ) external onlyMaster locked returns (uint256 returnedFXN) {
        if (conversionTokens.length != minimumFXNOut.length || conversionTokens.length > 16)
            revert InvalidConfiguration();
        address proxy = _proxy(false);
        uint256 fxnBefore = FXN.balanceOf(address(this));
        uint256 sdBefore = SDFXN.balanceOf(address(this));
        if (proxy != address(0)) IConvexFXNProxy(proxy).getReward();
        BOOSTHUB.harvest(BOOSTHUB_PID);
        BOOSTHUB.claim(BOOSTHUB_PID, address(this));
        uint256 directFXN = FXN.balanceOf(address(this)) - fxnBefore;
        uint256 sdRewards = SDFXN.balanceOf(address(this)) - sdBefore;
        uint256 sdCompound = Math.mulDiv(sdRewards, compoundBps, BPS);
        if (sdCompound != 0) {
            uint256 minCredit = Math.mulDiv(sdCompound, BPS - curveSlippageBps, BPS);
            _stakeBoostHub(sdCompound, minCredit);
        }
        uint256 sdForFXN = sdRewards - sdCompound;
        if (sdForFXN != 0) {
            if (minSdFXNToFXN == 0) revert InvalidConfiguration();
            uint256 beforeFXN = FXN.balanceOf(address(this));
            SDFXN.forceApprove(address(CURVE), sdForFXN);
            CURVE.exchange(1, 0, sdForFXN, minSdFXNToFXN);
            SDFXN.forceApprove(address(CURVE), 0);
            directFXN += FXN.balanceOf(address(this)) - beforeFXN;
        }
        for (uint256 i; i < conversionTokens.length; ++i) {
            address token = conversionTokens[i];
            address converter = rewardConverter[token];
            if (converter == address(0) || minimumFXNOut[i] == 0) revert InvalidConfiguration();
            for (uint256 j; j < i; ++j) if (conversionTokens[j] == token) revert InvalidConfiguration();
            uint256 amount = IERC20(token).balanceOf(address(this));
            if (amount == 0) continue;
            uint256 beforeFXN = FXN.balanceOf(address(this));
            IERC20(token).forceApprove(converter, amount);
            IFXNRewardConverter(converter).convert(token, address(FXN), amount, minimumFXNOut[i]);
            IERC20(token).forceApprove(converter, 0);
            uint256 gained = FXN.balanceOf(address(this)) - beforeFXN;
            if (gained < minimumFXNOut[i]) revert InsufficientOutput();
            directFXN += gained;
        }
        if (directFXN != 0) {
            uint256 compounded = Math.mulDiv(directFXN, compoundBps, BPS);
            if (compounded != 0) _addLiquidity(compounded, 0, 0);
            returnedFXN = directFXN - compounded;
            if (returnedFXN != 0) FXN.safeTransfer(MASTER, returnedFXN);
            emit YieldProcessed(directFXN, compounded, returnedFXN);
        }
    }
}