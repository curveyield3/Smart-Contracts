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
    function stakedBalanceOf(address account) external view returns (uint256);
    function GAUGE() external view returns (address);
    function FXSP() external view returns (address);
}

/// @notice fxMINT LTV logic plus ONE public, globally pending, native-IPOR withdrawal request.
/// @dev Own storage holds only target/slippage/pending request. All PlasmaVault protocol operations
///      go through registered IPOR execution fuses. No Yearn/Morpho/Aave adapter or strategy allocator.
struct FxSPEnterData { address vault; uint256 vaultAssetAmount; uint256 minSharesOut; }

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
        uint256 collateralReleaseWBTC;
        uint256 debtReduction;
        uint256 target;
    }
    struct PendingRequest {
        address user;
        uint8 stage; // 0=cooldown, 1=release recovery collateral, 2=finish repay, 3=final WBTC redemption.
        uint256 shares;
        uint256 nftId;
        uint256 debtReduction;
        uint256 collateralReleaseWBTC;
        uint256 fxspShares;
        uint256 unlockAt;
    }

    address public immutable VERSION;
    uint256 public constant MARKET_ID = 49;
    address public immutable VAULT;
    address public immutable OWNER;
    address public immutable POSITION_REGISTRY;
    address private immutable POOL;
    address private immutable POOL_MANAGER;
    address private immutable WBTC;
    address private immutable FXUSD;
    address private immutable FXN;
    address private immutable FXSP;
    address private immutable FXMINT_BORROW_FUSE;
    address private immutable FXMINT_COLLATERAL_FUSE;
    address private immutable CONVEX_STAKE_FUSE;
    address private immutable FXSP_SUPPLY_FUSE;
    address private immutable CONVEX_GAUGE;
    address private immutable OMNI_SWAP_FUSE;
    address private immutable OMNI_ROUTER;
    address private immutable USDC;
    address private immutable WITHDRAW_MANAGER;

    // Stored in this deployed manager contract, not in the PlasmaVault delegatecall storage slots.
    uint256 public targetLtvWad;
    uint256 public withdrawSlippageBps;
    PendingRequest private _pendingRequest;
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
            IFXMintConvexReader(a.convexStakeFuse).GAUGE() != a.convexGauge ||
            IFXMintConvexReader(a.convexStakeFuse).FXSP() != a.fxsp ||
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

    /// @notice Preserve the original eight-field getter ABI while packing stage with user.
    function pendingRequest() external view returns (
        address user, uint256 shares, uint256 nftId, uint256 debtReduction,
        uint256 collateralReleaseWBTC, uint256 fxspShares, uint256 unlockAt, uint8 stage
    ) {
        PendingRequest storage p = _pendingRequest;
        return (p.user, p.shares, p.nftId, p.debtReduction, p.collateralReleaseWBTC, p.fxspShares, p.unlockAt, p.stage);
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
        return address(this) == VERSION && _status == 2 && _pendingRequest.user != address(0);
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
        _exitCollateral(s.id, s.collateralReleaseWBTC, prefunded);
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
        uint256 fxn = _vaultBalance(FXN);
        if (fxn != 0) _swap(FXN, WBTC, fxn);
        _rebalanceUp(minFxspSharesOut);
    }

    /// @notice Owner/Alpha may repay using already idle fxUSD; NO immediate Convex/fxSP unstake/redeem.
    function rebalanceDown() external {
        _onlyVaultDelegatecall();
        uint256 id = _positionId();
        (uint256 collateral, uint256 debt) = _position(id);
        if (collateral == 0 || debt == 0) return;
        uint256 collateralUsd = _collateralUsd(collateral, _exchangePrice());
        uint256 allowed = Math.mulDiv(collateralUsd, _liveTarget(), WAD);
        if (debt <= allowed) return;
        uint256 reduction = debt - allowed;
        _precheckIntermediateDebtRatio(collateralUsd, debt, reduction);
        _repayFromIdle(id, reduction);
        (, uint256 remainingDebt) = _position(id);
        if (remainingDebt > allowed) revert UnsafeLtv(_ltv(collateral, remainingDebt, _exchangePrice()), _liveTarget());
        emit DebtRebalanced(id, debt - remainingDebt);
    }

    /// @notice The FIRST permissionless button forwards here. Only one request globally.
    function initializeFulfillWithdrawRequest(address user) external nonReentrant {
        _onlyImplementation();
        // f(x) PoolConfiguration permits only ONE operate per transaction.
        // A matured request may require several permissionless finalize calls;
        // never overwrite its state by auto-starting another user's request.
        if (_pendingRequest.user != address(0)) revert PendingWithdrawalAlreadyActive();
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
            uint256 idleWBTC = _vaultBalance(WBTC);
            if (desiredWBTC <= idleWBTC) revert InvalidAmount();
            s = _prepareWithdrawal(desiredWBTC - idleWBTC);
            if (s.debtReduction == 0) revert InvalidAmount();
        }
        uint256 debtBudget = _repayBudget(s.debtReduction);
        uint256 idleFxUSD = _vaultBalance(FXUSD);
        if (idleFxUSD >= debtBudget) revert InvalidAmount(); // no delayed redemption required
        (uint256 shares, uint256 unlockAt) = _requestExistingFxsp(
            debtBudget - idleFxUSD, debtBudget, s.collateralReleaseWBTC == type(uint256).max);
        _pendingRequest = PendingRequest({
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
        uint256 idle = _vaultBalance(FXSP);
        uint256 staked = IFXMintConvexReader(CONVEX_STAKE_FUSE).stakedBalanceOf(VAULT);
        uint256 availableShares = idle + staked;
        // At the last investor exit all remaining Convex/fxSP principal must
        // become liquid WBTC, not merely the shares needed to repay fxMINT debt.
        // Leaving staked assets behind makes ERC4626 redeemFromRequest attempt
        // to pay their NAV without the underlying WBTC in vault custody.
        if (fullExit) shares = availableShares;
        else if (shares > availableShares) shares = availableShares;
        if (shares == 0) revert InsufficientLiquidity(requiredBudget, 0);
        if (shares > idle) {
            _executeTokenAmount(CONVEX_STAKE_FUSE, bytes4(keccak256("exit((address,uint256))")), CONVEX_GAUGE, shares - idle);
        }
        _executeTokenAmount(FXSP_SUPPLY_FUSE, bytes4(keccak256("exit((address,uint256))")), FXSP, shares);
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
        PendingRequest storage p = _pendingRequest;
        if (p.user == address(0)) revert NoPendingRequest();
        if (block.timestamp < p.unlockAt) revert PendingNotMature(p.unlockAt);
        uint8 stage = p.stage;
        if (stage == 0 || stage == 2) {
            bool full = p.collateralReleaseWBTC == type(uint256).max;
            uint256 reduction = p.debtReduction;
            uint256 budget;
            bool recovery;
            if (stage == 0) {
                _executeTokenAmount(FXSP_SUPPLY_FUSE, bytes4(keccak256("finalizeExit((address,uint256))")), FXSP, p.fxspShares);
                _swap(USDC, FXUSD, _vaultBalance(USDC));
                if (full) (, reduction) = _position(p.nftId);
                budget = _repayBudget(reduction);
                recovery = _vaultBalance(FXUSD) < budget;
            } else if (!full && reduction != 0) {
                budget = _repayBudget(reduction);
            }
            if (recovery) {
                p.debtReduction = _repayAvailableScheduledFxUSD(p.nftId, reduction);
                p.stage = 1;
            } else if (full) {
                _finishRequest(p, true);
                return;
            } else {
                _repayFromIdleBudgeted(p.nftId, reduction, budget);
                p.debtReduction = 0;
                p.stage = 3;
            }
        } else if (stage == 1) {
            _sellCollateralForRemainingDebt(p.nftId, p.debtReduction);
            p.stage = 2;
        } else if (stage == 3) {
            _finishRequest(p, false);
            return;
        } else {
            revert InvalidFulfillStage(stage);
        }
        emit WithdrawRequestAdvanced(p.user, p.stage, p.debtReduction);
    }

    /// @dev Full and partial exits converge on native-IPOR settlement; the
    ///      collateral fuse owns actual withdrawal, full-close and live LTV enforcement.
    function _finishRequest(PendingRequest storage p, bool full) private {
        (uint256 collateral, uint256 debt) = _position(p.nftId);
        if (full) {
            if (collateral == 0) revert InvalidAmount();
            uint256 budget = _repayBudget(debt);
            uint256 availableFxUSD = _vaultBalance(FXUSD);
            if (availableFxUSD < budget) revert InsufficientFxUSDForRepayment(budget, availableFxUSD);
            _executeOne(FXMINT_COLLATERAL_FUSE, abi.encodeWithSignature(
                "exitAndRepayFull(uint256,uint256,uint256)", p.nftId, budget, uint256(0)));
            _swap(FXUSD, WBTC, _vaultBalance(FXUSD));
        } else {
            uint256 available = Math.mulDiv(collateral, WAD, _collateralScaling());
            uint256 releaseWBTC = Math.min(p.collateralReleaseWBTC, available);
            if (releaseWBTC != 0) _exitCollateral(p.nftId, releaseWBTC, 0);
        }
        _releaseNativeRequestShares(p.user, p.shares);
    }

    function _releaseNativeRequestShares(address user, uint256 shares) private {
        IFXMintWithdrawManager(WITHDRAW_MANAGER).releaseFunds(block.timestamp - 1, shares);
        uint256 released = IFXMintManagerVault(VAULT).redeemFromRequest(shares, user, user);
        delete _pendingRequest;
        emit WithdrawRequestFinalized(user, shares, released);
    }

    function _rebalanceUp(uint256 minFxspSharesOut) private {
        uint256 id = _positionId();
        _supplyAllIdleWBTC(id);
        (uint256 collateral, uint256 debt) = _position(id);
        if (collateral == 0) revert InvalidPosition(id);
        uint256 allowed = Math.mulDiv(_collateralUsd(collateral, _exchangePrice()), _liveTarget(), WAD);
        if (debt >= allowed) return;
        uint256 borrow = allowed - debt;
        if (borrow > RAW_DEBT_BUFFER) borrow -= RAW_DEBT_BUFFER;
        if (borrow == 0) return;
        uint256 received = _executeReceived(FXMINT_BORROW_FUSE,
            abi.encodeWithSignature("enter(uint256,uint256,uint256)", id, borrow, uint256(0)), FXUSD);
        if (received == 0) revert InsufficientLiquidity(borrow, 0);
        uint256 mintedShares = _executeReceived(FXSP_SUPPLY_FUSE,
            abi.encodeWithSignature("enter((address,uint256,uint256))", FxSPEnterData(FXSP, received, minFxspSharesOut)), FXSP);
        _executeTokenAmount(CONVEX_STAKE_FUSE, bytes4(keccak256("enter((address,uint256))")), CONVEX_GAUGE, mintedShares);
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
        uint256 originalCollateralUsd = _collateralUsd(s.initialCollateral, s.exchangePrice);
        uint256 initialLtv = _ltvFromUsd(originalCollateralUsd, s.initialDebt);
        (, uint256 withdrawFee, , ) = _feeRatios();
        if (withdrawFee >= FEE_PRECISION) revert InvalidConfiguration();
        s.collateralReleaseWBTC = Math.mulDiv(
            netWBTCNeeded, FEE_PRECISION, FEE_PRECISION - withdrawFee, Math.Rounding.Up
        );
        uint256 scaling = _collateralScaling();
        uint256 requestedRaw = Math.mulDiv(s.collateralReleaseWBTC, scaling, WAD);
        if (requestedRaw > s.initialCollateral) revert InsufficientCollateral(requestedRaw, s.initialCollateral);
        if (requestedRaw == 0) revert InvalidAmount();
        uint256 riskRelease = requestedRaw + (scaling / WAD) + 1;
        if (riskRelease > s.initialCollateral) riskRelease = s.initialCollateral;
        uint256 postCollateralUsd = _collateralUsd(s.initialCollateral - riskRelease, s.exchangePrice);
        if (originalCollateralUsd == 0) revert InvalidPrice();
        uint256 desiredFinalLtv;
        if (initialLtv > s.target + WITHDRAW_LTV_IMPROVEMENT_WAD) {
            uint256 onePointLower = initialLtv - WITHDRAW_LTV_IMPROVEMENT_WAD;
            if (onePointLower > s.target + WITHDRAW_ROUNDING_HEADROOM_WAD) {
                desiredFinalLtv = onePointLower - WITHDRAW_ROUNDING_HEADROOM_WAD;
            } else desiredFinalLtv = s.target;
        } else if (initialLtv > s.target) desiredFinalLtv = initialLtv;
        else desiredFinalLtv = s.target;
        if (s.initialDebt != 0) {
            uint256 allowedDebt = Math.mulDiv(postCollateralUsd, desiredFinalLtv, WAD);
            if (s.initialDebt > allowedDebt) {
                s.debtReduction = s.initialDebt - allowedDebt;
                uint256 debtLeft = s.initialDebt - s.debtReduction;
                if (debtLeft > RAW_DEBT_BUFFER) s.debtReduction += RAW_DEBT_BUFFER;
            }
        }
    }

    function _repayFeeBps(uint256 liveRepayFee) private pure returns (uint256 feeBps) {
        feeBps = Math.mulDiv(liveRepayFee, BPS, FEE_PRECISION, Math.Rounding.Up);
        if (feeBps < MIN_REPAY_RESERVE_BPS) feeBps = MIN_REPAY_RESERVE_BPS;
    }

    function _repayCostBps() private view returns (uint256) {
        (, , , uint256 fee) = _feeRatios();
        if (fee >= FEE_PRECISION) revert InvalidConfiguration();
        uint256 reserve = IFXMintManagerConfig(VERSION).withdrawSlippageBps();
        if (reserve < MIN_SLIPPAGE_BPS || reserve > MAX_SLIPPAGE_BPS) revert InvalidSlippage(reserve);
        return _repayFeeBps(fee) + reserve;
    }

    function _repayBudget(uint256 debtReduction) private view returns (uint256) {
        return debtReduction + Math.mulDiv(debtReduction, _repayCostBps(), BPS, Math.Rounding.Up)
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
        uint256 stableAvailable = _vaultBalance(FXUSD);
        uint256 repayable = Math.mulDiv(stableAvailable, BPS, BPS + _repayCostBps() + 100);
        if (repayable > requestedReduction) repayable = requestedReduction;
        (uint256 minDebtRatio,) = IFXMintManagerPosition(POOL).getDebtRatioRange();
        uint256 minResidual = Math.mulDiv(
            _collateralUsd(rawCollateral, price), minDebtRatio, WAD, Math.Rounding.Up
        ) + RAW_DEBT_BUFFER;
        if (repayable != 0 && initialDebt - repayable < minResidual) {
            repayable = initialDebt > minResidual ? initialDebt - minResidual : 0;
        }
        if (repayable != 0) {
            _executeRepayment(id, repayable, false, stableAvailable);
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
        uint256 idleStable = _vaultBalance(FXUSD);
        if (fullBudget > idleStable) {
            uint256 price = _exchangePrice();
            uint256 sell = Math.mulDiv(fullBudget - idleStable, 1e8, price, Math.Rounding.Up);
            sell = Math.mulDiv(sell, BPS + COLLATERAL_RECOVERY_SWAP_BUFFER_BPS,
                BPS, Math.Rounding.Up);
            if (sell == 0) revert InvalidAmount();
            // CollateralFuse.exit and fxMINT PoolManager enforce both
            // withdrawable collateral and live target LTV after the change.
            // No duplicate preflight calculations in the public manager.
            uint256 receivedWBTC = _executeReceived(FXMINT_COLLATERAL_FUSE,
                abi.encodeWithSignature("exit(uint256,uint256,uint256)", id, sell, uint256(0)), WBTC);
            if (receivedWBTC == 0) revert InsufficientLiquidity(sell, 0);
            _swap(WBTC, FXUSD, receivedWBTC);
        }
    }

    function _exitCollateral(uint256 id, uint256 amount, uint256 minOut) private {
        _executeOne(FXMINT_COLLATERAL_FUSE,
            abi.encodeWithSignature("exit(uint256,uint256,uint256)", id, amount, minOut));
    }

    function _executeRepayment(uint256 id, uint256 amount, bool full, uint256 budget) private {
        _executeOne(FXMINT_BORROW_FUSE,
            abi.encodeWithSignature("exit(uint256,uint256,bool,uint256)", id, amount, full, budget));
    }

    function _repayFromIdle(uint256 id, uint256 debtReduction) private {
        if (debtReduction == 0) return;
        _repayFromIdleBudgeted(id, debtReduction, _repayBudget(debtReduction));
    }

    function _repayFromIdleBudgeted(uint256 id, uint256 debtReduction, uint256 budget) private {
        if (debtReduction == 0) return;
        uint256 available = _vaultBalance(FXUSD);
        if (available < budget) revert InsufficientFxUSDForRepayment(budget, available);
        (, uint256 beforeDebt) = _position(id);
        bool full = debtReduction >= beforeDebt;
        _executeRepayment(id, debtReduction, full, budget);
        (, uint256 afterDebt) = _position(id);
        if (afterDebt > beforeDebt || beforeDebt - afterDebt < debtReduction) revert UnexpectedPositionChange();
    }

    /// @dev Existing IPOR UniversalTokenSwapperFuse, using its existing executor and guards.
    ///      The executor must approve the routed token before OmniRouter.easyswap pulls it.
    function _swap(address tokenIn, address tokenOut, uint256 amount) private {
        if (amount == 0) return;
        // Canonical ABI of enter((address,address,uint256,uint256,(address[],bytes[]))):
        // one dynamic tuple, two target addresses, two fixed-length inner calls.
        // Exact same approval and guarded OmniRouter swap as the prior encoder.
        bytes memory data = new bytes(740);
        bytes4 enterSelector = bytes4(keccak256("enter((address,address,uint256,uint256,(address[],bytes[])))"));
        bytes4 approveSelector = IERC20.approve.selector;
        bytes4 swapSelector = bytes4(keccak256("swap(address,address,uint256)"));
        address router = OMNI_ROUTER;
        assembly ("memory-safe") {
            let p := add(data, 32)
            let mask := 0xffffffffffffffffffffffffffffffffffffffff
            tokenIn := and(tokenIn, mask)
            tokenOut := and(tokenOut, mask)
            router := and(router, mask)
            mstore(p, enterSelector)
            mstore(add(p, 4), 32)
            mstore(add(p, 36), tokenIn)
            mstore(add(p, 68), tokenOut)
            mstore(add(p, 100), amount)
            mstore(add(p, 132), 0)
            mstore(add(p, 164), 160)
            mstore(add(p, 196), 64)
            mstore(add(p, 228), 160)
            mstore(add(p, 260), 2)
            mstore(add(p, 292), tokenIn)
            mstore(add(p, 324), router)
            mstore(add(p, 356), 2)
            mstore(add(p, 388), 64)
            mstore(add(p, 420), 192)
            mstore(add(p, 452), 68)
            mstore(add(p, 484), approveSelector)
            mstore(add(p, 488), router)
            mstore(add(p, 520), amount)
            // ABI padding in the zero-initialized bytes allocation.
            mstore(add(p, 580), 100)
            mstore(add(p, 612), swapSelector)
            mstore(add(p, 616), tokenIn)
            mstore(add(p, 648), tokenOut)
            mstore(add(p, 680), amount)
        }
        _executeOne(OMNI_SWAP_FUSE, data);
    }

    function _supplyAllIdleWBTC(uint256 id) private {
        uint256 idle = _vaultBalance(WBTC);
        if (idle != 0) _executeOne(FXMINT_COLLATERAL_FUSE,
            abi.encodeWithSignature("enter(uint256,uint256)", id, idle));
    }

    function _precheckIntermediateDebtRatio(uint256 collateralUsd, uint256 debt, uint256 reduction) private view {
        (uint256 minRatio,) = IFXMintManagerPosition(POOL).getDebtRatioRange();
        uint256 projectedDebt = reduction >= debt ? 0 : debt - reduction;
        uint256 intermediate = Math.mulDiv(projectedDebt, WAD, collateralUsd);
        if (intermediate < minRatio) revert ProtocolDebtRatioNotReachable(intermediate, minRatio);
    }

    function _collateralScaling() private view returns (uint256 scale) {
        scale = IFXMintManagerPoolManager(POOL_MANAGER).getTokenScalingFactor(WBTC);
        if (scale == 0) revert InvalidConfiguration();
    }

    function _remainingRawCollateral(uint256 amountWBTC, uint256 totalRaw) private view returns (uint256) {
        uint256 scale = _collateralScaling();
        uint256 requested = Math.mulDiv(amountWBTC, scale, WAD, Math.Rounding.Up);
        return requested >= totalRaw ? 0 : totalRaw - requested;
    }

    function _ltvAfter(uint256 rawCollateral, uint256 debt, uint256 price, uint256 amountWBTC, uint256 debtReduction)
        private view returns (uint256)
    {
        return _ltv(_remainingRawCollateral(amountWBTC, rawCollateral),
            debtReduction >= debt ? 0 : debt - debtReduction, price);
    }

    function _collateralUsd(uint256 rawCollateral, uint256 price) private pure returns (uint256) {
        return Math.mulDiv(rawCollateral, price, WAD);
    }

    function _ltvFromUsd(uint256 usd, uint256 debt) private pure returns (uint256) {
        if (debt == 0) return 0;
        return usd == 0 ? type(uint256).max : Math.mulDiv(debt, WAD, usd, Math.Rounding.Up);
    }

    function _ltv(uint256 rawCollateral, uint256 debt, uint256 price) private pure returns (uint256) {
        if (debt == 0) return 0;
        return _ltvFromUsd(_collateralUsd(rawCollateral, price), debt);
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

    function _executeTokenAmount(address fuse, bytes4 selector, address token, uint256 amount) private {
        _executeOne(fuse, abi.encodeWithSelector(selector, token, amount));
    }

    function _vaultBalance(address token) private view returns (uint256) {
        return IERC20(token).balanceOf(VAULT);
    }

    function _executeReceived(address fuse, bytes memory callData, address token) private returns (uint256) {
        uint256 beforeBalance = _vaultBalance(token);
        _executeOne(fuse, callData);
        return _vaultBalance(token) - beforeBalance;
    }

    function _executeOne(address fuse, bytes memory callData) private {
        bytes4 selector;
        if (address(this) == VAULT) selector = IFXMintManagerVault.executeInternal.selector;
        else if (address(this) == VERSION) selector = IFXMintManagerVault.execute.selector;
        else revert IncorrectExecutionContext();
        if (VAULT.code.length == 0) revert InvalidConfiguration();
        uint256 length = callData.length;
        bytes memory payload = new bytes(196 + ((length + 31) & ~uint256(31)));
        // execute(FuseAction[]): offset, array length, element offset,
        // fuse address, bytes offset, length, then zero-padded calldata.
        assembly ("memory-safe") {
            let p := add(payload, 32)
            mstore(p, selector)
            mstore(add(p, 4), 32)
            mstore(add(p, 36), 1)
            mstore(add(p, 68), 32)
            mstore(add(p, 100), and(fuse, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(p, 132), 64)
            mstore(add(p, 164), length)
            mcopy(add(p, 196), add(callData, 32), length)
        }
        (bool ok, bytes memory reason) = VAULT.call(payload);
        if (!ok) revert FuseExecutionFailed(reason);
    }
}
