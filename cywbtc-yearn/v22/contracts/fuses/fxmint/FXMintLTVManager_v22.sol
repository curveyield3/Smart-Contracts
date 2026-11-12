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
}
interface IFXMintManagerVault {
    function executeInternal(FuseAction[] calldata actions) external;
}
interface IFXMintYearnMaster {
    function YEARN_VAULT() external view returns (address);
}

// Exactly the official Erc4626SupplyFuse enter/exit tuple layouts.
struct Erc4626SupplyFuseEnterData {
    address vault;
    uint256 vaultAssetAmount;
    uint256 minSharesOut;
}
struct Erc4626SupplyFuseExitData {
    address vault;
    uint256 vaultAssetAmount;
    uint256 maxSharesBurned;
}

/// @title FXMintLTVManager
/// @notice Dedicated fxMINT market (49) LTV enforcement for fxMINT collateral/debt + official IPOR
///         generic ERC4626 Yearn market (100001). All protocol mutations are
///         executed only via registered IPOR fuses, in PlasmaVault context.
/// @dev Yearn owns the two Convex child positions and harvests its own rewards;
///      this manager must never attempt to manage those old positions directly.
contract FXMintLTVManager is IFuseCommon, IFuseInstantWithdraw {
    uint256 private constant WAD = 1e18;
    uint256 private constant FEE_PRECISION = 1e9;
    uint256 private constant BPS = 10_000;
    uint256 private constant MIN_SLIPPAGE_BPS = 5;
    uint256 private constant MAX_SLIPPAGE_BPS = 55;
    uint256 private constant RAW_DEBT_BUFFER = 1e12;
    uint256 private constant REFILL_TRIGGER_GAP = 5e16; // 5 percentage points
    uint256 private constant REFILL_FINISH_GAP = 3e16;  // 3 percentage points
    uint256 private constant MIN_REPAY_RESERVE_BPS = 30;
    uint256 private constant WITHDRAW_LTV_IMPROVEMENT_WAD = 1e16;
    uint256 private constant WITHDRAW_ROUNDING_HEADROOM_WAD = 1e14;
    uint256 private constant YEARN_MARKET_ID = 100_001;

    struct Addresses {
        address vault;
        address owner;
        address positionRegistry;
        address fxMintPool;
        address poolManager;
        address wbtc;
        address fxusd;
        address fxMintBorrowFuse;
        address fxMintCollateralFuse;
        address erc4626SupplyFuse;
        address yearnVault;
        address yearnMaster;
    }

    struct WithdrawState {
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

    address public immutable VERSION;
    uint256 public immutable MARKET_ID;
    address public immutable VAULT;
    address public immutable OWNER;
    address public immutable POSITION_REGISTRY;
    address public immutable POOL;
    address public immutable POOL_MANAGER;
    address public immutable WBTC;
    address public immutable FXUSD;
    address public immutable FXMINT_BORROW_FUSE;
    address public immutable FXMINT_COLLATERAL_FUSE;
    address public immutable ERC4626_SUPPLY_FUSE;
    address public immutable YEARN_VAULT;
    address public immutable YEARN_MASTER;

    // Owner-controlled implementation storage, never PlasmaVault delegatecall slots.
    uint256 public targetLtvWad;
    uint256 public withdrawSlippageBps;

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
    error FuseExecutionFailed(bytes revertData);
    error UnexpectedVaultBalance(uint256 needed, uint256 actual);
    error UnexpectedPositionChange();

    event TargetLtvSet(uint256 oldTarget, uint256 newTarget);
    event WithdrawSlippageSet(uint256 oldBps, uint256 newBps);
    event CollateralWithdrawal(uint256 indexed id, uint256 grossWBTC, uint256 netWBTC, uint256 debtReduction);
    event DebtRebalanced(uint256 indexed id, uint256 debtReduction);
    event TargetWindUp(uint256 indexed id, uint256 nominalBorrow, uint256 fxUSDDeposited);
    event IdleWBTCAllocated(uint256 indexed id, uint256 depositedWBTC);
    event AutoRefillSkipped(uint256 indexed id, uint256 liveLtv, uint256 triggerLtv);

    constructor(Addresses memory a, uint256 initialTargetLtvWad) {
        if (
            a.vault == address(0) || a.owner == address(0) || a.positionRegistry == address(0) ||
            a.fxMintPool == address(0) || a.poolManager == address(0) || a.wbtc == address(0) ||
            a.fxusd == address(0) || a.fxMintBorrowFuse == address(0) ||
            a.fxMintCollateralFuse == address(0) || a.erc4626SupplyFuse == address(0) ||
            a.yearnVault == address(0) || a.yearnMaster == address(0)
        ) revert InvalidConfiguration();
        IFXMintManagerPosition pool = IFXMintManagerPosition(a.fxMintPool);
        if (pool.poolManager() != a.poolManager || pool.fxUSD() != a.fxusd ||
            pool.collateralToken() != a.wbtc || IERC4626(a.yearnVault).asset() != a.fxusd ||
            IFXMintYearnMaster(a.yearnMaster).YEARN_VAULT() != a.yearnVault ||
            IFuseCommon(a.fxMintBorrowFuse).MARKET_ID() != 49 ||
            IFuseCommon(a.fxMintCollateralFuse).MARKET_ID() != 49 ||
            IFuseCommon(a.erc4626SupplyFuse).MARKET_ID() != YEARN_MARKET_ID
        ) revert InvalidConfiguration();
        VERSION = address(this);
        MARKET_ID = 49;
        VAULT = a.vault;
        OWNER = a.owner;
        POSITION_REGISTRY = a.positionRegistry;
        POOL = a.fxMintPool;
        POOL_MANAGER = a.poolManager;
        WBTC = a.wbtc;
        FXUSD = a.fxusd;
        FXMINT_BORROW_FUSE = a.fxMintBorrowFuse;
        FXMINT_COLLATERAL_FUSE = a.fxMintCollateralFuse;
        ERC4626_SUPPLY_FUSE = a.erc4626SupplyFuse;
        YEARN_VAULT = a.yearnVault;
        YEARN_MASTER = a.yearnMaster;
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

    /// @notice The 5..55 bps reserve above the fxMINT repay-fee reserve now
    ///         covers Yearn exits instead of the retired Curve LP min-out path.
    function setWithdrawSlippageBps(uint256 bps) external {
        _onlyOwnerImplementation();
        if (bps < MIN_SLIPPAGE_BPS || bps > MAX_SLIPPAGE_BPS) revert InvalidSlippage(bps);
        emit WithdrawSlippageSet(withdrawSlippageBps, bps);
        withdrawSlippageBps = bps;
    }

    /// @inheritdoc IFuseInstantWithdraw
    /// @dev params[0] is the WBTC shortfall after vault-held WBTC, NOT the
    ///      full user request. Keep repay-first, collateral-second behavior.
    function instantWithdraw(bytes32[] calldata params) external override {
        _onlyVaultDelegatecall();
        if (params.length != 1) revert InvalidAmount();
        uint256 netRequired = uint256(params[0]);
        if (netRequired == 0) return;
        WithdrawState memory s = _prepareWithdrawal(netRequired);
        if (s.debtReduction != 0) _repayFromYearn(s.id, s.debtReduction);
        (uint256 remainingCollateral, uint256 liveDebt) = _position(s.id);
        uint256 remainingValue = Math.mulDiv(remainingCollateral, _exchangePrice(), WAD);
        uint256 maxDebtAfter = Math.mulDiv(remainingValue, s.desiredFinalLtv, WAD);
        if (liveDebt > maxDebtAfter) {
            uint256 topUp = liveDebt - maxDebtAfter;
            _repayFromYearn(s.id, topUp);
        }
        uint256 beforeWBTC = IERC20(WBTC).balanceOf(address(this));
        _executeOne(FXMINT_COLLATERAL_FUSE,
            abi.encodeWithSignature("exit(uint256,uint256,uint256)", s.id, s.collateralReleaseWBTC, s.netWBTCNeeded));
        uint256 received = IERC20(WBTC).balanceOf(address(this)) - beforeWBTC;
        if (received < s.netWBTCNeeded) revert UnexpectedVaultBalance(s.netWBTCNeeded, received);
        (, uint256 finalDebt) = _position(s.id);
        emit CollateralWithdrawal(s.id, s.collateralReleaseWBTC, received,
            finalDebt < s.initialDebt ? s.initialDebt - finalDebt : 0);
    }

    /// @notice Authorized Alpha debt reduction, not part of user instant exit.
    function rebalanceDown() external {
        _onlyVaultDelegatecall();
        uint256 id = _positionId();
        _supplyAllIdleWBTC(id);
        (uint256 collateral, uint256 debt) = _position(id);
        if (collateral == 0 || debt == 0) return;
        uint256 collateralUsd = Math.mulDiv(collateral, _exchangePrice(), WAD);
        uint256 target = _liveTarget();
        uint256 permittedDebt = Math.mulDiv(collateralUsd, target, WAD);
        if (debt <= permittedDebt) return;
        uint256 requiredReduction = debt - permittedDebt;
        _precheckIntermediateDebtRatio(collateralUsd, debt, requiredReduction);
        _repayFromYearn(id, requiredReduction);
        (uint256 finalCollateral, uint256 finalDebt) = _position(id);
        if (finalCollateral != collateral || finalDebt > debt) revert UnexpectedPositionChange();
        uint256 actual = _ltv(finalCollateral, finalDebt, _exchangePrice());
        if (actual > target) revert UnsafeLtv(actual, target);
        emit DebtRebalanced(id, debt - finalDebt);
    }

    /// @notice Atomic deposit management entry. Called through PlasmaVault.execute
    ///         by a narrowly restricted WBTC deposit router granted ALPHA_ROLE.
    /// @param minStrategyOut Minimum Yearn ERC4626 shares minted when investing fxUSD.
    /// @dev ALWAYS collateralizes WBTC. ONLY refills debt if actual LTV is
    ///      at least 5 percentage points below target; stops ~3pp below target.
    function allocateAfterDeposit(uint256 minStrategyOut) external {
        _onlyVaultDelegatecall();
        _allocateAndMaybeRefill(minStrategyOut);
    }

    /// @notice Also exposed for Alpha-managed maintenance/donation allocation.
    function rebalanceUp(uint256 minStrategyOut) external {
        _onlyVaultDelegatecall();
        _allocateAndMaybeRefill(minStrategyOut);
    }

    function _allocateAndMaybeRefill(uint256 minStrategyOut) private {
        uint256 idleWBTC = IERC20(WBTC).balanceOf(address(this));
        uint256 id = IFXMintManagerPositionRegistry(POSITION_REGISTRY).positionId();
        if (id == 0) {
            if (idleWBTC == 0) revert InvalidAmount();
            // Mint and register in ONE internal batch; the NAV refresh happens
            // only after the position is visible to the direct balance fuse.
            FuseAction[] memory actions = new FuseAction[](2);
            actions[0] = FuseAction(FXMINT_COLLATERAL_FUSE,
                abi.encodeWithSignature("enterNewPosition(uint256)", idleWBTC));
            actions[1] = FuseAction(POSITION_REGISTRY,
                abi.encodeWithSignature("enterRegisterLatestPosition()"));
            _executeBatch(actions);
            id = _positionId();
            emit IdleWBTCAllocated(id, idleWBTC);
        } else {
            if (IFXMintManagerPosition(POOL).ownerOf(id) != VAULT) revert InvalidPosition(id);
            if (idleWBTC != 0) {
                // Supply the collateral first. If fxMINT enforces a minimum
                // debt ratio, increase debt in the SAME protocol operate call.
                // A collateral-only call at a too-low ratio would revert.
                (uint256 collateral, uint256 debt) = _position(id);
                uint256 scale = IFXMintManagerPoolManager(POOL_MANAGER).getTokenScalingFactor(WBTC);
                if (scale == 0) revert InvalidConfiguration();
                uint256 rawDelta = Math.mulDiv(idleWBTC, scale, WAD);
                uint256 newCollateralUsd = Math.mulDiv(collateral + rawDelta, _exchangePrice(), WAD);
                (uint256 minRatio, ) = IFXMintManagerPosition(POOL).getDebtRatioRange();
                uint256 minDebt = Math.mulDiv(newCollateralUsd, minRatio, WAD, Math.Rounding.Ceil);
                uint256 minDebtWithRounding = minDebt + RAW_DEBT_BUFFER;
                uint256 debtTopUp = minDebtWithRounding > debt ? minDebtWithRounding - debt : 0;
                if (debtTopUp != 0) {
                    _executeOne(FXMINT_COLLATERAL_FUSE, abi.encodeWithSignature(
                        "enterWithBorrow(uint256,uint256,uint256,uint256)", id, idleWBTC, debtTopUp, uint256(0)
                    ));
                } else {
                    _executeOne(FXMINT_COLLATERAL_FUSE,
                        abi.encodeWithSignature("enter(uint256,uint256)", id, idleWBTC));
                }
                emit IdleWBTCAllocated(id, idleWBTC);
            }
        }
        (uint256 collateralAfter, uint256 debtAfter) = _position(id);
        if (collateralAfter == 0) revert InvalidPosition(id);
        uint256 target = _liveTarget();
        uint256 exchange = _exchangePrice();
        uint256 currentLtv = _ltv(collateralAfter, debtAfter, exchange);
        uint256 trigger = target - REFILL_TRIGGER_GAP;
        if (currentLtv <= trigger) {
            uint256 desiredDebt = Math.mulDiv(
                Math.mulDiv(collateralAfter, exchange, WAD), target - REFILL_FINISH_GAP, WAD
            );
            if (desiredDebt > debtAfter) {
                uint256 headroom = desiredDebt - debtAfter;
                // The protocol may add a borrowing fee to outstanding debt;
                // budget pessimistically and leave rounding headroom.
                (, , uint256 borrowFee, ) = _feeRatios();
                if (borrowFee >= FEE_PRECISION) revert InvalidConfiguration();
                uint256 borrow = Math.mulDiv(headroom, FEE_PRECISION, FEE_PRECISION + borrowFee);
                if (borrow > RAW_DEBT_BUFFER) borrow -= RAW_DEBT_BUFFER;
                else borrow = 0;
                if (borrow != 0) {
                    _executeOne(FXMINT_BORROW_FUSE, abi.encodeWithSignature(
                        "enter(uint256,uint256,uint256)", id, borrow, uint256(0)));
                    (,uint256 liveDebt) = _position(id);
                    if (_ltv(collateralAfter, liveDebt, _exchangePrice()) > target)
                        revert UnsafeLtv(_ltv(collateralAfter, liveDebt, _exchangePrice()), target);
                    emit TargetWindUp(id, liveDebt - debtAfter, IERC20(FXUSD).balanceOf(address(this)));
                }
            }
        } else {
            emit AutoRefillSkipped(id,currentLtv,trigger);
        }
        // Always deploy minted fxUSD, including the minimum initial borrow or
        // an fxMINT-mandated minimum debt top-up, even if no refill fires.
        uint256 idleFxUSD = IERC20(FXUSD).balanceOf(address(this));
        if (idleFxUSD != 0) _executeOne(ERC4626_SUPPLY_FUSE, abi.encodeWithSignature(
            "enter((address,uint256,uint256))",
            Erc4626SupplyFuseEnterData(YEARN_VAULT, idleFxUSD, minStrategyOut)));
    }

    function previewWithdrawal(uint256 netWBTCNeeded)
        external view returns (uint256 grossWBTCToRelease, uint256 debtToReduce, uint256 projectedLtv)
    {
        WithdrawState memory s = _prepareWithdrawal(netWBTCNeeded);
        return (s.collateralReleaseWBTC, s.debtReduction,
            _ltvAfter(s.initialCollateral, s.initialDebt, s.exchangePrice, s.collateralReleaseWBTC, s.debtReduction));
    }

    function _prepareWithdrawal(uint256 netWBTCNeeded) private view returns (WithdrawState memory s) {
        if (netWBTCNeeded == 0) revert InvalidAmount();
        s.id = _positionId();
        (s.initialCollateral, s.initialDebt) = _position(s.id);
        if (s.initialCollateral == 0) revert InsufficientCollateral(netWBTCNeeded, 0);
        s.exchangePrice = _exchangePrice();
        s.target = _liveTarget();
        s.initialLtv = _ltv(s.initialCollateral, s.initialDebt, s.exchangePrice);
        (, uint256 withdrawFee, , ) = _feeRatios();
        if (withdrawFee >= FEE_PRECISION) revert InvalidConfiguration();
        // Debt repayment fees are funded as extra fxUSD, NEVER counted toward
        // actual debt reduction. fxMINT currently reports a zero collateral
        // withdrawal fee, but this calculation respects any live fee change.
        s.collateralReleaseWBTC = Math.mulDiv(
            netWBTCNeeded, FEE_PRECISION, FEE_PRECISION - withdrawFee, Math.Rounding.Ceil
        );
        s.netWBTCNeeded = netWBTCNeeded;

        uint256 scaling = IFXMintManagerPoolManager(POOL_MANAGER).getTokenScalingFactor(WBTC);
        if (scaling == 0) revert InvalidConfiguration();
        uint256 requestedRaw = Math.mulDiv(s.collateralReleaseWBTC, scaling, WAD);
        if (requestedRaw > s.initialCollateral) {
            revert InsufficientCollateral(requestedRaw, s.initialCollateral);
        }
        if (requestedRaw == 0) revert InvalidAmount();
        // Add one native WBTC unit to the risk-estimate of collateral burned
        // for share-conversion rounding in the fxMINT position.
        uint256 riskRelease = requestedRaw + (scaling / WAD) + 1;
        if (riskRelease > s.initialCollateral) riskRelease = s.initialCollateral;

        uint256 originalCollateralUsd = Math.mulDiv(s.initialCollateral, s.exchangePrice, WAD);
        uint256 postCollateralUsd = Math.mulDiv(s.initialCollateral - riskRelease, s.exchangePrice, WAD);
        if (originalCollateralUsd == 0) revert InvalidPrice();

        // Permissionless withdrawal policy:
        //   > target+1pp : post-withdraw LTV at least 1pp below its initial LTV
        //                   (+0.01pp buffer for integer rounding), not at target.
        //   target..target+1pp : do not worsen the current LTV.
        //   < target      : may drift up to the owner's target, but never beyond.
        // An idle-WBTC payout never invokes this manager, so creates no
        // artificial deleveraging requirement.
        if (s.initialLtv > s.target + WITHDRAW_LTV_IMPROVEMENT_WAD) {
            uint256 onePointLower = s.initialLtv - WITHDRAW_LTV_IMPROVEMENT_WAD;
            if (onePointLower > s.target + WITHDRAW_ROUNDING_HEADROOM_WAD) {
                s.desiredFinalLtv = onePointLower - WITHDRAW_ROUNDING_HEADROOM_WAD;
            } else {
                s.desiredFinalLtv = s.target;
            }
        } else if (s.initialLtv > s.target) {
            s.desiredFinalLtv = s.initialLtv;
        } else {
            s.desiredFinalLtv = s.target;
        }

        if (s.initialDebt != 0) {
            uint256 allowedDebt = Math.mulDiv(postCollateralUsd, s.desiredFinalLtv, WAD);
            if (s.initialDebt > allowedDebt) {
                s.debtReduction = s.initialDebt - allowedDebt;
                // A micro-fxUSD nominal headroom prevents an extra operation
                // solely to correct debt-share conversion rounding. Repayment
                // remains based on the post-withdrawal collateral, never the
                // owner's full maintenance target.
                uint256 debtStillOwed = s.initialDebt - s.debtReduction;
                if (debtStillOwed > RAW_DEBT_BUFFER) {
                    s.debtReduction += RAW_DEBT_BUFFER;
                }
            }
        }
        // No protocol-specific combined-operate shortcut. Repayment and WBTC
        // release are two individually approved fuse calls; the protocol's
        // own min/max LTV rules still apply to each operate() transaction.
    }


    function _repayFromYearn(uint256 id, uint256 debtReduction) private {
        if (debtReduction == 0) return;
        uint256 budget = _fundRepayment(debtReduction);
        (, uint256 beforeDebt) = _position(id);
        bool full = debtReduction >= beforeDebt;
        _executeOne(FXMINT_BORROW_FUSE,
            abi.encodeWithSignature("exit(uint256,uint256,bool,uint256)", id, debtReduction, full, budget));
        (, uint256 afterDebt) = _position(id);
        if (afterDebt > beforeDebt || beforeDebt - afterDebt < debtReduction) revert UnexpectedPositionChange();
    }

    function _fundRepayment(uint256 debtReduction) private returns (uint256 budget) {
        (, , , uint256 liveRepayFee) = _feeRatios();
        if (liveRepayFee >= FEE_PRECISION) revert InvalidConfiguration();
        uint256 reserveBps = IFXMintManagerConfig(VERSION).withdrawSlippageBps();
        if (reserveBps < MIN_SLIPPAGE_BPS || reserveBps > MAX_SLIPPAGE_BPS)
            revert InvalidSlippage(reserveBps);
        uint256 feeBps = Math.mulDiv(liveRepayFee, BPS, FEE_PRECISION, Math.Rounding.Ceil);
        if (feeBps < MIN_REPAY_RESERVE_BPS) feeBps = MIN_REPAY_RESERVE_BPS;
        budget = debtReduction + Math.mulDiv(debtReduction, feeBps + reserveBps, BPS, Math.Rounding.Ceil)
            + RAW_DEBT_BUFFER;
        uint256 idle = IERC20(FXUSD).balanceOf(address(this));
        if (idle < budget) _sourceFxUSDFromYearn(budget - idle);
        uint256 available = IERC20(FXUSD).balanceOf(address(this));
        if (available < budget) revert InsufficientFxUSDForRepayment(budget, available);
    }

    /// @dev Source fxUSD before debt repayment. The Yearn supply fuse enforces
    ///      the 25-bps Yearn max_loss argument on its redemption calls.
    function _sourceFxUSDFromYearn(uint256 shortfall) private {
        if (shortfall == 0) return;
        uint256 beforeFxUSD = IERC20(FXUSD).balanceOf(address(this));
        _executeOne(ERC4626_SUPPLY_FUSE, abi.encodeWithSignature(
            "exit((address,uint256,uint256))",
            Erc4626SupplyFuseExitData(YEARN_VAULT, shortfall, 0)));
        uint256 recovered = IERC20(FXUSD).balanceOf(address(this)) - beforeFxUSD;
        if (recovered < shortfall) revert InsufficientLiquidity(shortfall, recovered);
    }

    function _supplyAllIdleWBTC(uint256 id) private {
        uint256 idle = IERC20(WBTC).balanceOf(address(this));
        if (idle != 0) _executeOne(FXMINT_COLLATERAL_FUSE,
            abi.encodeWithSignature("enter(uint256,uint256)", id, idle));
    }

    function _precheckIntermediateDebtRatio(uint256 collateralUsd, uint256 debt, uint256 reduction) private view {
        (uint256 minRatio, ) = IFXMintManagerPosition(POOL).getDebtRatioRange();
        uint256 projectedDebt = reduction >= debt ? 0 : debt - reduction;
        uint256 intermediate = Math.mulDiv(projectedDebt, WAD, collateralUsd);
        if (intermediate < minRatio) revert ProtocolDebtRatioNotReachable(intermediate, minRatio);
    }

    function _remainingRawCollateral(uint256 amountWBTC, uint256 totalRaw) private view returns (uint256) {
        uint256 scale = IFXMintManagerPoolManager(POOL_MANAGER).getTokenScalingFactor(WBTC);
        if (scale == 0) revert InvalidConfiguration();
        uint256 requestedRaw = Math.mulDiv(amountWBTC, scale, WAD, Math.Rounding.Ceil);
        if (requestedRaw >= totalRaw) return 0;
        return totalRaw - requestedRaw;
    }

    function _ltvAfter(uint256 rawCollateral, uint256 debt, uint256 price, uint256 amountWBTC, uint256 debtReduction)
        private view returns (uint256)
    {
        uint256 remaining = _remainingRawCollateral(amountWBTC, rawCollateral);
        uint256 remainingDebt = debtReduction >= debt ? 0 : debt - debtReduction;
        return _ltv(remaining, remainingDebt, price);
    }

    function _ltv(uint256 rawCollateral, uint256 debt, uint256 price) private pure returns (uint256) {
        if (debt == 0) return 0;
        if (rawCollateral == 0) return type(uint256).max;
        uint256 collateralUsd = Math.mulDiv(rawCollateral, price, WAD);
        if (collateralUsd == 0) return type(uint256).max;
        return Math.mulDiv(debt, WAD, collateralUsd, Math.Rounding.Ceil);
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
        if (target <= REFILL_TRIGGER_GAP || target - REFILL_FINISH_GAP <= minRatio ||
            target > maxRatio || target >= WAD) {
            revert InvalidTarget(target);
        }
    }

    function _onlyOwnerImplementation() private view {
        if (address(this) != VERSION) revert IncorrectExecutionContext();
        if (msg.sender != OWNER) revert OnlyOwner();
    }

    function _onlyVaultDelegatecall() private view {
        if (address(this) != VAULT || address(this) == VERSION) revert IncorrectExecutionContext();
    }

    function _executeOne(address fuse, bytes memory callData) private {
        FuseAction[] memory actions = new FuseAction[](1);
        actions[0] = FuseAction({fuse: fuse, data: callData});
        _executeBatch(actions);
    }

    function _executeBatch(FuseAction[] memory actions) private {
        // The LTV manager NEVER calls protocol-mutating methods directly.
        // Only IPOR-registered fuses execute in the vault's delegatecall context.
        try IFXMintManagerVault(address(this)).executeInternal(actions) {
        } catch (bytes memory reason) {
            revert FuseExecutionFailed(reason);
        }
    }
}
