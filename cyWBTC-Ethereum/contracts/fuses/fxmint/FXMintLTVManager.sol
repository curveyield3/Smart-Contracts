// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IFuseCommon} from "../IFuseCommon.sol";
import {IFuseInstantWithdraw} from "../IFuseInstantWithdraw.sol";
import {FuseAction} from "../../interfaces/IPlasmaVault.sol";

interface IFXMintManagerPosition {
    function ownerOf(uint256 id) external view returns (address);
    function getPosition(uint256 id) external view returns (uint256 rawCollateral, uint256 rawDebt);
    function getDebtRatioRange() external view returns (uint256 minRatio, uint256 maxRatio);
    function priceOracle() external view returns (address);
    function configuration() external view returns (address);
    function poolManager() external view returns (address);
    function fxUSD() external view returns (address);
    function collateralToken() external view returns (address);
}
interface IFXMintManagerOracle {
    function getExchangePrice() external view returns (uint256);
}
interface IFXMintManagerPoolFees {
    function getPoolFeeRatio(address pool, address recipient)
        external view returns (uint256 supplyFee, uint256 withdrawFee, uint256 borrowFee, uint256 repayFee);
}
interface IFXMintManagerPoolManager {
    function getTokenScalingFactor(address token) external view returns (uint256);
}
interface IFXMintManagerPositionRegistry {
    function positionId() external view returns (uint256);
}
interface IFXMintManagerConfig {
    function targetLtvWad() external view returns (uint256);
    function withdrawSlippageBps() external view returns (uint256);
    function isFinalizingScheduledWithdrawal() external view returns (bool);
}
interface IFXMintManagerVault {
    function executeInternal(FuseAction[] calldata actions) external;
    function execute(FuseAction[] calldata actions) external;
    function updateMarketsBalances(uint256[] calldata marketIds) external returns (uint256);
    function redeemFromRequest(uint256 shares, address receiver, address owner) external returns (uint256);
    function getManagementFeeData() external view returns (address, uint16, uint32);
    function getPerformanceFeeData() external view returns (address, uint16);
}
interface IFXMintWithdrawManager {
    struct WithdrawRequestInfo {
        uint256 shares;
        uint256 endWithdrawWindowTimestamp;
        bool canWithdraw;
        uint256 withdrawWindowInSeconds;
    }
    function requestInfo(address user) external view returns (WithdrawRequestInfo memory);
    function releaseFunds(uint256 timestamp, uint256 sharesToRelease) external;
}
interface IFxSPNavForManager {
    function nav() external view returns (uint256);
    function redeemRequests(address account) external view returns (uint128 amount, uint128 unlockAt);
}
interface IFXMintConvexReader {
    function REGISTRY() external view returns (address);
}
interface IFXMintConvexRegistry {
    function vaultMap(uint256 pid, address owner) external view returns (address);
}

/// @notice fxMINT LTV logic plus ONE public, globally pending, native-IPOR withdrawal request.
/// @dev Own storage holds only target/slippage/pending request. All PlasmaVault protocol operations
///      go through registered IPOR execution fuses. No Yearn/Morpho/Aave adapter or strategy allocator.
struct FxSPEnterData { address vault; uint256 vaultAssetAmount; uint256 minSharesOut; }
struct FxSPExitData { address vault; uint256 shares; }
struct ConvexGaugeEnterData { address childLiquidityGauge; uint256 lpTokenAmount; }
struct ConvexGaugeExitData { address childLiquidityGauge; uint256 lpTokenAmount; }
struct IPORSwapData { address[] targets; bytes[] data; }
struct IPORSwapEnterData { address tokenIn; address tokenOut; uint256 amountIn; uint256 minAmountOut; IPORSwapData data; }

contract FXMintLTVManager is IFuseCommon, IFuseInstantWithdraw {
    uint256 private constant WAD = 1e18;
    uint256 private constant FEE_PRECISION = 1e9;
    uint256 private constant BPS = 10_000;
    uint256 private constant MIN_SLIPPAGE_BPS = 5;
    uint256 private constant MAX_SLIPPAGE_BPS = 55;
    uint256 private constant RAW_DEBT_BUFFER = 1e12;
    uint256 private constant MIN_REPAY_RESERVE_BPS = 30;
    uint256 private constant WITHDRAW_LTV_IMPROVEMENT_WAD = 1e16;
    uint256 private constant WITHDRAW_ROUNDING_HEADROOM_WAD = 1e14;
    uint256 private constant FXSP_COOLDOWN = 1 hours;
    /// @dev IPOR calls its instant-withdraw queue repeatedly inside a single
    /// redeem(), including reserve/slippage-buffer attempts. f(x) permits only
    /// one PoolManager.operate per transaction (EIP-1153 transient lock).
    /// Therefore do not perform a second collateral exit in the same tx.
    bytes32 private constant INSTANT_FXMINT_EXIT_USED_SLOT =
        keccak256("curveyield.cywbtc.fxmint.instant-withdraw.pool-operate.used.v1");
    // IPOR can increase a share-redemption payout after refreshing market NAV
    // during its ten liquidity-collection attempts. fxMINT cannot be entered
    // twice in the same tx; fund the first safe collateral release with a
    // bounded 25% margin. All existing live debt/LTV checks remain mandatory.
    uint256 private constant INSTANT_LIQUIDITY_MARGIN_BPS = 2_500;
    uint256 private constant COLLATERAL_RECOVERY_SWAP_BUFFER_BPS = 300;

    struct Addresses {
        address vault;
        address owner;
        address balanceFuse;
        address fxMintPool;
        address poolManager;
        address wbtc;
        address fxusd;
        address fxn;
        address fxsp;
        address fxMintBorrowFuse;
        address fxMintCollateralFuse;
        address convexStakeFuse;
        address fxspSupplyFuse;
        address convexGauge;
        address omniSwapFuse;
        address omniRouter;
        address usdc;
        address withdrawManager;
    }
    struct Withdrawal {
        uint256 id;
        uint256 initialCollateral;
        uint256 initialDebt;
        uint256 exchangePrice;
        uint256 initialLtv;
        uint256 collateralReleaseWBTC;
        uint256 netWBTCNeeded;
        uint256 debtReduction;
        uint256 target;
        uint256 desiredFinalLtv;
    }
    struct PendingRequest {
        address user;
        uint256 shares;
        uint256 nftId;
        uint256 debtReduction;
        uint256 collateralReleaseWBTC;
        uint256 fxspShares;
        uint256 unlockAt;
        uint8 stage; // 0=cooldown, 1=release recovery collateral, 2=finish repay, 3=final WBTC redemption.
    }

    address public immutable VERSION;
    uint256 public constant MARKET_ID = 49;
    address public immutable VAULT;
    address public immutable OWNER;
    address public immutable POSITION_REGISTRY;
    address public immutable POOL;
    address public immutable POOL_MANAGER;
    address public immutable WBTC;
    address public immutable FXUSD;
    address public immutable FXN;
    address public immutable FXSP;
    address public immutable FXMINT_BORROW_FUSE;
    address public immutable FXMINT_COLLATERAL_FUSE;
    address public immutable CONVEX_STAKE_FUSE;
    address public immutable FXSP_SUPPLY_FUSE;
    address public immutable CONVEX_GAUGE;
    address public immutable OMNI_SWAP_FUSE;
    address public immutable OMNI_ROUTER;
    address public immutable USDC;
    address public immutable WITHDRAW_MANAGER;

    // Stored in this deployed manager contract, not in the PlasmaVault delegatecall storage slots.
    uint256 public targetLtvWad;
    uint256 public withdrawSlippageBps;
    PendingRequest public pendingRequest;
    uint256 private _status = 1;
    modifier nonReentrant() { if (_status != 1) revert InvalidConfiguration(); _status=2; _; _status=1; }

    error IncorrectExecutionContext();
    error OnlyOwner();
    error InvalidConfiguration();
    error InvalidTarget(uint256 target);
    error InvalidSlippage(uint256 bps);
    error InvalidPosition(uint256 id);
    error InvalidPrice();
    error InvalidAmount();
    error InsufficientCollateral(uint256 required, uint256 available);
    error InsufficientLiquidity(uint256 needed, uint256 available);
    error InsufficientFxUSDForRepayment(uint256 needed, uint256 available);
    error ProtocolDebtRatioNotReachable(uint256 projectedLtv, uint256 protocolMinimum);
    error UnsafeLtv(uint256 actualLtv, uint256 maximumLtv);
    error DebtRepaymentRequiresScheduledWithdrawal(uint256 requiredFxUSD);
    error PendingNotMature(uint256 unlockAt);
    error NoPendingRequest();
    error PendingWithdrawalAlreadyActive();
    error InvalidFulfillStage(uint8 stage);
    error InvalidWithdrawRequest(address user);
    error FuseExecutionFailed(bytes reason);
    error UnexpectedVaultBalance(uint256 needed, uint256 actual);
    error UnexpectedPositionChange();

    event TargetLtvSet(uint256 oldTarget, uint256 newTarget);
    event WithdrawSlippageSet(uint256 oldBps, uint256 newBps);
    event CollateralWithdrawal(uint256 indexed id, uint256 grossWBTC, uint256 netWBTC, uint256 debtReduction);
    event DebtRebalanced(uint256 indexed id, uint256 debtReduction);
    event TargetWindUp(uint256 indexed id, uint256 nominalBorrow, uint256 fxUSDDeposited);
    event WithdrawRequestInitialized(address indexed user, uint256 shares, uint256 fxspShares, uint256 unlockAt);
    event WithdrawRequestFinalized(address indexed user, uint256 shares, uint256 releasedWBTC);
    event WithdrawRequestAdvanced(address indexed user, uint8 stage, uint256 debtRemaining);

    constructor(Addresses memory a, uint256 initialTargetLtvWad) {
        if (a.vault == address(0) || a.owner == address(0) || a.balanceFuse == address(0) ||
            a.fxMintPool == address(0) || a.poolManager == address(0) || a.wbtc == address(0) ||
            a.fxusd == address(0) || a.fxn == address(0) || a.fxsp == address(0) ||
            a.fxMintBorrowFuse == address(0) || a.fxMintCollateralFuse == address(0) ||
            a.convexStakeFuse == address(0) || a.fxspSupplyFuse == address(0) ||
            a.convexGauge == address(0) || a.omniSwapFuse == address(0) ||
            a.omniRouter == address(0) || a.usdc == address(0) || a.withdrawManager == address(0)) revert InvalidConfiguration();
        IFXMintManagerPosition p = IFXMintManagerPosition(a.fxMintPool);
        if (p.poolManager() != a.poolManager || p.fxUSD() != a.fxusd || p.collateralToken() != a.wbtc ||
            IFuseCommon(a.fxMintBorrowFuse).MARKET_ID() != MARKET_ID ||
            IFuseCommon(a.fxMintCollateralFuse).MARKET_ID() != MARKET_ID ||
            IFuseCommon(a.balanceFuse).MARKET_ID() != MARKET_ID ||
            IFuseCommon(a.convexStakeFuse).MARKET_ID() != 17 ||
            IFuseCommon(a.fxspSupplyFuse).MARKET_ID() != 16 ||
            IFuseCommon(a.omniSwapFuse).MARKET_ID() != 12) revert InvalidConfiguration();
        VERSION = address(this);
        VAULT = a.vault;
        OWNER = a.owner;
        POSITION_REGISTRY = a.balanceFuse;
        POOL = a.fxMintPool;
        POOL_MANAGER = a.poolManager;
        WBTC = a.wbtc;
        FXUSD = a.fxusd;
        FXN = a.fxn;
        FXSP = a.fxsp;
        FXMINT_BORROW_FUSE = a.fxMintBorrowFuse;
        FXMINT_COLLATERAL_FUSE = a.fxMintCollateralFuse;
        CONVEX_STAKE_FUSE = a.convexStakeFuse;
        FXSP_SUPPLY_FUSE = a.fxspSupplyFuse;
        CONVEX_GAUGE = a.convexGauge;
        OMNI_SWAP_FUSE = a.omniSwapFuse;
        OMNI_ROUTER = a.omniRouter;
        USDC = a.usdc;
        WITHDRAW_MANAGER = a.withdrawManager;
        withdrawSlippageBps = 20;
        _validateTarget(initialTargetLtvWad);
        targetLtvWad = initialTargetLtvWad;
    }

    function setTargetLtvWad(uint256 target) external {
        _onlyOwnerImplementation();
        _validateTarget(target);
        emit TargetLtvSet(targetLtvWad, target);
        targetLtvWad = target;
    }

    /// @notice True only while the manager is executing an already-pending
    ///         scheduled withdrawal. No additional storage or executor authority.
    function isFinalizingScheduledWithdrawal() external view returns (bool) {
        return address(this) == VERSION && _status == 2 && pendingRequest.user != address(0);
    }

    function setWithdrawSlippageBps(uint256 bps) external {
        _onlyOwnerImplementation();
        if (bps < MIN_SLIPPAGE_BPS || bps > MAX_SLIPPAGE_BPS) revert InvalidSlippage(bps);
        emit WithdrawSlippageSet(withdrawSlippageBps, bps);
        withdrawSlippageBps = bps;
    }

    /// @dev This is invoked by IPOR's *existing instant withdraw queue* in PlasmaVault delegatecall context.
    ///      params[0] is only the WBTC shortfall after idle vault WBTC. Never repay debt here.
    function instantWithdraw(bytes32[] calldata params) external override {
        _onlyVaultDelegatecall();
        // IPOR redeemFromRequest() asks its instant queue for BOTH the requested
        // assets and already-released reserved assets. While _finalize() is
        // redeeming an already-funded scheduled request, a second fxMINT exit
        // would be unnecessary and could revert on the LTV guard.
        if (IFXMintManagerConfig(VERSION).isFinalizingScheduledWithdrawal()) return;
        if (params.length != 1) revert InvalidAmount();
        // The first call obtains enough underlying for ERC4626 redemption;
        // repeated calls request an optional additional liquidity buffer.
        // A second f(x) operate in the same tx always reverts due its native
        // transient lock. If actual payout lacks WBTC the ERC4626 transfer
        // still reverts atomically; this never fabricates collateral/liquidity.
        bytes32 usedSlot = INSTANT_FXMINT_EXIT_USED_SLOT;
        uint256 used;
        assembly ("memory-safe") { used := tload(usedSlot) }
        if (used != 0) return;
        uint256 shortfall = uint256(params[0]);
        if (shortfall == 0) return;
        uint256 prefunded = shortfall + Math.mulDiv(
            shortfall, INSTANT_LIQUIDITY_MARGIN_BPS, BPS, Math.Rounding.Up);
        Withdrawal memory s = _prepareWithdrawal(prefunded);
        if (s.debtReduction != 0) revert DebtRepaymentRequiresScheduledWithdrawal(s.debtReduction);
        uint256 currentDebt = s.initialDebt;
        uint256 remainingRaw = _remainingRawCollateral(s.collateralReleaseWBTC, s.initialCollateral);
        uint256 newLtv = _ltv(remainingRaw, currentDebt, _exchangePrice());
        if (newLtv > s.target) revert DebtRepaymentRequiresScheduledWithdrawal(currentDebt);
        _executeOne(FXMINT_COLLATERAL_FUSE,
            abi.encodeWithSignature("exit(uint256,uint256,uint256)", s.id, s.collateralReleaseWBTC, s.netWBTCNeeded));
        assembly ("memory-safe") { tstore(usedSlot, 1) }
        emit CollateralWithdrawal(s.id, s.collateralReleaseWBTC, shortfall, 0);
    }

    /// @notice Owner/Alpha action: borrow to current target and invest in this one fxSP -> Convex market.
    function rebalanceUp(uint256 minFxspSharesOut) external {
        _onlyVaultDelegatecall();
        _rebalanceUp(minFxspSharesOut);
    }

    /// @notice Owner/Alpha action: compound FXN already claimed to the PlasmaVault into collateral and new yield.
    /// @dev Convex user-vault getReward() is already permissionless and sends its FXN to the vault owner;
    ///      no reward-claim fuse or additional custody contract is needed.
    function compound(uint256 minFxspSharesOut) external {
        _onlyVaultDelegatecall();
        uint256 fxn = IERC20(FXN).balanceOf(address(this));
        if (fxn != 0) _swap(FXN, WBTC, fxn);
        _rebalanceUp(minFxspSharesOut);
    }

    /// @notice Owner/Alpha may repay using already idle fxUSD; NO immediate Convex/fxSP unstake/redeem.
    function rebalanceDown() external {
        _onlyVaultDelegatecall();
        uint256 id = _positionId();
        (uint256 collateral, uint256 debt) = _position(id);
        if (collateral == 0 || debt == 0) return;
        uint256 allowed = Math.mulDiv(Math.mulDiv(collateral, _exchangePrice(), WAD), _liveTarget(), WAD);
        if (debt <= allowed) return;
        uint256 reduction = debt - allowed;
        _precheckIntermediateDebtRatio(Math.mulDiv(collateral, _exchangePrice(), WAD), debt, reduction);
        _repayFromIdle(id, reduction);
        (, uint256 remainingDebt) = _position(id);
        if (remainingDebt > allowed) revert UnsafeLtv(_ltv(collateral, remainingDebt, _exchangePrice()), _liveTarget());
        emit DebtRebalanced(id, debt - remainingDebt);
    }

    /// @notice The FIRST permissionless button forwards here. Only one request globally.
    function initializeFulfillWithdrawRequest(address user) external nonReentrant {
        _onlyImplementation();
        PendingRequest memory prior = pendingRequest;
        // f(x) PoolConfiguration permits only ONE operate per transaction.
        // A matured request may require several permissionless finalize calls;
        // never overwrite its state by auto-starting another user's request.
        if (prior.user != address(0)) revert PendingWithdrawalAlreadyActive();
        IFXMintWithdrawManager.WithdrawRequestInfo memory r = IFXMintWithdrawManager(WITHDRAW_MANAGER).requestInfo(user);
        if (user == address(0) || r.shares == 0 ||
            r.endWithdrawWindowTimestamp <= block.timestamp + FXSP_COOLDOWN ||
            IERC20(VAULT).allowance(user, VERSION) < r.shares) revert InvalidWithdrawRequest(user);

        // Vault totalAssets() reflects IPOR's last recorded market balances,
        // which can lag real f(x) prices during a WBTC rally and subsequent
        // reversal. Recompute the strategy NAV before quoting share redemption;
        // otherwise a safe instant exit can make a later 100% exit appear to
        // require MORE WBTC than remains as collateral.
        uint256[] memory markets = new uint256[](4);
        markets[0] = MARKET_ID; // fxMINT NFT net of debt
        markets[1] = 17; // Convex personal vault
        markets[2] = 16; // idle fxSP
        markets[3] = 7; // idle stablecoin and reward positions
        IFXMintManagerVault(VAULT).updateMarketsBalances(markets);

        Withdrawal memory s;
        if (_isEntireUserCapitalExit(user, r.shares)) {
            // Full user exit is NOT a partial collateral withdrawal. A vault
            // holding idle stablecoins can have NAV greater than its fxMINT
            // collateral alone; estimating gross NFT release from that NAV
            // incorrectly reverts InsufficientCollateral. Closing the whole
            // position must instead repay its actual debt and withdraw all
            // remaining NFT collateral in a single protocol operation.
            s.id = _positionId();
            (s.initialCollateral, s.initialDebt) = _position(s.id);
            if (s.initialCollateral == 0 || s.initialDebt == 0) revert InvalidAmount();
            s.debtReduction = s.initialDebt;
            s.collateralReleaseWBTC = type(uint256).max;
        } else {
            uint256 desiredWBTC = IERC4626(VAULT).convertToAssets(r.shares);
            uint256 idleWBTC = IERC20(WBTC).balanceOf(VAULT);
            if (desiredWBTC <= idleWBTC) revert InvalidAmount();
            s = _prepareWithdrawal(desiredWBTC - idleWBTC);
            if (s.debtReduction == 0) revert InvalidAmount();
        }
        uint256 debtBudget = _repayBudget(s.debtReduction);
        uint256 idleFxUSD = IERC20(FXUSD).balanceOf(VAULT);
        if (idleFxUSD >= debtBudget) revert InvalidAmount(); // no delayed redemption required
        (uint256 shares, uint256 unlockAt) = _requestExistingFxsp(
            debtBudget - idleFxUSD, debtBudget, s.collateralReleaseWBTC == type(uint256).max);
        pendingRequest = PendingRequest({
            user: user, shares: r.shares, nftId: s.id, debtReduction: s.debtReduction,
            collateralReleaseWBTC: s.collateralReleaseWBTC, fxspShares: shares, unlockAt: unlockAt, stage: 0
        });
        emit WithdrawRequestInitialized(user, r.shares, shares, unlockAt);
    }

    /// @notice Treat a request for all non-fee-owned shares as the last user exit.
    /// @dev IPOR may mint management/performance fee shares during an earlier
    ///      partial withdrawal. Total supply is then slightly larger than the
    ///      final user's shares. Comparing to totalSupply alone wrongly leaves a
    ///      nonzero fxMINT debt on the last user's exit. Exclude only verified
    ///      fee-account balances; any other user's shares prevent full closure.
    function _isEntireUserCapitalExit(address user, uint256 requestedShares) private view returns (bool) {
        if (requestedShares == 0 || IERC20(VAULT).balanceOf(user) < requestedShares) return false;
        uint256 supply = IERC20(VAULT).totalSupply();
        if (requestedShares == supply) return true;
        (address managementAccount,,) = IFXMintManagerVault(VAULT).getManagementFeeData();
        (address performanceAccount,) = IFXMintManagerVault(VAULT).getPerformanceFeeData();
        uint256 feeShares;
        if (managementAccount != address(0) && managementAccount != user) {
            feeShares = IERC20(VAULT).balanceOf(managementAccount);
        }
        if (performanceAccount != address(0) && performanceAccount != user
            && performanceAccount != managementAccount) {
            feeShares += IERC20(VAULT).balanceOf(performanceAccount);
        }
        // IPOR charges deposit AND native request fees in VAULT shares to
        // WithdrawManager itself, not to the DAO management/performance accounts.
        // These are fee-owned shares, not an active investor position.
        if (WITHDRAW_MANAGER != user && WITHDRAW_MANAGER != managementAccount
            && WITHDRAW_MANAGER != performanceAccount) {
            feeShares += IERC20(VAULT).balanceOf(WITHDRAW_MANAGER);
        }
        return feeShares <= supply && requestedShares == supply - feeShares;
    }

    /// @dev Isolated so public request bookkeeping remains within the non-viaIR
    ///      compiler stack budget. Caps to real idle + Convex-personal staked fxSP.
    function _requestExistingFxsp(uint256 neededFxUSD, uint256 requiredBudget, bool fullExit)
        private returns (uint256 shares, uint256 unlockAt)
    {
        uint256 nav = IFxSPNavForManager(FXSP).nav();
        if (nav == 0) revert InvalidPrice();
        shares = Math.mulDiv(neededFxUSD, WAD, nav, Math.Rounding.Up);
        uint256 idle = IERC20(FXSP).balanceOf(VAULT);
        address registry = IFXMintConvexReader(CONVEX_STAKE_FUSE).REGISTRY();
        address personal = IFXMintConvexRegistry(registry).vaultMap(37, VAULT);
        uint256 staked = personal == address(0) ? 0 : IERC20(CONVEX_GAUGE).balanceOf(personal);
        uint256 availableShares = idle + staked;
        // At the last investor exit all remaining Convex/fxSP principal must
        // become liquid WBTC, not merely the shares needed to repay fxMINT debt.
        // Leaving staked assets behind makes ERC4626 redeemFromRequest attempt
        // to pay their NAV without the underlying WBTC in vault custody.
        if (fullExit) shares = availableShares;
        else if (shares > availableShares) shares = availableShares;
        if (shares == 0) revert InsufficientLiquidity(requiredBudget, 0);
        if (shares > idle) {
            _executeOne(CONVEX_STAKE_FUSE, abi.encodeWithSignature(
                "exit((address,uint256))", ConvexGaugeExitData(CONVEX_GAUGE, shares - idle)));
        }
        _executeOne(FXSP_SUPPLY_FUSE, abi.encodeWithSignature(
            "exit((address,uint256))", FxSPExitData(FXSP, shares)));
        (, uint128 matureAt) = IFxSPNavForManager(FXSP).redeemRequests(VAULT);
        unlockAt = uint256(matureAt);
        if (unlockAt < block.timestamp + FXSP_COOLDOWN) revert InvalidConfiguration();
    }

    /// @notice The SECOND permissionless button. No input and no separate execution state machine.
    function finalizeFulfillWithdrawRequest() external nonReentrant {
        _onlyImplementation();
        _finalize();
    }

    /// @notice Advance one native-IPOR scheduled exit step PER transaction.
    /// @dev f(x) PoolConfiguration.lock uses transient storage and does not
    ///      allow two PoolManager.operate calls within one transaction. The
    ///      public FinalizeFulfillWithdrawRequest button may be called again
    ///      permissionlessly after each advancing step. Each step is atomic.
    function _finalize() private {
        PendingRequest storage p = pendingRequest;
        if (p.user == address(0)) revert NoPendingRequest();
        if (block.timestamp < p.unlockAt) revert PendingNotMature(p.unlockAt);
        uint8 stage = p.stage;
        if (stage == 0) {
            // First mature finalization transaction: release real fxSP yield
            // and spend at most one permitted fxMINT PoolManager operation.
            _executeOne(FXSP_SUPPLY_FUSE, abi.encodeWithSignature(
                "finalizeExit((address,uint256))", FxSPExitData(FXSP, p.fxspShares)));
            uint256 usdc = IERC20(USDC).balanceOf(VAULT);
            if (usdc != 0) _swap(USDC, FXUSD, usdc);
            uint256 desiredReduction = p.debtReduction;
            if (p.collateralReleaseWBTC == type(uint256).max) {
                (, desiredReduction) = _position(p.nftId); // include any accrued debt
            }
            if (IERC20(FXUSD).balanceOf(VAULT) >= _repayBudget(desiredReduction)) {
                if (p.collateralReleaseWBTC == type(uint256).max) {
                    _closeEntirePositionAndRedeem(); // one f(x) operate: full debt+collateral
                    return;
                }
                _repayFromIdle(p.nftId, desiredReduction);
                p.debtReduction = 0;
                p.stage = 3;
            } else {
                p.debtReduction = _repayAvailableScheduledFxUSD(p.nftId, desiredReduction);
                p.stage = 1;
            }
            emit WithdrawRequestAdvanced(p.user, p.stage, p.debtReduction);
            return;
        }
        if (stage == 1) {
            // One separate fxMINT operate to release safe WBTC, then the
            // existing approved WBTC->USDC->fxUSD route prepares repayment.
            _sellCollateralForRemainingDebt(p.nftId, p.debtReduction);
            p.stage = 2;
            emit WithdrawRequestAdvanced(p.user, 2, p.debtReduction);
            return;
        }
        if (stage == 2) {
            // Entire NFT closure must repay debt AND withdraw collateral in
            // one operate; f(x) rejects standalone full repay with collateral.
            if (p.collateralReleaseWBTC == type(uint256).max) {
                _closeEntirePositionAndRedeem();
                return;
            }
            _repayFromIdle(p.nftId, p.debtReduction);
            p.debtReduction = 0;
            p.stage = 3;
            emit WithdrawRequestAdvanced(p.user, 3, 0);
            return;
        }
        if (stage == 3) {
            // Final separate transaction: one fxMINT collateral exit plus
            // IPOR native share release/redemption (no additional fxMINT call).
            _releasePendingCollateralAndShares();
            return;
        }
        revert InvalidFulfillStage(stage);
    }

    /// @notice End-of-life close, entire share supply requested. This entire
    ///         sequence uses exactly one f(x) PoolManager operation.
    /// @notice Full-close on a single fxMINT operate: repay debt and remove collateral.
    function _closeEntirePositionAndRedeem() private {
        PendingRequest memory p = pendingRequest;
        (uint256 collateral, uint256 debt) = _position(p.nftId);
        if (collateral == 0) revert InvalidAmount();
        uint256 budget = _repayBudget(debt);
        uint256 availableFxUSD = IERC20(FXUSD).balanceOf(VAULT);
        if (availableFxUSD < budget) revert InsufficientFxUSDForRepayment(budget, availableFxUSD);
        _executeOne(FXMINT_COLLATERAL_FUSE, abi.encodeWithSignature(
            "exitAndRepayFull(uint256,uint256,uint256)",
            p.nftId, budget, uint256(0)));
        // The IPOR vault prices idle fxUSD in totalAssets even after the
        // final fxMINT debt is closed. A 100%-share redemption must first
        // settle that remaining non-WBTC exposure into the WBTC underlying,
        // or redeemFromRequest can attempt to transfer more WBTC than exists.
        uint256 residualFxUSD = IERC20(FXUSD).balanceOf(VAULT);
        if (residualFxUSD != 0) _swap(FXUSD, WBTC, residualFxUSD);
        _releaseNativeRequestShares(p);
    }

    /// @dev For a partial exit, collateralFuse.exit already checks LIVE LTV
    ///      after the actual protocol call; do not duplicate that same check.
    function _releasePendingCollateralAndShares() private {
        PendingRequest memory p = pendingRequest;
        (uint256 collateral,) = _position(p.nftId);
        uint256 scaling = IFXMintManagerPoolManager(POOL_MANAGER).getTokenScalingFactor(WBTC);
        if (scaling == 0) revert InvalidConfiguration();
        uint256 available = Math.mulDiv(collateral, WAD, scaling);
        uint256 releaseWBTC = p.collateralReleaseWBTC < available
            ? p.collateralReleaseWBTC : available;
        if (releaseWBTC != 0) _executeOne(FXMINT_COLLATERAL_FUSE,
            abi.encodeWithSignature("exit(uint256,uint256,uint256)", p.nftId, releaseWBTC, uint256(0)));
        _releaseNativeRequestShares(p);
    }

    function _releaseNativeRequestShares(PendingRequest memory p) private {
        IFXMintWithdrawManager(WITHDRAW_MANAGER).releaseFunds(block.timestamp - 1, p.shares);
        uint256 released = IFXMintManagerVault(VAULT).redeemFromRequest(p.shares, p.user, p.user);
        delete pendingRequest;
        emit WithdrawRequestFinalized(p.user, p.shares, released);
    }

    function _rebalanceUp(uint256 minFxspSharesOut) private {
        uint256 id = _positionId();
        _supplyAllIdleWBTC(id);
        (uint256 collateral, uint256 debt) = _position(id);
        if (collateral == 0) revert InvalidPosition(id);
        uint256 allowed = Math.mulDiv(Math.mulDiv(collateral, _exchangePrice(), WAD), _liveTarget(), WAD);
        if (debt >= allowed) return;
        uint256 borrow = allowed - debt;
        if (borrow > RAW_DEBT_BUFFER) borrow -= RAW_DEBT_BUFFER;
        if (borrow == 0) return;
        uint256 prior = IERC20(FXUSD).balanceOf(address(this));
        _executeOne(FXMINT_BORROW_FUSE,
            abi.encodeWithSignature("enter(uint256,uint256,uint256)", id, borrow, uint256(0)));
        uint256 received = IERC20(FXUSD).balanceOf(address(this)) - prior;
        if (received == 0) revert InsufficientLiquidity(borrow, 0);
        uint256 fxspBefore = IERC20(FXSP).balanceOf(address(this));
        _executeOne(FXSP_SUPPLY_FUSE,
            abi.encodeWithSignature("enter((address,uint256,uint256))", FxSPEnterData(FXSP, received, minFxspSharesOut)));
        uint256 mintedShares = IERC20(FXSP).balanceOf(address(this)) - fxspBefore;
        _executeOne(CONVEX_STAKE_FUSE,
            abi.encodeWithSignature("enter((address,uint256))", ConvexGaugeEnterData(CONVEX_GAUGE, mintedShares)));
        emit TargetWindUp(id, borrow, received);
    }

    function previewWithdrawal(uint256 shortfallWBTC)
        external view returns (uint256 grossWBTCToRelease, uint256 debtToReduce, uint256 projectedLtv)
    {
        Withdrawal memory s = _prepareWithdrawal(shortfallWBTC);
        return (s.collateralReleaseWBTC, s.debtReduction,
            _ltvAfter(s.initialCollateral, s.initialDebt, s.exchangePrice, s.collateralReleaseWBTC, s.debtReduction));
    }

    /// @dev Original v17 fxMINT LTV policy and fee/rounding mathematics retained.
    function _prepareWithdrawal(uint256 netWBTCNeeded) private view returns (Withdrawal memory s) {
        if (netWBTCNeeded == 0) revert InvalidAmount();
        s.id = _positionId();
        (s.initialCollateral, s.initialDebt) = _position(s.id);
        if (s.initialCollateral == 0) revert InsufficientCollateral(netWBTCNeeded, 0);
        s.exchangePrice = _exchangePrice();
        s.target = _liveTarget();
        s.initialLtv = _ltv(s.initialCollateral, s.initialDebt, s.exchangePrice);
        (, uint256 withdrawFee, , ) = _feeRatios();
        if (withdrawFee >= FEE_PRECISION) revert InvalidConfiguration();
        s.collateralReleaseWBTC = Math.mulDiv(
            netWBTCNeeded, FEE_PRECISION, FEE_PRECISION - withdrawFee, Math.Rounding.Up
        );
        s.netWBTCNeeded = netWBTCNeeded;
        uint256 scaling = IFXMintManagerPoolManager(POOL_MANAGER).getTokenScalingFactor(WBTC);
        if (scaling == 0) revert InvalidConfiguration();
        uint256 requestedRaw = Math.mulDiv(s.collateralReleaseWBTC, scaling, WAD);
        if (requestedRaw > s.initialCollateral) revert InsufficientCollateral(requestedRaw, s.initialCollateral);
        if (requestedRaw == 0) revert InvalidAmount();
        uint256 riskRelease = requestedRaw + (scaling / WAD) + 1;
        if (riskRelease > s.initialCollateral) riskRelease = s.initialCollateral;
        uint256 originalCollateralUsd = Math.mulDiv(s.initialCollateral, s.exchangePrice, WAD);
        uint256 postCollateralUsd = Math.mulDiv(s.initialCollateral - riskRelease, s.exchangePrice, WAD);
        if (originalCollateralUsd == 0) revert InvalidPrice();
        if (s.initialLtv > s.target + WITHDRAW_LTV_IMPROVEMENT_WAD) {
            uint256 onePointLower = s.initialLtv - WITHDRAW_LTV_IMPROVEMENT_WAD;
            if (onePointLower > s.target + WITHDRAW_ROUNDING_HEADROOM_WAD) {
                s.desiredFinalLtv = onePointLower - WITHDRAW_ROUNDING_HEADROOM_WAD;
            } else s.desiredFinalLtv = s.target;
        } else if (s.initialLtv > s.target) s.desiredFinalLtv = s.initialLtv;
        else s.desiredFinalLtv = s.target;
        if (s.initialDebt != 0) {
            uint256 allowedDebt = Math.mulDiv(postCollateralUsd, s.desiredFinalLtv, WAD);
            if (s.initialDebt > allowedDebt) {
                s.debtReduction = s.initialDebt - allowedDebt;
                uint256 debtLeft = s.initialDebt - s.debtReduction;
                if (debtLeft > RAW_DEBT_BUFFER) s.debtReduction += RAW_DEBT_BUFFER;
            }
        }
    }

    function _repayBudget(uint256 debtReduction) private view returns (uint256 budget) {
        (, , , uint256 liveRepayFee) = _feeRatios();
        if (liveRepayFee >= FEE_PRECISION) revert InvalidConfiguration();
        uint256 reserve = IFXMintManagerConfig(VERSION).withdrawSlippageBps();
        if (reserve < MIN_SLIPPAGE_BPS || reserve > MAX_SLIPPAGE_BPS) revert InvalidSlippage(reserve);
        uint256 feeBps = Math.mulDiv(liveRepayFee, BPS, FEE_PRECISION, Math.Rounding.Up);
        if (feeBps < MIN_REPAY_RESERVE_BPS) feeBps = MIN_REPAY_RESERVE_BPS;
        budget = debtReduction + Math.mulDiv(debtReduction, feeBps + reserve, BPS, Math.Rounding.Up)
            + RAW_DEBT_BUFFER;
    }

    /// @notice Scheduled-only debt repayment recovery when redeemed fxSP is
    ///         insufficient to cover both principal and fees. First repay from
    ///         actual fxUSD, then release a small SAFE amount of WBTC and swap it
    ///         using the existing WBTC->USDC->fxUSD OmniRouter configuration.
    /// @dev Neither the normal user instant redemption nor instantWithdraw calls
    ///      this function. Each withdrawal checks the live configured LTV.
    function _repayAvailableScheduledFxUSD(uint256 id, uint256 requestedReduction)
        private returns (uint256 remainingToRepay)
    {
        (uint256 rawCollateral, uint256 initialDebt) = _position(id);
        if (requestedReduction > initialDebt) requestedReduction = initialDebt;
        uint256 price = _exchangePrice();
        uint256 stableAvailable = IERC20(FXUSD).balanceOf(VAULT);
        (, , , uint256 liveRepayFee) = _feeRatios();
        uint256 feeBps = Math.mulDiv(liveRepayFee, BPS, FEE_PRECISION, Math.Rounding.Up);
        if (feeBps < MIN_REPAY_RESERVE_BPS) feeBps = MIN_REPAY_RESERVE_BPS;
        uint256 repayable = Math.mulDiv(stableAvailable, BPS,
            BPS + feeBps + IFXMintManagerConfig(VERSION).withdrawSlippageBps() + 100);
        if (repayable > requestedReduction) repayable = requestedReduction;
        (uint256 minDebtRatio,) = IFXMintManagerPosition(POOL).getDebtRatioRange();
        uint256 minResidual = Math.mulDiv(
            Math.mulDiv(rawCollateral, price, WAD), minDebtRatio, WAD, Math.Rounding.Up
        ) + RAW_DEBT_BUFFER;
        if (repayable != 0 && initialDebt - repayable < minResidual) {
            repayable = initialDebt > minResidual ? initialDebt - minResidual : 0;
        }
        if (repayable != 0) {
            _executeOne(FXMINT_BORROW_FUSE, abi.encodeWithSignature(
                "exit(uint256,uint256,bool,uint256)", id, repayable, false, stableAvailable));
        }
        (, uint256 debtAfter) = _position(id);
        if (debtAfter > initialDebt) revert UnexpectedPositionChange();
        uint256 repaid = initialDebt - debtAfter;
        remainingToRepay = requestedReduction > repaid ? requestedReduction - repaid : 0;
    }

    /// @dev Separate bounded branch so Solidity 0.8.30 compiles without viaIR.
    ///      The collateral side enforces the live target even if this check passes.
    function _sellCollateralForRemainingDebt(uint256 id, uint256 remainingToRepay) private {
        uint256 fullBudget = _repayBudget(remainingToRepay);
        uint256 idleStable = IERC20(FXUSD).balanceOf(VAULT);
        if (fullBudget > idleStable) {
            uint256 price = _exchangePrice();
            uint256 sell = Math.mulDiv(fullBudget - idleStable, 1e8, price, Math.Rounding.Up);
            sell = Math.mulDiv(sell, BPS + COLLATERAL_RECOVERY_SWAP_BUFFER_BPS,
                BPS, Math.Rounding.Up);
            if (sell == 0) revert InvalidAmount();
            // CollateralFuse.exit and fxMINT PoolManager enforce both
            // withdrawable collateral and live target LTV after the change.
            // No duplicate preflight calculations in the public manager.
            uint256 beforeWBTC = IERC20(WBTC).balanceOf(VAULT);
            _executeOne(FXMINT_COLLATERAL_FUSE,
                abi.encodeWithSignature("exit(uint256,uint256,uint256)", id, sell, uint256(0)));
            uint256 receivedWBTC = IERC20(WBTC).balanceOf(VAULT) - beforeWBTC;
            if (receivedWBTC == 0) revert InsufficientLiquidity(sell, 0);
            _swap(WBTC, FXUSD, receivedWBTC);
        }
    }

    function _repayFromIdle(uint256 id, uint256 debtReduction) private {
        if (debtReduction == 0) return;
        uint256 budget = _repayBudget(debtReduction);
        uint256 available = IERC20(FXUSD).balanceOf(VAULT);
        if (available < budget) revert InsufficientFxUSDForRepayment(budget, available);
        (, uint256 beforeDebt) = _position(id);
        bool full = debtReduction >= beforeDebt;
        _executeOne(FXMINT_BORROW_FUSE,
            abi.encodeWithSignature("exit(uint256,uint256,bool,uint256)", id, debtReduction, full, budget));
        (, uint256 afterDebt) = _position(id);
        if (afterDebt > beforeDebt || beforeDebt - afterDebt < debtReduction) revert UnexpectedPositionChange();
    }

    /// @dev Existing IPOR UniversalTokenSwapperFuse, using its existing executor and guards.
    ///      The executor must approve the routed token before OmniRouter.easyswap pulls it.
    function _swap(address tokenIn, address tokenOut, uint256 amount) private {
        if (amount == 0) return;
        address[] memory targets = new address[](2);
        targets[0] = tokenIn;
        targets[1] = OMNI_ROUTER;
        bytes[] memory callData = new bytes[](2);
        callData[0] = abi.encodeWithSignature("approve(address,uint256)", OMNI_ROUTER, amount);
        callData[1] = abi.encodeWithSignature("swap(address,address,uint256)", tokenIn, tokenOut, amount);
        // Bound to the deployed Ethereum IPOR UniversalTokenSwapperFuse v0.8.26,
        // whose verified ABI has TWO SwapData fields (targets, data). The
        // v0.8.30 source adds tokensToReturn and uses a different selector.
        _executeOne(OMNI_SWAP_FUSE, abi.encodeWithSignature(
            "enter((address,address,uint256,uint256,(address[],bytes[])))",
            IPORSwapEnterData(tokenIn, tokenOut, amount, 0, IPORSwapData(targets, callData))));
    }

    function _supplyAllIdleWBTC(uint256 id) private {
        uint256 idle = IERC20(WBTC).balanceOf(address(this));
        if (idle != 0) _executeOne(FXMINT_COLLATERAL_FUSE,
            abi.encodeWithSignature("enter(uint256,uint256)", id, idle));
    }

    function _precheckIntermediateDebtRatio(uint256 collateralUsd, uint256 debt, uint256 reduction) private view {
        (uint256 minRatio,) = IFXMintManagerPosition(POOL).getDebtRatioRange();
        uint256 projectedDebt = reduction >= debt ? 0 : debt - reduction;
        uint256 intermediate = Math.mulDiv(projectedDebt, WAD, collateralUsd);
        if (intermediate < minRatio) revert ProtocolDebtRatioNotReachable(intermediate, minRatio);
    }

    function _remainingRawCollateral(uint256 amountWBTC, uint256 totalRaw) private view returns (uint256) {
        uint256 scale = IFXMintManagerPoolManager(POOL_MANAGER).getTokenScalingFactor(WBTC);
        if (scale == 0) revert InvalidConfiguration();
        uint256 requested = Math.mulDiv(amountWBTC, scale, WAD, Math.Rounding.Up);
        return requested >= totalRaw ? 0 : totalRaw - requested;
    }

    function _ltvAfter(uint256 rawCollateral, uint256 debt, uint256 price, uint256 amountWBTC, uint256 debtReduction)
        private view returns (uint256)
    {
        return _ltv(_remainingRawCollateral(amountWBTC, rawCollateral),
            debtReduction >= debt ? 0 : debt - debtReduction, price);
    }

    function _ltv(uint256 rawCollateral, uint256 debt, uint256 price) private pure returns (uint256) {
        if (debt == 0) return 0;
        if (rawCollateral == 0) return type(uint256).max;
        uint256 usd = Math.mulDiv(rawCollateral, price, WAD);
        return usd == 0 ? type(uint256).max : Math.mulDiv(debt, WAD, usd, Math.Rounding.Up);
    }

    function _exchangePrice() private view returns (uint256 price) {
        price = IFXMintManagerOracle(IFXMintManagerPosition(POOL).priceOracle()).getExchangePrice();
        if (price == 0) revert InvalidPrice();
    }

    function _feeRatios() private view returns (uint256 supplyFee, uint256 withdrawFee, uint256 borrowFee, uint256 repayFee) {
        return IFXMintManagerPoolFees(IFXMintManagerPosition(POOL).configuration()).getPoolFeeRatio(POOL, VAULT);
    }

    function _positionId() private view returns (uint256 id) {
        id = IFXMintManagerPositionRegistry(POSITION_REGISTRY).positionId();
        if (id == 0 || IFXMintManagerPosition(POOL).ownerOf(id) != VAULT) revert InvalidPosition(id);
    }

    function _position(uint256 id) private view returns (uint256 collateral, uint256 debt) {
        return IFXMintManagerPosition(POOL).getPosition(id);
    }

    function _liveTarget() private view returns (uint256 target) {
        target = IFXMintManagerConfig(VERSION).targetLtvWad();
        _validateTarget(target);
    }

    function _validateTarget(uint256 target) private view {
        (uint256 minRatio, uint256 maxRatio) = IFXMintManagerPosition(POOL).getDebtRatioRange();
        if (target == 0 || target <= minRatio || target > maxRatio || target >= WAD) revert InvalidTarget(target);
    }

    function _onlyImplementation() private view {
        if (address(this) != VERSION) revert IncorrectExecutionContext();
    }

    function _onlyOwnerImplementation() private view {
        _onlyImplementation();
        if (msg.sender != OWNER) revert OnlyOwner();
    }

    function _onlyVaultDelegatecall() private view {
        if (address(this) != VAULT || address(this) == VERSION) revert IncorrectExecutionContext();
    }

    function _executeOne(address fuse, bytes memory callData) private {
        FuseAction[] memory actions = new FuseAction[](1);
        actions[0] = FuseAction({fuse: fuse, data: callData});
        if (address(this) == VAULT) {
            // IPOR's existing vault-self nested fuse path (instant withdrawals/Alpha maintenance).
            try IFXMintManagerVault(VAULT).executeInternal(actions) {} catch (bytes memory reason) {
                revert FuseExecutionFailed(reason);
            }
        } else if (address(this) == VERSION) {
            // Public delayed requests require the manager itself to have narrowly scoped ALPHA_ROLE.
            try IFXMintManagerVault(VAULT).execute(actions) {} catch (bytes memory reason) {
                revert FuseExecutionFailed(reason);
            }
        } else revert IncorrectExecutionContext();
    }
}
