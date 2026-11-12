// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

// Reference architecture: YearnMorphoRankedMaster_v9, from supplied v16 ZIP.
// The master is a Yearn V3 TokenizedStrategy. Its shares are held by the
// factory-deployed vault; it owns an append-only set of child strategies.
import {BaseStrategy} from "./YearnBaseStrategyFXUSD_v1.sol";
import {ITokenizedStrategy} from "@tokenized-strategy/interfaces/ITokenizedStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IYearnFXNChildV1 is ITokenizedStrategy {
    function MASTER() external view returns (address);
    function FXN() external view returns (IERC20);
    function positionAssets() external view returns (uint256);
    function claimFxNToMaster() external returns (uint256);
    function compoundFromMaster(uint256 amount) external;
}
interface IYearnCooldownChildV9 {
    function requestMigrationExit(uint256 fxusdAmount) external returns (uint256 shares, uint256 unlockAt);
    function finalizeMigrationExit() external returns (uint256 fxusdReceived);
    function cooldownExitPending() external view returns (bool);
    function cooldownUnlockAt() external view returns (uint256);
    function setUserSettlementActive(bool enabled) external;
    function availableUserCooldownAssets() external view returns (uint256);
    function requestUserCooldownExit(address owner, uint256 vaultShares, uint256 fxusdAmount)
        external returns (uint256 id, uint256 fxspShares, uint256 unlockAt);
    function finalizeUserCooldownExit(uint256 id) external returns (uint256 fxusdReceived);
    function recordUserCooldownSettlement(uint256 id, uint256 amount) external;
    function consumeUserCooldownClaim(uint256 id, address claimant)
        external returns (uint256 shares, uint256 reserved);
    function pendingUserCooldownRequestId() external view returns (uint256);
    function cooldownClaims(uint256 id) external view returns (
        address owner, uint256 shares, uint256 unlockAt, uint256 reserved, bool claimed
    );
}
interface IYearnVaultCooldownV12 is IERC20 {
    function asset() external view returns (address);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function permit(address owner, address spender, uint256 amount, uint256 deadline,
        uint8 v, bytes32 r, bytes32 s) external returns (bool);
    function redeem(uint256 shares, address receiver, address owner, uint256 maxLoss,
        address[] calldata strategies) external returns (uint256 assets);
}
/// @dev Economic-only third child: its FXN and sdFXN holdings are NOT NAV backing.
interface IFXNZeroNAVRewardChild {
    function MASTER() external view returns (address);
    function FXN() external view returns (IERC20);
    function FXUSD() external view returns (IERC20);
    function investFromMaster(uint256 fxnAmount) external;
    function harvestToMaster(address[] calldata conversionTokens, uint256[] calldata minimumFXNOut,
        uint256 minSdFXNToFXN) external returns (uint256 returnedFXN);
}

interface IFXNCurveRewardRouter {
    function FXUSD() external view returns (IERC20);
    function FXN() external view returns (IERC20);
    function master() external view returns (address);
    function swapFXNToFXUSD(uint256 amount) external returns (uint256 received);
}

/// @title Yearn fxUSD manually allocated master and aggregated FXN strategy
/// @notice Factory-deployed Yearn V3 vault -> master -> append-only Yearn FXN children.
/// @dev An allocation of zero disables deposits, harvesting and reporting
///      for that child, but prioritizes its remaining liquidity
///      for withdrawals until the position is emptied.
contract FXNYearnMasterAllocator is BaseStrategy {
    using SafeERC20 for IERC20;
    uint256 private constant BPS = 10_000;
    uint256 private constant MIGRATION_DUST_BPS = 1;
    // The live FXN/WETH Curve pool cannot quote wei-scale reward dust.
    // 1 gwei FXN is well above the observed minimum quote quantum.
    uint256 private constant MIN_ENGINE_FXN_SWAP_WEI = 1e9;

    IERC20 public immutable FXUSD;
    IERC20 public immutable FXN;
    IFXNCurveRewardRouter public immutable rewardRouter;
    IFXNZeroNAVRewardChild public fxnRewardChild;
    uint16 public fxnRewardAllocationBps = 800; // 8% of collected FXN; max 20%
    // Pending economic FXN yield is NOT redeemable fxUSD NAV.
    uint256 public pendingRewardFXN;

    // fxUSD reserved for settled cooldown claims remains physically in the master.
    // Native Yearn ERC4626 withdrawals must never consume it.
    uint256 public totalReservedFxUSD;
    uint256 public minCooldownShares;
    address public cooldownFeeRecipient;
    uint16 public constant COOLDOWN_REQUEST_FEE_BPS = 10; // 0.1%, charged in vault shares
    bool private nativeExitEntered;
    IYearnVaultCooldownV12 public YEARN_VAULT;
    bool private cooldownClaimEntered;


    // Append-only registered children. Registration never implies allocation.
    address[] public children;
    mapping(address => bool) public isChild;
    mapping(address => uint16) public allocationBps;

    // Configurable, append-only priority list. Zero-allocation children are
    // tried before active ones, but both groups follow this priority ordering.
    address[] public withdrawalOrder;
    mapping(address => bool) public cooldownEnabled;
    address public pendingCooldownChild;


    // The default cooldown child is Pool 37; further children remain append-only.
    address public pool37Child;

    // Only explicit management commands start principal migration. An in-flight
    // cooldown may be completed by a keeper in a later transaction.
    bool public manualMigrationPending;


    event YearnVaultBound(address indexed vault);
    event MinCooldownSharesChanged(uint256 oldMinimum, uint256 newMinimum);
    event CooldownFeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event CooldownRequestFee(address indexed owner, address indexed feeRecipient,
        uint256 indexed requestId, uint256 sharesCharged);

    event UserCooldownRequested(uint256 indexed id, address indexed owner,
        uint256 vaultShares, uint256 expectedAssets, uint256 fxspShares, uint256 unlockAt);
    event UserCooldownSettled(uint256 indexed id, uint256 fxUSDReserved);
    event UserCooldownClaimed(uint256 indexed id, address indexed owner, uint256 sharesBurned, uint256 fxusdPaid);
    event ChildrenBound(address indexed child32, address indexed child37);
    event ChildAdded(address indexed child);
    event StrategyAllocationSet(address indexed child, uint16 previousBps, uint16 newBps);
    event StrategyAllocationsConfigured(uint256 activeCount);
    event ManualMigrationStarted();
    event ManualMigrationProgressed(bool complete, address pendingCooldownChild);
    event ChildWithdrawalDeferred(address indexed child, uint256 requested, bytes reason);
    event WithdrawalPriorityConfigured(address[] order);
    event CooldownStrategyConfigured(address indexed child, bool enabled);
    event CooldownMigrationRequested(address indexed child, uint256 shares, uint256 unlockAt);
    event CooldownMigrationFinalized(address indexed child, uint256 assetsFreed);
    event NativeYearnExitLoss(address indexed child, uint256 nominalAssets, uint256 received,
        uint256 loss);

    event WithdrawalSourcesUsed(uint256 nominalNeeded, uint256 childNominal, uint256 childRecovered);
    event DepositRoutedToChildren(uint256 incomingFxUSD, uint256 activeChildren);
    event ChildDepositRouted(address indexed child, uint256 fxusd);
    event ChildHarvested(address indexed child, uint256 fxnClaimed, uint256 fxusdCompounded);
    event AggregatedHarvest(uint256 fxnSold, uint256 fxusdReceived, uint256 activeChildren);
    event FXNRewardChildSet(address indexed child);
    event FXNRewardAllocationSet(uint16 oldBps, uint16 newBps);
    event FXNRewardDiverted(uint256 fxnDeposited, uint256 fxnSwapped);
    event FXNRewardEngineHarvest(uint256 fxnConverted, uint256 fxusdReinvested);
    event FXNRewardDustDeferred(uint256 newlyReceived, uint256 totalPending);
    event FXNChildDustReturned(address indexed child, uint256 amount);


    error BadConfiguration();
    error NoChildren();
    error InsufficientLiquidity();

    constructor(
        address fxusd, address fxn, address tokenizedStrategy, address router
    ) BaseStrategy(fxusd, "CurveYield fxUSD Aggregated Master", tokenizedStrategy) {
        if (fxusd == address(0) || fxn == address(0) || router.code.length == 0)
            revert BadConfiguration();
        IFXNCurveRewardRouter checked = IFXNCurveRewardRouter(router);
        if (address(checked.FXUSD()) != fxusd || address(checked.FXN()) != fxn)
            revert BadConfiguration();
        FXUSD = IERC20(fxusd);
        FXN = IERC20(fxn);
        rewardRouter = checked;
        cooldownFeeRecipient = msg.sender;
    }

    /// @notice Bind the factory-created Yearn vault once, after it has added
    ///         this master as a strategy. No new vault contract is deployed.
    function bindYearnVault(address vault) external onlyManagement {
        if (address(YEARN_VAULT) != address(0) || vault.code.length == 0 ||
            IYearnVaultCooldownV12(vault).asset() != address(FXUSD)) revert BadConfiguration();
        uint8 decimals = IERC20Metadata(vault).decimals();
        if (decimals > 36) revert BadConfiguration();
        minCooldownShares = 10 ** uint256(decimals); // exactly one whole vault share
        YEARN_VAULT = IYearnVaultCooldownV12(vault);
        emit YearnVaultBound(vault);
    }

    /// @notice The minimum is raw vault-share units, not fxUSD units.
    function setMinCooldownShares(uint256 newMinimum) external onlyManagement {
        if (newMinimum == 0) revert BadConfiguration();
        emit MinCooldownSharesChanged(minCooldownShares, newMinimum);
        minCooldownShares = newMinimum;
    }

    /// @notice Request anti-grief tax is transferred in Yearn vault shares,
    ///         never minted and never charged a second time on claim.
    function setCooldownFeeRecipient(address recipient) external onlyManagement {
        if (recipient == address(0)) revert BadConfiguration();
        emit CooldownFeeRecipientChanged(cooldownFeeRecipient, recipient);
        cooldownFeeRecipient = recipient;
    }

    /// @notice Available fxBASE cooldown capacity at this instant. A matured
    ///         but not yet settled older request can be cleared atomically by
    ///         the next request, so this view conservatively returns zero
    ///         until that older exit is finalized.
    function availableCooldownAssets() external view returns (uint256) {
        if (address(YEARN_VAULT) == address(0) || pool37Child == address(0) ||
            manualMigrationPending || pendingCooldownChild != address(0)) return 0;
        return IYearnCooldownChildV9(pool37Child).availableUserCooldownAssets();
    }


    /// @notice Only unreserved fxUSD may fund ordinary master operations.
    function unreservedFxUSD() public view returns (uint256) {
        uint256 balance = FXUSD.balanceOf(address(this));
        if (balance < totalReservedFxUSD) revert InsufficientLiquidity();
        return balance - totalReservedFxUSD;
    }

    /// @notice Public, two-stage fee-free fxBASE cooldown. Users transfer
    ///         their real Yearn vault shares into master custody now; those
    ///         shares remain in supply until the claim transaction burns them.
    function requestCooldownWithdrawal(uint256 vaultShares, uint256 minExpectedAssets)
        external nonReentrantTokenized returns (uint256 id)
    {
        return _requestCooldownWithdrawal(msg.sender, vaultShares, minExpectedAssets);
    }

    /// @notice Optional share permit: approve and escrow vault shares in one
    ///         request transaction, rather than an earlier ERC20 approval.
    function requestCooldownWithdrawalWithPermit(
        uint256 vaultShares, uint256 minExpectedAssets, uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external nonReentrantTokenized returns (uint256 id) {
        if (address(YEARN_VAULT) == address(0)) revert BadConfiguration();
        if (!YEARN_VAULT.permit(msg.sender, address(this), vaultShares, deadline, v, r, s))
            revert BadConfiguration();
        return _requestCooldownWithdrawal(msg.sender, vaultShares, minExpectedAssets);
    }

    function _requestCooldownWithdrawal(address owner, uint256 vaultShares, uint256 minExpectedAssets)
        internal returns (uint256 id)
    {
        if (cooldownClaimEntered || address(YEARN_VAULT) == address(0) ||
            pool37Child == address(0) || manualMigrationPending ||
            pendingCooldownChild != address(0) || vaultShares < minCooldownShares ||
            cooldownFeeRecipient == address(0)) revert BadConfiguration();
        IYearnCooldownChildV9 child = IYearnCooldownChildV9(pool37Child);
        uint256 older = child.pendingUserCooldownRequestId();
        if (older != 0) {
            (,,uint256 unlockAt,,) = child.cooldownClaims(older);
            if (block.timestamp < unlockAt) revert BadConfiguration();
            _settleCooldownWithdrawal(older);
        }
        uint256 feeShares = Math.mulDiv(vaultShares, COOLDOWN_REQUEST_FEE_BPS, BPS, Math.Rounding.Up);
        if (feeShares == 0 || feeShares >= vaultShares) revert BadConfiguration();
        uint256 claimShares = vaultShares - feeShares;
        uint256 expected = YEARN_VAULT.previewRedeem(claimShares);
        if (expected == 0 || expected < minExpectedAssets) revert InsufficientLiquidity();
        if (!YEARN_VAULT.transferFrom(owner, address(this), vaultShares) ||
            !YEARN_VAULT.transfer(cooldownFeeRecipient, feeShares)) revert BadConfiguration();
        (uint256 reqId, uint256 fxspShares, uint256 unlockAt) =
            child.requestUserCooldownExit(owner, claimShares, expected);
        id = reqId;
        emit CooldownRequestFee(owner, cooldownFeeRecipient, id, feeShares);
        emit UserCooldownRequested(id, owner, claimShares, expected, fxspShares, unlockAt);
    }


    /// @notice Anyone can close a mature fxBASE cooldown and credit its
    ///         realized fxUSD in master custody to the earlier requester.
    /// @dev No Yearn vault shares are burned until the owner claims.
    function settleCooldownWithdrawal(uint256 id)
        external nonReentrantTokenized returns (uint256 received)
    {
        if (cooldownClaimEntered && msg.sender != address(this)) revert BadConfiguration();
        return _settleCooldownWithdrawal(id);
    }

    function _settleCooldownWithdrawal(uint256 id) internal returns (uint256 received) {
        IYearnCooldownChildV9 cooldown = IYearnCooldownChildV9(pool37Child);
        if (id == 0 || cooldown.pendingUserCooldownRequestId() != id)
            revert BadConfiguration();
        uint256 realized = cooldown.finalizeUserCooldownExit(id);
        IYearnFXNChildV1 child = IYearnFXNChildV1(pool37Child);
        child.report();
        uint256 owned = child.balanceOf(address(this));
        uint256 sharesToBurn = child.previewWithdraw(realized);
        if (sharesToBurn > owned) sharesToBurn = owned;
        if (sharesToBurn == 0) revert InsufficientLiquidity();
        uint256 beforeBalance = FXUSD.balanceOf(address(this));
        cooldown.setUserSettlementActive(true);
        child.redeem(sharesToBurn, address(this), address(this), BPS);
        cooldown.setUserSettlementActive(false);
        received = FXUSD.balanceOf(address(this)) - beforeBalance;
        if (received == 0) revert InsufficientLiquidity();
        cooldown.recordUserCooldownSettlement(id, received);
        totalReservedFxUSD += received;
        if (FXUSD.balanceOf(address(this)) < totalReservedFxUSD)
            revert InsufficientLiquidity();
        emit UserCooldownSettled(id, received);
    }


    /// @notice Burns the requester's net escrowed Yearn shares. Its settled
    ///         fxUSD is reserved; any extra current-PPS entitlement may use
    ///         only truly unreserved master fxUSD, never another claim's reserve.
    function claimCooldownWithdrawal(uint256 id, uint256 minFXUSDOut, uint16 maxLossBps)
        external returns (uint256 paid)
    {
        if (cooldownClaimEntered || nativeExitEntered || maxLossBps > BPS) revert BadConfiguration();
        cooldownClaimEntered = true;
        IYearnCooldownChildV9 child = IYearnCooldownChildV9(pool37Child);
        (address owner,,,,bool claimed) = child.cooldownClaims(id);
        if (owner != msg.sender || claimed) revert BadConfiguration();
        if (child.pendingUserCooldownRequestId() == id) this.settleCooldownWithdrawal(id);
        (uint256 shares, uint256 entitlement) = child.consumeUserCooldownClaim(id, msg.sender);
        if (YEARN_VAULT.balanceOf(address(this)) < shares) revert BadConfiguration();
        totalReservedFxUSD -= entitlement;
        address[] memory queue = new address[](1);
        queue[0] = address(this);
        uint256 beforeShares = YEARN_VAULT.balanceOf(address(this));
        paid = YEARN_VAULT.redeem(shares, address(this), address(this), maxLossBps, queue);
        if (beforeShares - YEARN_VAULT.balanceOf(address(this)) != shares ||
            paid < minFXUSDOut || paid == 0 ||
            FXUSD.balanceOf(address(this)) < totalReservedFxUSD + paid)
            revert InsufficientLiquidity();
        FXUSD.safeTransfer(msg.sender, paid);
        if (FXUSD.balanceOf(address(this)) < totalReservedFxUSD)
            revert InsufficientLiquidity();
        emit UserCooldownClaimed(id, msg.sender, shares, paid);
        cooldownClaimEntered = false;
    }


    /// @notice Bind the non-NAV economic FXN child, not the fxUSD backing registry.
    /// @dev Its FXN/sdFXN principal never supports Yearn share redemptions.
    function setFXNRewardChild(address child) external onlyManagement {
        if (child.code.length == 0 || address(fxnRewardChild) != address(0) ||
            IFXNZeroNAVRewardChild(child).MASTER() != address(this) ||
            address(IFXNZeroNAVRewardChild(child).FXN()) != address(FXN) ||
            address(IFXNZeroNAVRewardChild(child).FXUSD()) != address(FXUSD))
            revert BadConfiguration();
        fxnRewardChild = IFXNZeroNAVRewardChild(child);
        emit FXNRewardChildSet(child);
    }

    function setFXNRewardAllocationBps(uint16 bps) external onlyManagement {
        if (bps > 2_000) revert BadConfiguration();
        emit FXNRewardAllocationSet(fxnRewardAllocationBps, bps);
        fxnRewardAllocationBps = bps;
    }

    /// @notice Realized engine yield increases backing children; engine principal is never NAV.
    /// @dev Master sells the actual FXN received using the existing approved router,
    ///      reinvests *only* newly received fxUSD, and does not touch cooldown reserves.
    function harvestFXNRewardChild(
        address[] calldata conversionTokens, uint256[] calldata minimumFXNOut, uint256 minSdFXNToFXN
    ) external onlyKeepers nonReentrantTokenized returns (uint256 fxusdReinvested) {
        if (address(fxnRewardChild) == address(0)) revert BadConfiguration();
        uint256 beforeFXN = FXN.balanceOf(address(this));
        uint256 reported = fxnRewardChild.harvestToMaster(conversionTokens, minimumFXNOut, minSdFXNToFXN);
        uint256 receivedFXN = FXN.balanceOf(address(this)) - beforeFXN;
        if (receivedFXN != reported) revert BadConfiguration();
        // Some harvests receive only a few thousand wei of FXN. Curve's
        // FXN/WETH crypto pool reverts even on its get_dy() quote for such dust.
        // Keep it as actual FXN in the master (outside backing NAV), rather
        // than calling a pool with an unquotable amount or losing the reward.
        if (receivedFXN != 0) pendingRewardFXN += receivedFXN;
        if (pendingRewardFXN >= MIN_ENGINE_FXN_SWAP_WEI) {
            uint256 toConvert = pendingRewardFXN;
            if (FXN.balanceOf(address(this)) < toConvert) revert BadConfiguration();
            // Update before external swap; any revert rolls back this ledger.
            pendingRewardFXN = 0;
            fxusdReinvested = _swapAggregatedFXN(toConvert);
            _routeIncomingDeposit(fxusdReinvested);
        } else if (receivedFXN != 0) {
            emit FXNRewardDustDeferred(receivedFXN, pendingRewardFXN);
        }
        emit FXNRewardEngineHarvest(receivedFXN, fxusdReinvested);
    }

    function childCount() external view returns (uint256) { return children.length; }
    function activeChildCount() public view returns (uint256 count) {
        for (uint256 i; i < children.length; ++i)
            if (allocationBps[children[i]] != 0) ++count;
    }



    /// @notice One-time bootstrap for the two original
    ///         routes; additional independently deployed children can be added.
    function bindChildren(address c32, address c37) external onlyManagement {
        if (children.length != 0 || c32 == c37) revert BadConfiguration();
        _addChild(c32);
        _addChild(c37);
        cooldownEnabled[c37] = true;
        emit CooldownStrategyConfigured(c37, true);
        pool37Child = c37;
        allocationBps[c32] = 5_500;
        allocationBps[c37] = 4_500;
        emit StrategyAllocationSet(c32, 0, 5_500);
        emit StrategyAllocationSet(c37, 0, 4_500);
        emit ChildrenBound(c32, c37);
    }

    /// @notice Add a child without ever removing any previously registered
    ///         child. Newly added children have zero allocation until
    ///         management explicitly activates them.
    function addChild(address child) external onlyManagement {
        if (children.length == 0) revert NoChildren();
        _addChild(child);
    }

    function _addChild(address child) internal {
        if (child == address(0) || isChild[child]) revert BadConfiguration();
        _verifyChild(child);
        isChild[child] = true;
        children.push(child);
        withdrawalOrder.push(child);
        emit ChildAdded(child);
    }

    /// @notice Set a full permutation of the append-only registry. Pool 32 is
    ///         first and fxBASE Pool 37 second by default. Zero-weight positions
    ///         remain first-tier withdrawal sources regardless of this ordering.
    function setWithdrawalPriority(address[] calldata order) external onlyManagement {
        if (order.length != children.length || order.length == 0) revert BadConfiguration();
        for (uint256 i; i < order.length; ++i) {
            if (!isChild[order[i]]) revert BadConfiguration();
            for (uint256 j; j < i; ++j) if (order[j] == order[i]) revert BadConfiguration();
        }
        delete withdrawalOrder;
        for (uint256 i; i < order.length; ++i) withdrawalOrder.push(order[i]);
        emit WithdrawalPriorityConfigured(order);
    }



    /// @notice Future children can opt in to the same two-stage cooldown API.
    function setCooldownStrategy(address child, bool enabled) external onlyManagement {
        if (!isChild[child] || pendingCooldownChild == child ||
            (child == pool37Child && !enabled)) revert BadConfiguration();
        if (enabled) {
            (bool ok, bytes memory data) = child.staticcall(
                abi.encodeWithSelector(IYearnCooldownChildV9.cooldownExitPending.selector)
            );
            if (!ok || data.length != 32) revert BadConfiguration();
        }
        cooldownEnabled[child] = enabled;
        emit CooldownStrategyConfigured(child, enabled);
    }

    function _verifyChild(address child) internal view {
        IYearnFXNChildV1 c = IYearnFXNChildV1(child);
        if (child.code.length == 0 || c.asset() != address(FXUSD) ||
            c.MASTER() != address(this) || address(c.FXN()) != address(FXN) ||
            c.keeper() != address(this) || c.profitMaxUnlockTime() != 0 || c.isShutdown())
            revert BadConfiguration();
    }

    /// @notice Set weights for the entire append-only registry in registry
    ///         order. Weights must total 10_000. A zero makes its child entirely
    ///         inactive for deposits, claims and reports.
    ///         A child assigned zero retains its existing position in NAV,
    ///         but becomes the FIRST source for all subsequent withdrawals
    ///         until its position is empty (subject to actual liquidity).
    function setStrategyAllocations(uint16[] calldata weights) external onlyManagement {
        if (children.length == 0 || weights.length != children.length) revert BadConfiguration();
        uint256 total;
        for (uint256 i; i < weights.length; ++i) total += weights[i];
        if (total != BPS) revert BadConfiguration();
        for (uint256 i; i < weights.length; ++i) {
            address child = children[i];
            uint16 old = allocationBps[child];
            if (old != weights[i]) {
                allocationBps[child] = weights[i];
                emit StrategyAllocationSet(child, old, weights[i]);
            }
        }
        emit StrategyAllocationsConfigured(activeChildCount());
    }

    /// @notice Update one registered child's target, compensating through
    ///         another child so the total stays 100%. Either child may become
    ///         0%, but the aggregate still retains at least one active child.
    function setStrategyAllocation(address child, uint16 newBps, address balancingChild)
        external onlyManagement
    {
        if (!isChild[child] || !isChild[balancingChild] || child == balancingChild ||
            newBps > BPS) revert BadConfiguration();
        uint256 combined = uint256(allocationBps[child]) + allocationBps[balancingChild];
        if (newBps > combined) revert BadConfiguration();
        uint16 complementary = uint16(combined - newBps);
        uint16 old = allocationBps[child];
        uint16 oldBalancing = allocationBps[balancingChild];
        allocationBps[child] = newBps;
        allocationBps[balancingChild] = complementary;
        emit StrategyAllocationSet(child, old, newBps);
        emit StrategyAllocationSet(balancingChild, oldBalancing, complementary);
        emit StrategyAllocationsConfigured(activeChildCount());
    }



    function _position(address child) internal view returns (uint256) {
        IYearnFXNChildV1 c = IYearnFXNChildV1(child);
        uint256 shares = c.balanceOf(address(this));
        if (shares == 0) return 0;
        uint256 supply = c.totalSupply();
        if (supply == 0 || shares > supply) revert BadConfiguration();
        return Math.mulDiv(c.positionAssets(), shares, supply);
    }

    /// @dev Zero-allocation positions remain in NAV while invested; normal
    ///      withdrawals preferentially drain those positions rather than lock them.
    function _portfolioValue() internal view returns (uint256 total) {
        // Claim reserves are physically held by the master and counted once
        // in NAV. Only the free portion may fund unrelated operations.
        total = FXUSD.balanceOf(address(this));
        for (uint256 i; i < children.length; ++i) total += _position(children[i]);
    }



    function _withdrawChild(address child, uint256 desired) internal returns (uint256 received) {
        if (!isChild[child] || desired == 0) return 0;
        (received,) = _redeemChildWithAcceptedLoss(child, desired);
    }

    /// @dev Use Yearn native loss-aware redeem for all children. It burns
    /// nominal strategy shares while delivering only net fxUSD after exit costs.
    function _redeemChildWithAcceptedLoss(address child, uint256 desired)
        internal returns (uint256 received, uint256 nominal)
    {
        if (desired == 0 || !isChild[child]) return (0, 0);
        IYearnFXNChildV1 c = IYearnFXNChildV1(child);
        uint256 ownedShares = c.balanceOf(address(this));
        if (ownedShares == 0) return (0, 0);
        uint256 shares = c.previewWithdraw(desired);
        if (shares > ownedShares) shares = ownedShares;
        if (shares > c.maxRedeem(address(this))) shares = c.maxRedeem(address(this));
        if (shares == 0) return (0, 0);
        nominal = c.previewRedeem(shares);
        if (nominal == 0) return (0, 0);
        uint256 beforeBalance = FXUSD.balanceOf(address(this));
        c.redeem(shares, address(this), address(this), 10_000);
        received = FXUSD.balanceOf(address(this)) - beforeBalance;
        if (received > nominal) revert BadConfiguration();
        if (nominal > received) emit NativeYearnExitLoss(child, nominal, received, nominal - received);
    }

    function _depositChild(address child, uint256 desired) internal returns (uint256 spent) {
        if ((allocationBps[child] == 0 || !isChild[child]) || desired == 0) return 0;
        uint256 amount = Math.min(desired, unreservedFxUSD());
        if (amount == 0) return 0;
        FXUSD.forceApprove(child, amount);
        IYearnFXNChildV1(child).deposit(amount, address(this));
        FXUSD.forceApprove(child, 0);
        spent = amount;
    }

    /// @notice Owner-triggered investment of unreserved idle funds to the
    ///         current manually configured targets; never called by a harvest.
    function allocateIdleToManualTargets() external onlyManagement nonReentrantTokenized {
        if (children.length == 0) revert NoChildren();
        _fundManualTargets();
    }

    /// @dev Called only by explicit owner actions, never APR/yield based.
    function _fundManualTargets() internal {
        if (children.length == 0) revert NoChildren();
        uint256 total = _portfolioValue();
        for (uint256 i; i < children.length; ++i) {
            address child = children[i];
            if (allocationBps[child] == 0) continue;
            uint256 target = Math.mulDiv(total, allocationBps[child], BPS);
            uint256 current = _position(child);
            if (target > current) _depositChild(child, target - current);
        }
    }

    /// @notice Owner-authorized principal migration toward manually configured
    /// weights. fxBASE cooldown exits settle in a later transaction; never
    /// invoked by harvesting or automatic deposit allocation.
    function migrateToManualTargets() external onlyManagement nonReentrantTokenized
        returns (bool complete)
    {
        if (children.length == 0 || manualMigrationPending || IYearnCooldownChildV9(pool37Child).pendingUserCooldownRequestId() != 0) revert BadConfiguration();
        manualMigrationPending = true;
        emit ManualMigrationStarted();
        complete = _processManualMigration();
        manualMigrationPending = !complete;
        emit ManualMigrationProgressed(complete, pendingCooldownChild);
    }

    /// @dev Self-call entry point sequences manual migrations and
    /// is not callable directly by arbitrary users.
    /// @dev Only management/keeper entry points execute this internal routine.
    ///      The fxBASE child owns cooldown state, deadlines and redemption mechanics.
    function _processManualMigration() internal returns (bool complete) {
        if (!manualMigrationPending) revert BadConfiguration();
        address pending = pendingCooldownChild;
        if (pending != address(0)) {
            if (block.timestamp < IYearnCooldownChildV9(pending).cooldownUnlockAt()) return false;
            uint256 freed = IYearnCooldownChildV9(pending).finalizeMigrationExit();
            IYearnFXNChildV1(pending).report();
            uint256 ready = FXUSD.balanceOf(pending);
            if (ready != 0) _withdrawChild(pending, ready);
            pendingCooldownChild = address(0);
            emit CooldownMigrationFinalized(pending, freed);
        }
        uint256 total = _portfolioValue();
        uint256 dust = Math.mulDiv(total, MIGRATION_DUST_BPS, BPS) + 1;
        for (uint256 i; i < children.length; ++i) {
            address child = children[i];
            uint256 target = Math.mulDiv(total, allocationBps[child], BPS);
            uint256 current = _position(child);
            if (current <= target + dust) continue;
            if (cooldownEnabled[child]) {
                // Recover any already-idle fxUSD without an additional cooldown.
                uint256 idle = FXUSD.balanceOf(child);
                if (idle != 0) {
                    _withdrawChild(child, Math.min(current - target, idle));
                    total = _portfolioValue();
                    target = Math.mulDiv(total, allocationBps[child], BPS);
                    current = _position(child);
                    dust = Math.mulDiv(total, MIGRATION_DUST_BPS, BPS) + 1;
                    if (current <= target + dust) continue;
                }
                (uint256 shares, uint256 unlockAt) =
                    IYearnCooldownChildV9(child).requestMigrationExit(current - target);
                if (shares == 0) revert InsufficientLiquidity();
                pendingCooldownChild = child;
                emit CooldownMigrationRequested(child, shares, unlockAt);
                return false;
            }
            _withdrawChild(child, current - target);
        }
        _fundManualTargets();
        total = _portfolioValue();
        dust = Math.mulDiv(total, MIGRATION_DUST_BPS, BPS) + 1;
        complete = true;
        for (uint256 i; i < children.length; ++i) {
            address child = children[i];
            if (_position(child) > Math.mulDiv(total, allocationBps[child], BPS) + dust)
                complete = false;
        }
    }


    /// @notice Resume an owner-requested migration after the child cooldown.
    function progressPendingMigration() external onlyKeepers nonReentrantTokenized
        returns (bool complete)
    {
        if (!manualMigrationPending) return true;
        complete = _processManualMigration();
        manualMigrationPending = !complete;
        emit ManualMigrationProgressed(complete, pendingCooldownChild);
    }

    /// @notice Yearn TokenizedStrategy deposit callback; the factory vault's
    ///         auto_allocate debt update invokes this in the SAME transaction
    ///         that the user deposits into the vault.
    /// @dev Allocate *this incoming amount*, not the entire idle balance or
    ///      portfolio-weight deficit. Changes to existing principal require
    ///      an explicit owner migration. Any child failure reverts the
    ///      entire vault deposit, rather than silently leaving part uninvested.
    function _deployFunds(uint256 incomingFxUSD) internal override {
        if (incomingFxUSD == 0) return;
        _routeIncomingDeposit(incomingFxUSD);
    }

    /// @dev Single-pass ratio allocation. Assign rounding dust to the largest
    ///      owner-weighted child, avoiding a separately stored sorted registry.
    function _routeIncomingDeposit(uint256 incomingFxUSD) internal {
        if (children.length == 0 || unreservedFxUSD() < incomingFxUSD) revert NoChildren();
        uint256 primary;
        uint256 topWeight;
        uint256 active;
        for (uint256 i; i < children.length; ++i) {
            uint256 weight = allocationBps[children[i]];
            if (weight == 0) continue;
            ++active;
            if (weight > topWeight) { topWeight = weight; primary = i; }
        }
        if (active == 0) revert NoChildren();
        uint256 remaining = incomingFxUSD;
        for (uint256 i; i < children.length; ++i) {
            if (i == primary || allocationBps[children[i]] == 0) continue;
            uint256 portion = Math.mulDiv(incomingFxUSD, allocationBps[children[i]], BPS);
            if (portion == 0) continue;
            remaining -= portion;
            if (_depositChild(children[i], portion) != portion) revert InsufficientLiquidity();
            emit ChildDepositRouted(children[i], portion);
        }
        if (remaining != 0) {
            if (_depositChild(children[primary], remaining) != remaining)
                revert InsufficientLiquidity();
            emit ChildDepositRouted(children[primary], remaining);
        }
        emit DepositRoutedToChildren(incomingFxUSD, active);
    }


    /// @notice Withdraw zero-target children first, then active children, in
    /// owner's priority order. Gross redeemed shares count toward requested
    /// principal; any Curve LP exit shortfall is NOT topped up from other
    /// children (which would silently socialize the cost to other holders).
    function _withdrawPriority(uint256 need)
        internal returns (uint256 grossConsumed, uint256 netRecovered)
    {
        if (need == 0) return (0, 0);
        (uint256 grossFirst, uint256 netFirst) = _withdrawPriorityTier(need, true);
        grossConsumed = grossFirst;
        netRecovered = netFirst;
        if (grossConsumed < need) {
            (uint256 grossSecond, uint256 netSecond) =
                _withdrawPriorityTier(need - grossConsumed, false);
            grossConsumed += grossSecond;
            netRecovered += netSecond;
        }
    }

    function _withdrawPriorityTier(uint256 need, bool zeroAllocation)
        internal returns (uint256 grossConsumed, uint256 netRecovered)
    {
        for (uint256 i; i < withdrawalOrder.length && grossConsumed < need; ++i) {
            address child = withdrawalOrder[i];
            if ((allocationBps[child] == 0) != zeroAllocation) continue;
            uint256 available;
            try IYearnFXNChildV1(child).maxWithdraw(address(this)) returns (uint256 liquidity) {
                available = Math.min(_position(child), liquidity);
            } catch (bytes memory reason) {
                emit ChildWithdrawalDeferred(child, need - grossConsumed, reason);
                continue;
            }
            uint256 amount = Math.min(need - grossConsumed, available);
            if (amount == 0) continue;
            for (uint256 attempt; attempt < 8 && amount != 0 && grossConsumed < need; ++attempt) {
                try this.withdrawOneChild(child, amount)
                    returns (uint256 received, uint256 nominal)
                {
                    if (nominal == 0) break;
                    grossConsumed += nominal;
                    netRecovered += received;
                    if (grossConsumed >= need) break;
                    try IYearnFXNChildV1(child).maxWithdraw(address(this))
                        returns (uint256 renewed) {
                        amount = Math.min(need - grossConsumed,
                            Math.min(_position(child), renewed));
                    } catch { break; }
                } catch (bytes memory reason) {
                    emit ChildWithdrawalDeferred(child, amount, reason);
                    amount /= 2;
                }
            }
        }
    }

    /// @dev Only internal scheduler self-calls can access this entry point.
    function withdrawOneChild(address child, uint256 amount)
        external returns (uint256 received, uint256 nominal)
    {
        if (msg.sender != address(this) || !isChild[child]) revert BadConfiguration();
        return _redeemChildWithAcceptedLoss(child, amount);
    }

    function _freeFunds(uint256 amount) internal override {
        if (children.length == 0) revert NoChildren();
        if (cooldownClaimEntered) return; // never draw other child liquidity for a claim
        // Fallback for any shortfall remaining after the entry-point prefund.
        // Yearn handles user-specified maxLoss when recovered assets are short.
        _withdrawPriority(amount);
    }

    /// @dev Yearn's native ERC4626 exit consumes idle tokens before invoking
    ///      _freeFunds. Withdraw from children *before* delegating to that
    ///      implementation so master-held, unreserved fxUSD is used last.
    ///      As with standard Yearn exits, all transfers are atomic. The normal
    ///      reservation guard still protects settled cooldown requests.
    function _prefundNativeExit(uint256 nominalAssets) internal {
        if (cooldownClaimEntered || children.length == 0 || nominalAssets == 0) return;
        (uint256 gross, uint256 net) = _withdrawPriority(nominalAssets);
        emit WithdrawalSourcesUsed(nominalAssets, gross, net);
    }

    /// @dev Official TokenizedStrategy treats *all* on-contract fxUSD as loose.
    ///      The standard withdrawal callback alone cannot exclude reserves;
    ///      guard all four native entry points and verify the remaining balance.
    ///      A claim may consume only its explicitly released reservation.
    function _startNativeExit() internal {
        if (nativeExitEntered) revert BadConfiguration();
        nativeExitEntered = true;
        if (cooldownClaimEntered && msg.sender != address(YEARN_VAULT))
            revert BadConfiguration();
    }

    function _endNativeExit() internal {
        if (FXUSD.balanceOf(address(this)) < totalReservedFxUSD)
            revert InsufficientLiquidity();
        nativeExitEntered = false;
    }

    function redeem(uint256 shares, address receiver, address owner)
        external returns (uint256 assets)
    {
        _startNativeExit();
        _prefundNativeExit(ITokenizedStrategy(address(this)).previewRedeem(shares));
        assets = abi.decode(_delegateCall(abi.encodeWithSignature(
            "redeem(uint256,address,address)", shares, receiver, owner)), (uint256));
        _endNativeExit();
    }

    function redeem(uint256 shares, address receiver, address owner, uint256 maxLoss)
        external returns (uint256 assets)
    {
        _startNativeExit();
        _prefundNativeExit(ITokenizedStrategy(address(this)).previewRedeem(shares));
        assets = abi.decode(_delegateCall(abi.encodeWithSignature(
            "redeem(uint256,address,address,uint256)", shares, receiver, owner, maxLoss)),
            (uint256));
        _endNativeExit();
    }

    function withdraw(uint256 assets, address receiver, address owner)
        external returns (uint256 shares)
    {
        _startNativeExit();
        _prefundNativeExit(assets);
        shares = abi.decode(_delegateCall(abi.encodeWithSignature(
            "withdraw(uint256,address,address)", assets, receiver, owner)), (uint256));
        _endNativeExit();
    }

    function withdraw(uint256 assets, address receiver, address owner, uint256 maxLoss)
        external returns (uint256 shares)
    {
        _startNativeExit();
        _prefundNativeExit(assets);
        shares = abi.decode(_delegateCall(abi.encodeWithSignature(
            "withdraw(uint256,address,address,uint256)", assets, receiver, owner, maxLoss)),
            (uint256));
        _endNativeExit();
    }

    function availableWithdrawLimit(address) public view override returns (uint256 total) {
        total = unreservedFxUSD();
        // Every registered child contributes recoverable liquidity, including
        // zero-target positions. Their preferred withdrawal order is enforced
        // in _withdrawPriority, not by excluding liquidity from this view.
        for (uint256 i; i < children.length; ++i) {
            address c = children[i];
            total += Math.min(_position(c), IYearnFXNChildV1(c).maxWithdraw(address(this)));
        }
    }

    function _emergencyWithdraw(uint256 amount) internal override {
        if (children.length != 0) {
            uint256 idle = unreservedFxUSD();
            if (amount > idle) _freeFunds(amount - idle);
        }
    }

    function _harvestAndReport() internal override returns (uint256) { return _portfolioValue(); }

    /// @notice Harvest all active children once, swap the sum of their FXN
    ///         through the single Curve route, and compound pro rata.
    ///         A child with zero allocation is excluded from harvesting and
    ///         reporting, but remains eligible for priority withdrawals.
    function harvestActive() external onlyKeepers nonReentrantTokenized
        returns (uint256 fxnSold, uint256 fxusdReceived)
    {
        (fxnSold, fxusdReceived,) = _harvestActive();
    }

    /// @notice Backwards-compatible name; harvests all active children.
    ///         Returns only the original two child payouts; events cover others.


    function _harvestActive() internal returns (uint256 totalFXN, uint256 fxusdReceived,
        uint256[] memory payouts)
    {
        if (children.length == 0) revert NoChildren();
        uint256 n = children.length;
        uint256[] memory claims = new uint256[](n);
        payouts = new uint256[](n);
        uint256 activeCount;
        for (uint256 i; i < n; ++i) {
            address child = children[i];
            if (allocationBps[child] == 0) continue;
            ++activeCount;
            uint256 before = FXN.balanceOf(address(this));
            IYearnFXNChildV1(child).claimFxNToMaster();
            claims[i] = FXN.balanceOf(address(this)) - before;
            totalFXN += claims[i];
        }
        if (activeCount == 0) revert NoChildren();
        // Curve's FXN/WETH pool rejects wei-scale swaps. Keep every tiny
        // reward with its original child so the next claim accumulates it,
        // preserving child-level attribution without manufactured yield.
        if (totalFXN != 0 && totalFXN < MIN_ENGINE_FXN_SWAP_WEI) {
            for (uint256 i; i < n; ++i) {
                if (claims[i] != 0) {
                    FXN.safeTransfer(children[i], claims[i]);
                    emit FXNChildDustReturned(children[i], claims[i]);
                }
            }
            totalFXN = 0;
        }
        if (totalFXN != 0) {
            uint256 fxnForEngine = Math.mulDiv(totalFXN, fxnRewardAllocationBps, BPS);
            if (fxnForEngine != 0) {
                if (address(fxnRewardChild) == address(0)) revert BadConfiguration();
                FXN.safeTransfer(address(fxnRewardChild), fxnForEngine);
                fxnRewardChild.investFromMaster(fxnForEngine);
            }
            uint256 fxnForBacking = totalFXN - fxnForEngine;
            emit FXNRewardDiverted(fxnForEngine, fxnForBacking);
            if (fxnForBacking != 0) fxusdReceived = _swapAggregatedFXN(fxnForBacking);
            uint256 credited;
            uint256 lastContributor;
            for (uint256 i; i < n; ++i) if (claims[i] != 0) lastContributor = i;
            for (uint256 i; i < n; ++i) {
                uint256 contribution = claims[i];
                if (contribution == 0) continue;
                uint256 payout = i == lastContributor ? fxusdReceived - credited
                    : Math.mulDiv(fxusdReceived, contribution, totalFXN);
                credited += payout;
                payouts[i] = payout;
                if (payout != 0) {
                    FXUSD.safeTransfer(children[i], payout);
                    IYearnFXNChildV1(children[i]).compoundFromMaster(payout);
                }
            }
        }
        for (uint256 i; i < n; ++i) {
            if (allocationBps[children[i]] == 0) continue;
            IYearnFXNChildV1(children[i]).report();
            emit ChildHarvested(children[i], claims[i], payouts[i]);
        }
        emit AggregatedHarvest(totalFXN - Math.mulDiv(totalFXN, fxnRewardAllocationBps, BPS), fxusdReceived, activeCount);
    }

    /// @dev Router is the only contract with exchange and oracle knowledge.
    ///      It pulls exactly the harvested FXN and pays fxUSD directly back to
    ///      the master. The master attributes the balance delta to children.
    function _swapAggregatedFXN(uint256 amount) internal returns (uint256 fxusdOut) {
        if (rewardRouter.master() != address(this)) revert BadConfiguration();
        uint256 beforeFxUSD = FXUSD.balanceOf(address(this));
        FXN.forceApprove(address(rewardRouter), amount);
        uint256 reported = rewardRouter.swapFXNToFXUSD(amount);
        FXN.forceApprove(address(rewardRouter), 0);
        fxusdOut = FXUSD.balanceOf(address(this)) - beforeFxUSD;
        if (fxusdOut == 0 || fxusdOut != reported) revert BadConfiguration();
    }
}