// SPDX-License-Identifier: UNLICENSED
// BoostHub implementation revision: v26 (source-only structural organization)
/**
 * @title CurveYield System Component
 * @notice CurveYield is a decentralized NGO building optimized DeFi systems for the good of all.
 *
 * @dev CurveYield integrates specialized AMM infrastructure, tokenized yield strategies, credit
 * markets, and protocol-owned liquidity into a unified, capital-efficient liquidity stack governed
 * by an open, international DAO community.
 *
 * Protocol operations are enhanced by cross-chain bridging and messaging, MEV capture systems,
 * off-chain to on-chain automation, and peer-to-peer data networks.
 *
 * This contract is one component of the CurveYield system.
 *
 * CurveYield uses proven DeFi primitives where possible and adds targeted coordination and
 * capital-efficiency-enhancing contracts where needed. Users and integrators must review
 * CurveYield documentation before use.
 *
 * Learn more:
 * Documentation: https://docs.curveyield.com
 * dApp: https://curveyield.online
 * GitHub: https://github.com/curveyield
 *
 * Decentralized links may have limited or delayed availability during periods of high network activity:
 * https://curveyield.eth.limo
 * https://curveyield.dao
 *
 * Note: curveyield.dao may require a Brave Browser or an Unstoppable Domains browser plugin to use.
 */
pragma solidity 0.8.28;

// ========================================================================
// 01. Imports, interfaces, constants, structs, and storage
// ========================================================================

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBoostHub} from "./interfaces/IBoostHub.sol";
import {IStakeDaoGauge} from "./interfaces/IStakeDaoGauge.sol";
import {IvlBoost} from "./interfaces/IvlBoost.sol";
import {BoostHubErrors as Errors} from "./libraries/BoostHubErrors.sol";

interface ISnapshotDelegateRegistry {
    function setDelegate(bytes32 spaceId, address delegate) external;
}

/// @dev Ethereum Stake DAO indexed distribution (former Ethereum executor ABI).
interface IMultiMerkleStash {
    function update(address token) external view returns (uint256);
    function claim(address token, uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external;
}

/// @dev Fraxtal Stake DAO cumulative URD distribution (former Fraxtal executor ABI).
interface IStakeDaoUniversalRewardsDistributor {
    function recipients(address account) external view returns (address);
    function claim(address account, address reward, uint256 cumulativeClaimable, bytes32[] calldata proof)
        external returns (uint256 amount);
}

contract BoostHub is IBoostHub, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 internal constant ACC_PRECISION = 1e18;
    uint256 internal constant MAX_REWARD_TOKENS = 9; // Principal plus up to eight gauge reward tokens.
    uint256 internal constant MAX_GAUGE_REWARD_TOKENS = 8;
    uint256 internal constant FEE_DENOMINATOR = 10_000;
    uint256 internal constant MAX_PERFORMANCE_FEE_BPS = 2_500;
    uint256 internal constant INITIAL_CONFIG_WINDOW = 7 days;
    uint256 private immutable deployedAt;
    uint256 private constant CONFIG_CHANGE_DELAY = 10 days;
    uint256 public constant EMERGENCY_RECOVERY_DELAY = 90 days;
    bytes4 internal constant ERC1271_MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant ERC1271_INVALID = 0xffffffff;
    bytes32 internal constant SNAPSHOT_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version)");
    bytes32 internal constant SNAPSHOT_NAME_HASH = keccak256("snapshot");
    bytes32 internal constant SNAPSHOT_VERSION_HASH = keccak256("0.1.4");
    bytes32 internal constant SNAPSHOT_VOTE_UINT32_TYPEHASH =
        keccak256("Vote(string from,string space,uint64 timestamp,string proposal,uint32 choice,string reason,string app,string metadata)");

    struct Pool {
        address asset;
        bool active; // Packed alongside asset to save one storage slot per pool.
        address gauge;
        uint256 totalStaked;
        address[] rewardTokens;
    }

    struct Position {
        uint256 principal;
        mapping(address => uint256) rewardDebt;
        mapping(address => uint256) claimable;
    }

    struct FeeConfig {
        uint16 platformFeeBps;
        address platformFeeRecipient;
    }

    struct PendingFeeConfig {
        FeeConfig config;
        uint256 readyAt;
    }

    address private _pendingOwner;

    Pool[] internal pools;

    address private immutable vlBoost;

    /// @notice The *distributor*, not a separate executor. Chain 1: MultiMerkleStash; chain 252: URD.
    address public rewardDistributor;
    address public pendingRewardDistributor;
    uint256 public pendingRewardDistributorReadyAt;
    uint256 private ownershipTransferReadyAt;
    mapping(uint256 => FeeConfig) private poolFeeConfig;
    mapping(uint256 => PendingFeeConfig) private pendingPoolFeeConfig;
    mapping(uint256 => bool) private poolFeeConfigSet;

    // Tokens held for accrued user rewards, including undistributed rounding dust.
    mapping(address => uint256) private _rewardTokenReserves;
    // Owner-owned assets are never swept into participant rewards.
    mapping(address => uint256) private _ownerRewardReserves;
    mapping(address => bool) private _rewardTokenListed;
    // Matching deposit-token rewards have one explicitly approved receiving PID.
    // Zero disables direct locker reward attribution for that token.
    mapping(address => uint256) public approvedLockerRewardPidPlusOne;
    // Detect locker deposit tokens and avoid guessing when PIDs share an asset.
    mapping(address => bool) private _lockerDepositTokens;
    bool public automaticHarvestOnDeposit = true;
    bytes32 public pendingEmergencyRecoveryHash;
    uint256 public pendingEmergencyRecoveryReadyAt;
    mapping(uint256 => bytes4) private poolCheckpointSelector;

    // The first entry is exposed as the legacy PoolView.depositor without separate storage.
    mapping(uint256 => address[]) private poolDepositorAllowlist;
    mapping(uint256 => mapping(address => uint256)) private depositorIndexPlusOne;
    mapping(uint256 => bool) private poolDepositorLocked;
    mapping(address => bool) private gaugeAdded;
    mapping(uint256 => mapping(address => Position)) internal positions;
    mapping(uint256 => mapping(address => uint256)) private accRewardPerShare;
    mapping(bytes32 => bool) private approvedSnapshotVoteHash;

    // ========================================================================
    // 02. Events and custom errors
    // ========================================================================

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event TransactionsCleared();
    event PoolAdded(uint256 indexed pid, address indexed asset, address indexed gauge);
    event PoolActiveSet(uint256 indexed pid, bool active);
    event PoolDepositorAllowlistLocked(uint256 indexed pid);
    event PoolDepositorApproval(uint256 indexed pid, address indexed depositor, bool approved);
    event AutomaticHarvestOnDepositSet(bool enabled);
    event BoostCheckpointFailed(address indexed account);
    event GaugeCheckpointFailed(uint256 indexed pid, address indexed gauge);
    event OwnerRewardTokensReserved(address indexed token, uint256 amount);
    event OwnerRewardTokensReleased(address indexed token, address indexed recipient, uint256 amount);
    event EmergencyRecoveryStarted(bytes32 indexed callsHash, uint256 readyAt);
    event EmergencyRecoveryCanceled(bytes32 indexed callsHash);
    event EmergencyRecoveryExecuted(bytes32 indexed callsHash, uint256 callCount);
    event PoolFeesSet(uint256 indexed pid, uint16 platformFeeBps, address platformFeeRecipient);
    event PoolFeesQueued(uint256 indexed pid, uint16 platformFeeBps, address platformFeeRecipient, uint256 readyAt);
    event PoolCheckpointSelectorSet(uint256 indexed pid, bytes4 selector);
    event PoolRewardTokenAdded(uint256 indexed pid, address indexed rewardToken);
    event RewardAttributed(uint256 indexed pid, address indexed token, uint256 gross, uint256 net);
    event ApprovedLockerRewardTokenSet(address indexed token, uint256 indexed pid, bool approved);
    event GaugeCheckpointed(uint256 indexed pid);
    event BoostCheckpointed(address indexed account);
    event StakeDaoAddressesSet(address indexed vlBoost);
    event StakeDaoRewardDistributorSet(address indexed distributor);
    event StakeDaoRewardDistributorQueued(address indexed distributor, uint256 readyAt);
    event EthereumMerkleRewardClaimed(
        address indexed token, uint256 indexed updateNumber, uint256 indexed index,
        uint256 amount, uint256 received
    );
    event FraxtalUrdRewardClaimed(
        address indexed reward, uint256 cumulativeClaimable, uint256 received
    );
    event UnreservedTokensSwept(address indexed token, address indexed recipient, uint256 amount);
    event VotingPowerDelegated(address indexed registry, bytes32 indexed spaceId, string space, address indexed delegate);
    event SnapshotVoteHashApproved(bytes32 indexed hash, bytes32 indexed spaceId);
    error TimelockNotReady();
    error NoPendingChange();
    error WrongClaimChain(uint256 expected, uint256 actual);
    error MissingDistributorCode(address distributor);
    error EmptyClaims();
    error InvalidClaimAmount();
    error RewardTokenNotRegistered(address token);
    error UnsafeUrdRecipient(address recipient);
    error ClaimedBalanceMismatch(uint256 returnedDelta, uint256 observedDelta);
    error EmergencyRecoveryPending();
    error EmergencyRecoveryNotPending();
    error EmergencyRecoveryCallsMismatch();
    error EmergencyRecoveryCallFailed(uint256 index, bytes reason);
    error RewardReserveUnderfunded(address token);
    error LockerRewardPidMismatch(address token, uint256 pid);
    error LockerRewardNotApproved(address token);
    error ZeroSnapshotVoteHash();

    // ========================================================================
    // 03. Constructor and protocol configuration
    // ========================================================================

    constructor(address owner_, address vlBoost_, address rewardDistributor_) Ownable(owner_) {
        if (rewardDistributor_ == address(0)) revert Errors.ZeroAddress();
        if (rewardDistributor_.code.length == 0) revert MissingDistributorCode(rewardDistributor_);
        deployedAt = block.timestamp;
        vlBoost = vlBoost_;
        rewardDistributor = rewardDistributor_;
        emit StakeDaoAddressesSet(vlBoost_);
        emit StakeDaoRewardDistributorSet(rewardDistributor_);
    }

    receive() external payable {}

    // ========================================================================
    // 04. Ownership, timelocks, and fee administration
    // ========================================================================

    /// @notice Queue a new trusted Stake DAO Merkle/URD distributor for the standard 10-day delay.
    function setRewardDistributor(address distributor) external onlyOwner {
        if (distributor == address(0)) revert Errors.ZeroAddress();
        if (distributor.code.length == 0) revert MissingDistributorCode(distributor);
        if (distributor == rewardDistributor) {
            delete pendingRewardDistributor;
            delete pendingRewardDistributorReadyAt;
            return;
        }
        if (pendingRewardDistributor == distributor) return;
        pendingRewardDistributor = distributor;
        pendingRewardDistributorReadyAt = block.timestamp + CONFIG_CHANGE_DELAY;
        emit StakeDaoRewardDistributorQueued(distributor, pendingRewardDistributorReadyAt);
    }

    function transferOwnership(address newOwner) public override onlyOwner nonReentrant {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
        ownershipTransferReadyAt = newOwner == address(0) ? 0 : _queuedTransactionReadyAt();
    }

    /// @notice Execute every queued ownership, fee and distributor change whose delay expired.
    function executeTransactions() external nonReentrant {
        address newOwner = _pendingOwner;
        bool ownershipReady = newOwner != address(0) && block.timestamp >= ownershipTransferReadyAt;
        if (ownershipReady) {
            if (_msgSender() != newOwner) revert OwnableUnauthorizedAccount(_msgSender());
            _transferOwnership(newOwner);
        } else {
            _checkOwner();
        }
        if (pendingRewardDistributor != address(0) && block.timestamp >= pendingRewardDistributorReadyAt) {
            address next = pendingRewardDistributor;
            if (next.code.length == 0) revert MissingDistributorCode(next);
            rewardDistributor = next;
            delete pendingRewardDistributor;
            delete pendingRewardDistributorReadyAt;
            emit StakeDaoRewardDistributorSet(next);
        }
        for (uint256 pid; pid < pools.length; ++pid) {
            uint256 readyAt = pendingPoolFeeConfig[pid].readyAt;
            if (readyAt != 0 && block.timestamp >= readyAt) _applyPoolFees(pid);
        }
    }

    /// @notice Cancel queued actions, but leave active configuration untouched.
    function clearTransactions() external onlyOwner nonReentrant {
        delete _pendingOwner;
        delete ownershipTransferReadyAt;
        delete pendingRewardDistributor;
        delete pendingRewardDistributorReadyAt;
        for (uint256 pid; pid < pools.length; ++pid) {
            delete pendingPoolFeeConfig[pid];
        }
        emit TransactionsCleared();
    }

    /// @notice First invocation commits the exact arbitrary calls and starts the 90-day freeze.
    ///         Repeat with IDENTICAL arrays after 90 days to execute the approved batch.
    ///         All calls are atomic. Cancellation is a separate owner operation.
    function emergencyStopRecoveryAndMigrate(
        address[] calldata targets, uint256[] calldata values, bytes[] calldata callData
    ) external onlyOwner nonReentrant {
        if (targets.length != values.length || targets.length != callData.length) revert Errors.LengthMismatch();
        if (targets.length == 0) revert Errors.ZeroAmount();
        bytes32 callsHash = keccak256(abi.encode(targets, values, callData));
        bytes32 pending = pendingEmergencyRecoveryHash;
        if (pending == bytes32(0)) {
            for (uint256 i; i < targets.length; ++i) {
                if (targets[i] == address(0)) revert Errors.ZeroAddress();
            }
            pendingEmergencyRecoveryHash = callsHash;
            pendingEmergencyRecoveryReadyAt = block.timestamp + EMERGENCY_RECOVERY_DELAY;
            emit EmergencyRecoveryStarted(callsHash, pendingEmergencyRecoveryReadyAt);
            return;
        }
        if (callsHash != pending) revert EmergencyRecoveryCallsMismatch();
        if (block.timestamp < pendingEmergencyRecoveryReadyAt) revert TimelockNotReady();
        delete pendingEmergencyRecoveryHash;
        delete pendingEmergencyRecoveryReadyAt;
        for (uint256 i; i < targets.length; ++i) {
            (bool ok, bytes memory response) = targets[i].call{value: values[i]}(callData[i]);
            if (!ok) revert EmergencyRecoveryCallFailed(i, response);
        }
        emit EmergencyRecoveryExecuted(callsHash, targets.length);
    }

    function cancelEmergencyStopRecoveryAndMigrate() external onlyOwner {
        bytes32 pending = pendingEmergencyRecoveryHash;
        if (pending == bytes32(0)) revert EmergencyRecoveryNotPending();
        delete pendingEmergencyRecoveryHash;
        delete pendingEmergencyRecoveryReadyAt;
        emit EmergencyRecoveryCanceled(pending);
    }

    // ========================================================================
    // 05. Pool registration, allowlists, and activation
    // ========================================================================

    function addPoolsBatch(
        address[] calldata assets,
        address[] calldata gauges,
        address[][] calldata rewardTokens
    ) external onlyOwner returns (uint256[] memory pids) {
        uint256 length = assets.length;
        if (length != gauges.length || length != rewardTokens.length) revert Errors.LengthMismatch();
        pids = new uint256[](length);
        for (uint256 i; i < length; ++i) {
            pids[i] = _addPool(assets[i], gauges[i], rewardTokens[i]);
        }
    }

    /// @notice Batch-add or revoke approved depositors for one pool, then optionally freeze the allowlist.
    /// @dev Revoking does not confiscate an existing position or its claimable rewards.
    function setApprovedDepositors(uint256 pid, address[] calldata depositors, bool[] calldata approvals, bool lockList)
        external onlyOwner
    {
        _pool(pid);
        if (depositors.length != approvals.length) revert Errors.LengthMismatch();
        for (uint256 i; i < depositors.length; ++i) {
            _setPoolDepositorApproval(pid, depositors[i], approvals[i]);
        }
        if (lockList && !poolDepositorLocked[pid]) {
            poolDepositorLocked[pid] = true;
            emit PoolDepositorAllowlistLocked(pid);
        }
    }

    /// @notice Sets depositors, optional permanent locks, checkpoints, queued fees and pool activity.
    /// @dev Each supplied depositor is added to that PID's allowlist; it never replaces existing approvals.
    function setDepositors(
        uint256[] memory pids,
        address[] memory depositors,
        bool[] memory lockDepositors,
        bytes4[] memory checkpointSelectors,
        FeeConfig[] memory configs,
        bool[] memory active
    ) external onlyOwner {
        uint256 length = pids.length;
        if (
            length != depositors.length || length != lockDepositors.length ||
            length != checkpointSelectors.length || length != configs.length || length != active.length
        ) revert Errors.LengthMismatch();
        for (uint256 i; i < length; ++i) {
            uint256 pid = pids[i];
            _setPoolDepositor(pid, depositors[i], lockDepositors[i]);
            if (checkpointSelectors[i] != bytes4(0)) {
                _setPoolCheckpointSelector(pid, checkpointSelectors[i]);
            }
            if (!_feeConfigIsCurrentOrQueued(pid, configs[i])) _setPoolFees(pid, configs[i]);
            Pool storage pool = _pool(pid);
            if (pool.active != active[i]) {
                pool.active = active[i];
                emit PoolActiveSet(pid, active[i]);
            }
        }
    }

    function setAutomaticHarvestOnDeposit(bool enabled) external onlyOwner {
        automaticHarvestOnDeposit = enabled;
        emit AutomaticHarvestOnDepositSet(enabled);
    }

    /// @notice Configure the deposit-token-to-PID allowlist used for Merkle/URD rewards.
    /// @dev Approval requires that the selected PID actually stakes this token.
    function setApprovedLockerRewardToken(address token, uint256 pid, bool approved) external onlyOwner {
        if (token == address(0)) revert Errors.ZeroAddress();
        if (approved) {
            if (_pool(pid).asset != token) revert LockerRewardPidMismatch(token, pid);
            approvedLockerRewardPidPlusOne[token] = pid + 1;
        } else {
            delete approvedLockerRewardPidPlusOne[token];
        }
        emit ApprovedLockerRewardTokenSet(token, pid, approved);
    }

    // ========================================================================
    // 06. Deposits and withdrawals
    // ========================================================================

    function deposit(uint256 pid, uint256 amount) external virtual override nonReentrant {
        if (amount == 0) revert Errors.ZeroAmount();
        Pool storage pool = _pool(pid);
        if (pendingEmergencyRecoveryHash != bytes32(0)) revert EmergencyRecoveryPending();
        if (depositorIndexPlusOne[pid][msg.sender] == 0) revert Errors.StrategyNotApproved();
        if (!pool.active) revert Errors.PoolInactive();
        if (automaticHarvestOnDeposit) _harvest(pid, pool, false);
        IERC20(pool.asset).safeTransferFrom(msg.sender, address(this), amount);
        IStakeDaoGauge(pool.gauge).deposit(amount, address(this));
        Position storage position = positions[pid][msg.sender];
        _checkpoint(pid, msg.sender, position.principal + amount);
        position.principal += amount;
        pool.totalStaked += amount;
    }

    function withdraw(uint256 pid, uint256 amount) external virtual override nonReentrant {
        if (amount == 0) revert Errors.ZeroAmount();
        Pool storage pool = _pool(pid);
        Position storage position = positions[pid][msg.sender];
        // Account for earnings against old principal; set new debt in the same loop.
        _checkpoint(pid, msg.sender, position.principal - amount);
        position.principal -= amount;
        pool.totalStaked -= amount;
        IStakeDaoGauge(pool.gauge).withdraw(amount, false);
        IERC20(pool.asset).safeTransfer(msg.sender, amount);
    }

    // ========================================================================
    // 07. Gauge harvesting and reward attribution
    // ========================================================================

    /// @notice Checkpoints vlBoost when configured, then the selected pools' gauges.
    /// @dev A zero vlBoost disables boost integration for chains such as Fraxtal.
    ///      A failed individual checkpoint is reported but does not abort other checkpoints.
    function checkpoint(uint256[] calldata pids) external nonReentrant returns (bool allSucceeded) {
        allSucceeded = true;
        if (vlBoost != address(0)) {
            try IvlBoost(vlBoost).checkpointUser(address(this)) {
                emit BoostCheckpointed(address(this));
            } catch {
                allSucceeded = false;
                emit BoostCheckpointFailed(address(this));
            }
        }
        for (uint256 i; i < pids.length; ++i) {
            uint256 pid = pids[i];
            if (pid >= pools.length) {
                allSucceeded = false;
                emit GaugeCheckpointFailed(pid, address(0));
                continue;
            }
            Pool storage pool = pools[pid];
            bytes4 selector = poolCheckpointSelector[pid];
            if (selector == bytes4(0) || !_checkpointGauge(pool.gauge, selector)) {
                allSucceeded = false;
                emit GaugeCheckpointFailed(pid, pool.gauge);
                continue;
            }
            emit GaugeCheckpointed(pid);
        }
    }

    function harvest(uint256 pid) public virtual override nonReentrant
        returns (address[] memory tokens, uint256[] memory amounts)
    {
        Pool storage pool = _pool(pid);
        (tokens, amounts) = _harvest(pid, pool, true);
    }

    // ========================================================================
    // 08. Merkle and URD reward claims
    // ========================================================================

    /// @notice Claim Ethereum Stake DAO distributions, attributing approved locker tokens immediately.
    /// @dev The configured distributor verifies proofs and claimed state.
    function claimEthereumMerkleRewards(EthereumMerkleClaim[] calldata claims)
        public override nonReentrant returns (uint256[] memory amounts)
    {
        _requireClaimChain(1);
        if (claims.length == 0) revert EmptyClaims();
        IMultiMerkleStash stash = IMultiMerkleStash(rewardDistributor);
        amounts = new uint256[](claims.length);
        for (uint256 i; i < claims.length; ++i) {
            EthereumMerkleClaim calldata entry = claims[i];
            _requireRegisteredRewardToken(entry.token);
            if (entry.amount == 0) revert InvalidClaimAmount();
            uint256 updateNumber = stash.update(entry.token);
            uint256 beforeBalance = IERC20(entry.token).balanceOf(address(this));
            stash.claim(entry.token, entry.index, address(this), entry.amount, entry.proof);
            uint256 received = IERC20(entry.token).balanceOf(address(this)) - beforeBalance;
            if (received == 0) revert InvalidClaimAmount();
            _attributeClaimedLockerReward(entry.token, received);
            amounts[i] = received;
            emit EthereumMerkleRewardClaimed(entry.token, updateNumber, entry.index, entry.amount, received);
        }
    }

    /// @notice Claim Fraxtal Stake DAO URD cumulative distributions, attributing locker tokens immediately.
    /// @dev Fraxtal uses double-keccak leaves and cumulative claimed amounts, NOT Ethereum's index leaf.
    function claimFraxtalMerkleRewards(FraxtalUrdClaim[] calldata claims)
        public override nonReentrant returns (uint256[] memory amounts)
    {
        _requireClaimChain(252);
        if (claims.length == 0) revert EmptyClaims();
        IStakeDaoUniversalRewardsDistributor urd = IStakeDaoUniversalRewardsDistributor(rewardDistributor);
        // The URD can redirect rewards; reject any recipient other than BoostHub.
        address recipient = urd.recipients(address(this));
        if (recipient != address(0) && recipient != address(this)) revert UnsafeUrdRecipient(recipient);
        amounts = new uint256[](claims.length);
        for (uint256 i; i < claims.length; ++i) {
            FraxtalUrdClaim calldata entry = claims[i];
            _requireRegisteredRewardToken(entry.reward);
            if (entry.cumulativeClaimable == 0) revert InvalidClaimAmount();
            uint256 beforeBalance = IERC20(entry.reward).balanceOf(address(this));
            uint256 reported = urd.claim(address(this), entry.reward, entry.cumulativeClaimable, entry.proof);
            uint256 received = IERC20(entry.reward).balanceOf(address(this)) - beforeBalance;
            if (reported == 0 || received != reported) revert ClaimedBalanceMismatch(reported, received);
            _attributeClaimedLockerReward(entry.reward, received);
            amounts[i] = received;
            emit FraxtalUrdRewardClaimed(entry.reward, entry.cumulativeClaimable, received);
        }
    }

    // ========================================================================
    // 09. Participant reward claims and owner sweep
    // ========================================================================

    /// @notice Claims the selected registered reward tokens; omitted rewards remain claimable.
    /// @dev A failing selected token reverts this call; omit it to claim the other tokens.
    function claim(uint256 pid, address[] calldata rewardTokens, address receiver)
        external virtual override nonReentrant returns (address[] memory tokens, uint256[] memory amounts)
    {
        if (receiver == address(0)) revert Errors.ZeroAddress();
        if (!_canClaim(pid, msg.sender)) revert Errors.StrategyNotApproved();
        Pool storage pool = _pool(pid);
        Position storage position = positions[pid][msg.sender];
        tokens = rewardTokens;
        amounts = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            if (!_isRewardToken(pool, token)) revert Errors.RewardTokenNotRegistered();
            uint256 stored = position.claimable[token];
            uint256 amount = stored + _checkpointReward(pid, position, token, position.principal);
            if (stored != 0) position.claimable[token] = 0;
            amounts[i] = amount;
            if (amount == 0) continue;
            _rewardTokenReserves[token] -= amount;
            IERC20(token).safeTransfer(receiver, amount);
        }
    }

    /// @notice Owner-supplied tokens can be explicitly reserved rather than redistributed.
    function reserveOwnerRewardTokens(address token, uint256 amount) external onlyOwner nonReentrant {
        if (token == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.ZeroAmount();
        uint256 beforeBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - beforeBalance;
        _ownerRewardReserves[token] += received;
        emit OwnerRewardTokensReserved(token, received);
    }

    function releaseOwnerRewardTokens(address token, address recipient, uint256 amount)
        external onlyOwner nonReentrant
    {
        if (recipient == address(0)) revert Errors.ZeroAddress();
        _ownerRewardReserves[token] -= amount;
        IERC20(token).safeTransfer(recipient, amount);
        emit OwnerRewardTokensReleased(token, recipient, amount);
    }

    /// @notice Sweep only tokens in excess of all attributed staker and owner reserves.
    /// @dev Also permits recovery of residual gauge rewards after the PID has no stakers.
    ///      Attributed rewards remain reserved for their claimants; no gauge scans are needed.
    function sweep(address token, address recipient) external override onlyOwner nonReentrant {
        if (token == address(0) || recipient == address(0)) revert Errors.ZeroAddress();
        uint256 reserved = _rewardTokenReserves[token] + _ownerRewardReserves[token];
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < reserved) revert RewardReserveUnderfunded(token);
        uint256 surplus = balance - reserved;
        if (surplus == 0) return;
        IERC20(token).safeTransfer(recipient, surplus);
        emit UnreservedTokensSwept(token, recipient, surplus);
    }

    // ========================================================================
    // 10. Governance, delegation, and Snapshot integration
    // ========================================================================

    function delegateVotingPowerBatch(address registry, string[] calldata spaces, address delegate) external onlyOwner {
        if (spaces.length == 0) revert Errors.LengthMismatch();
        for (uint256 i; i < spaces.length; ++i) {
            _delegateVotingPower(registry, spaces[i], delegate);
        }
    }

    function approveSnapshotVoteUint32(
        string calldata from,
        string calldata space,
        uint64 timestamp,
        string calldata proposal,
        uint32 choice,
        string calldata reason,
        string calldata app,
        string calldata metadata
    ) external onlyOwner returns (bytes32 hash) {
        bytes32 spaceId = _snapshotSpaceId(space);
        bytes32 structHash = keccak256(abi.encode(
            SNAPSHOT_VOTE_UINT32_TYPEHASH,
            keccak256(bytes(from)),
            keccak256(bytes(space)),
            timestamp,
            keccak256(bytes(proposal)),
            choice,
            keccak256(bytes(reason)),
            keccak256(bytes(app)),
            keccak256(bytes(metadata))
        ));
        hash = _snapshotTypedDataHash(structHash);
        _approveSnapshotVoteHash(hash, spaceId);
    }

    function isValidSignature(bytes32 hash, bytes calldata) external view returns (bytes4) {
        return approvedSnapshotVoteHash[hash] ? ERC1271_MAGICVALUE : ERC1271_INVALID;
    }

    // ========================================================================
    // 11. Read-only views
    // ========================================================================

    /// @notice Returns queued ownership, fee and distributor changes.
    function pendingTransactions() external view override returns (PendingTransactionsView memory view_) {
        view_.pendingOwner = _pendingOwner;
        view_.ownershipTransferReadyAt = ownershipTransferReadyAt;
        view_.pendingRewardDistributor = pendingRewardDistributor;
        view_.rewardDistributorReadyAt = pendingRewardDistributorReadyAt;
        // Fee configuration is infrequent; scan the existing pool registry instead of
        // maintaining a second persistent registry of pending PID indices.
        uint256 length = pools.length;
        uint256 count;
        for (uint256 pid; pid < length; ++pid) {
            if (pendingPoolFeeConfig[pid].readyAt != 0) ++count;
        }
        view_.feeChanges = new PendingFeeView[](count);
        uint256 next;
        for (uint256 pid; pid < length; ++pid) {
            PendingFeeConfig storage pending = pendingPoolFeeConfig[pid];
            if (pending.readyAt == 0) continue;
            view_.feeChanges[next++] = PendingFeeView({
                pid: pid,
                platformFeeBps: pending.config.platformFeeBps,
                platformFeeRecipient: pending.config.platformFeeRecipient,
                readyAt: pending.readyAt
            });
        }
    }

    function approvedDepositors(uint256 pid) external view returns (address[] memory) {
        _pool(pid);
        return poolDepositorAllowlist[pid];
    }

    function isApprovedDepositor(uint256 pid, address account) public view returns (bool) {
        _pool(pid);
        return depositorIndexPlusOne[pid][account] != 0;
    }

    /// @notice Enumerate the currently approved locker reward tokens and their PIDs.
    function approvedLockerRewardTokens() external view returns (address[] memory tokens, uint256[] memory pids) {
        uint256 count;
        for (uint256 pid; pid < pools.length; ++pid) {
            if (approvedLockerRewardPidPlusOne[pools[pid].asset] == pid + 1) ++count;
        }
        tokens = new address[](count);
        pids = new uint256[](count);
        uint256 next;
        for (uint256 pid; pid < pools.length; ++pid) {
            address token = pools[pid].asset;
            if (approvedLockerRewardPidPlusOne[token] != pid + 1) continue;
            tokens[next] = token;
            pids[next++] = pid;
        }
    }

    function tokenReserves(address token) external view returns (uint256 stakerReserved, uint256 ownerReserved) {
        return (_rewardTokenReserves[token], _ownerRewardReserves[token]);
    }

    /// @notice Returns deployment, timelock, integration addresses, delegated boost and pool count.
    function systemInfo() external view override returns (SystemView memory view_) {
        view_.deployedAt = deployedAt;
        view_.configChangeDelay = CONFIG_CHANGE_DELAY;
        view_.vlBoost = vlBoost;
        view_.rewardDistributor = rewardDistributor;
        view_.poolCount = pools.length;
        address registry = vlBoost;
        if (registry == address(0)) return view_;
        try IvlBoost(registry).delegatedIn(address(this)) returns (uint256 delegated) {
            view_.vlsdtDelegated = delegated;
        } catch {
            view_.vlsdtDelegated = 0;
        }
    }

    /// @notice Returns the pool, depositor, fees, retained stake and reward indexes.
    /// @dev Reward indexes follow the order of rewardTokens; this reads stored accounting only.
    function poolInfo(uint256 pid) external view override returns (PoolView memory view_) {
        Pool storage pool = _pool(pid);
        FeeConfig storage fees = poolFeeConfig[pid];
        view_.asset = pool.asset;
        view_.gauge = pool.gauge;
        view_.active = pool.active;
        view_.totalStaked = pool.totalStaked;
        view_.rewardTokens = pool.rewardTokens;
        view_.depositor = _primaryDepositor(pid);
        view_.depositorLocked = poolDepositorLocked[pid];
        view_.checkpointSelector = poolCheckpointSelector[pid];
        view_.platformFeeBps = fees.platformFeeBps;
        view_.platformFeeRecipient = fees.platformFeeRecipient;
        view_.feeConfigSet = poolFeeConfigSet[pid];
        uint256 length = pool.rewardTokens.length;
        view_.accRewardPerShare = new uint256[](length);
        for (uint256 i; i < length; ++i) {
            view_.accRewardPerShare[i] = accRewardPerShare[pid][pool.rewardTokens[i]];
        }
    }

    /// @notice Returns principal, depositor approval and accrued rewards for an account.
    /// @dev Approval means the account appears in this PID's allowlist; activity is in poolInfo.
    function positionInfo(uint256 pid, address account)
        external
        view
        virtual
        override
        returns (PositionView memory view_)
    {
        Pool storage pool = _pool(pid);
        Position storage position = positions[pid][account];
        view_.principal = position.principal;
        view_.approved = depositorIndexPlusOne[pid][account] != 0;
        view_.rewardTokens = pool.rewardTokens;
        view_.pendingRewards = new uint256[](pool.rewardTokens.length);
        for (uint256 i; i < pool.rewardTokens.length; ++i) {
            address token = pool.rewardTokens[i];
            uint256 accumulated = position.principal * accRewardPerShare[pid][token] / ACC_PRECISION;
            uint256 pending = accumulated > position.rewardDebt[token] ? accumulated - position.rewardDebt[token] : 0;
            view_.pendingRewards[i] = position.claimable[token] + pending;
        }
    }

    // ========================================================================
    // 12a. Internal ownership, configuration, and pool administration
    // ========================================================================

    function _queuedTransactionReadyAt() internal view returns (uint256) {
        if (block.timestamp < deployedAt + INITIAL_CONFIG_WINDOW) return block.timestamp;
        return block.timestamp + CONFIG_CHANGE_DELAY;
    }

    function _transferOwnership(address newOwner) internal override {
        delete _pendingOwner;
        delete ownershipTransferReadyAt;
        super._transferOwnership(newOwner);
    }

    function _applyPoolFees(uint256 pid) internal {
        _pool(pid);
        PendingFeeConfig memory pending = pendingPoolFeeConfig[pid];
        if (pending.readyAt == 0) revert NoPendingChange();
        if (block.timestamp < pending.readyAt) revert TimelockNotReady();
        poolFeeConfig[pid] = pending.config;
        poolFeeConfigSet[pid] = true;
        delete pendingPoolFeeConfig[pid];
        emit PoolFeesSet(
            pid,
            pending.config.platformFeeBps,
            pending.config.platformFeeRecipient
        );
    }

    function _setPoolDepositor(uint256 pid, address depositor, bool lockDepositor) internal {
        _setPoolDepositorApproval(pid, depositor, true);
        if (lockDepositor && !poolDepositorLocked[pid]) {
            poolDepositorLocked[pid] = true;
            emit PoolDepositorAllowlistLocked(pid);
        }
    }

    function _setPoolDepositorApproval(uint256 pid, address depositor, bool approved) internal {
        _pool(pid);
        if (depositor == address(0)) revert Errors.ZeroAddress();
        uint256 indexPlusOne = depositorIndexPlusOne[pid][depositor];
        if ((indexPlusOne != 0) == approved) return;
        if (poolDepositorLocked[pid]) revert Errors.AlreadySet();
        address[] storage list = poolDepositorAllowlist[pid];
        if (approved) {
            depositorIndexPlusOne[pid][depositor] = list.length + 1;
            list.push(depositor);
        } else {
            uint256 index = indexPlusOne - 1;
            address moved = list[list.length - 1];
            list[index] = moved;
            depositorIndexPlusOne[pid][moved] = index + 1;
            list.pop();
            delete depositorIndexPlusOne[pid][depositor];
        }
        emit PoolDepositorApproval(pid, depositor, approved);
    }

    function _feeConfigIsCurrentOrQueued(uint256 pid, FeeConfig memory config) internal view returns (bool) {
        PendingFeeConfig storage pending = pendingPoolFeeConfig[pid];
        if (pending.readyAt != 0) {
            return pending.config.platformFeeBps == config.platformFeeBps
                && pending.config.platformFeeRecipient == config.platformFeeRecipient;
        }
        FeeConfig storage current = poolFeeConfig[pid];
        return poolFeeConfigSet[pid] && current.platformFeeBps == config.platformFeeBps
            && current.platformFeeRecipient == config.platformFeeRecipient;
    }

    function _setPoolFees(uint256 pid, FeeConfig memory config) internal {
        _pool(pid);
        _validateFeeConfig(config);
        uint256 readyAt = _queuedTransactionReadyAt();
        pendingPoolFeeConfig[pid] = PendingFeeConfig({config: config, readyAt: readyAt});
        emit PoolFeesQueued(pid, config.platformFeeBps, config.platformFeeRecipient, readyAt);
    }

    function _validateFeeConfig(FeeConfig memory config) internal pure {
        if (config.platformFeeBps > MAX_PERFORMANCE_FEE_BPS) revert Errors.InvalidFee();
        if (config.platformFeeBps > 0 && config.platformFeeRecipient == address(0)) revert Errors.ZeroAddress();
    }

    function _setPoolCheckpointSelector(uint256 pid, bytes4 selector) internal {
        _pool(pid);
        if (selector == bytes4(0)) revert Errors.ZeroSelector();
        poolCheckpointSelector[pid] = selector;
        emit PoolCheckpointSelectorSet(pid, selector);
    }

    function _primaryDepositor(uint256 pid) internal view returns (address) {
        address[] storage list = poolDepositorAllowlist[pid];
        return list.length == 0 ? address(0) : list[0];
    }

    // ========================================================================
    // 12b. Internal pool registration and reward-token discovery
    // ========================================================================

    function _addPool(address asset, address gauge, address[] calldata rewardTokens) internal returns (uint256 pid) {
        if (asset == address(0) || gauge == address(0)) revert Errors.ZeroAddress();
        if (gaugeAdded[gauge]) revert Errors.DuplicateGauge();
        if (IStakeDaoGauge(gauge).staking_token() != asset) revert Errors.InvalidGaugeAsset();
        if (rewardTokens.length > MAX_REWARD_TOKENS) revert Errors.RewardTokenLimitExceeded();
        for (uint256 i; i < rewardTokens.length; i++) {
            if (rewardTokens[i] == address(0)) revert Errors.ZeroAddress();
            for (uint256 j; j < i; j++) {
                if (rewardTokens[i] == rewardTokens[j]) revert Errors.DuplicateRewardToken();
            }
        }
        pid = pools.length;
        pools.push();
        Pool storage pool = pools[pid];
        pool.asset = asset;
        pool.gauge = gauge;
        pool.active = true;
        gaugeAdded[gauge] = true;
        for (uint256 i; i < rewardTokens.length; i++) {
            _addRewardToken(pool, pid, rewardTokens[i]);
        }
        // The deposit token is a reward of its own PID even if it was not
        // supplied in the initial list of tokens claimable from the gauge.
        if (!_isRewardToken(pool, asset)) _addRewardToken(pool, pid, asset);
        // Approve a unique locker deposit token automatically; require an explicit
        // owner choice once two PIDs stake the same token.
        bool alreadyRegistered = _lockerDepositTokens[asset];
        _lockerDepositTokens[asset] = true;
        if (!alreadyRegistered) {
            approvedLockerRewardPidPlusOne[asset] = pid + 1;
            emit ApprovedLockerRewardTokenSet(asset, pid, true);
        } else {
            delete approvedLockerRewardPidPlusOne[asset];
            emit ApprovedLockerRewardTokenSet(asset, pid, false);
        }
        IERC20(asset).forceApprove(gauge, type(uint256).max);
        emit PoolAdded(pid, asset, gauge);
    }

    function _syncGaugeRewards(uint256 pid, Pool storage pool)
        internal returns (
            address[8] memory gaugeTokens,
            uint256[8] memory resultIndices,
            uint256 gaugeCount,
            bool hasClaimable
        )
    {
        for (uint256 i; i < MAX_GAUGE_REWARD_TOKENS; ++i) {
            address token = IStakeDaoGauge(pool.gauge).reward_tokens(i);
            if (token == address(0)) break;
            uint256 index = pool.rewardTokens.length;
            for (uint256 j; j < pool.rewardTokens.length; ++j) {
                if (pool.rewardTokens[j] == token) {
                    index = j;
                    break;
                }
            }
            if (index == pool.rewardTokens.length) {
                _addRewardToken(pool, pid, token);
            }
            gaugeTokens[gaugeCount] = token;
            resultIndices[gaugeCount] = index;
            ++gaugeCount;
            if (!hasClaimable && IStakeDaoGauge(pool.gauge).claimable_reward(address(this), token) != 0) {
                hasClaimable = true;
            }
        }
    }

    function _addRewardToken(Pool storage pool, uint256 pid, address rewardToken) internal {
        if (rewardToken == address(0)) revert Errors.ZeroAddress();
        if (pool.rewardTokens.length >= MAX_REWARD_TOKENS) revert Errors.RewardTokenLimitExceeded();
        if (_isRewardToken(pool, rewardToken)) revert Errors.DuplicateRewardToken();
        pool.rewardTokens.push(rewardToken);
        if (!_rewardTokenListed[rewardToken]) {
            _rewardTokenListed[rewardToken] = true;
        }
        emit PoolRewardTokenAdded(pid, rewardToken);
    }

    function _isRewardToken(Pool storage pool, address rewardToken) internal view returns (bool) {
        for (uint256 i; i < pool.rewardTokens.length; i++) {
            if (pool.rewardTokens[i] == rewardToken) return true;
        }
        return false;
    }

    function _pool(uint256 pid) internal view returns (Pool storage pool) {
        if (pid >= pools.length) revert Errors.InvalidPool();
        pool = pools[pid];
    }

    // ========================================================================
    // 12c. Internal harvesting and reward accounting
    // ========================================================================

    /// @dev A gauge's own claim is attributed to that PID. With zero stakers, its
    ///      newly collected rewards are left as unreserved surplus for owner sweeping.
    ///      Build public harvest result arrays only when they will be returned.
    function _harvest(uint256 pid, Pool storage pool, bool returnResults)
        internal returns (address[] memory tokens, uint256[] memory amounts)
    {
        (address[8] memory gaugeTokens, uint256[8] memory resultIndices, uint256 gaugeCount, bool hasClaimable) =
            _syncGaugeRewards(pid, pool);
        if (returnResults) {
            tokens = pool.rewardTokens;
            amounts = new uint256[](tokens.length);
        }
        if (!hasClaimable) return (tokens, amounts);
        uint256[8] memory beforeBalances;
        for (uint256 i; i < gaugeCount; ++i) {
            beforeBalances[i] = IERC20(gaugeTokens[i]).balanceOf(address(this));
        }
        IStakeDaoGauge(pool.gauge).claim_rewards(address(this), address(this));
        for (uint256 i; i < gaugeCount; ++i) {
            address token = gaugeTokens[i];
            uint256 afterBalance = IERC20(token).balanceOf(address(this));
            if (afterBalance <= beforeBalances[i]) continue;
            uint256 received = afterBalance - beforeBalances[i];
            // No principal remains: owner may sweep the resulting unreserved balance.
            uint256 net = pool.totalStaked == 0 ? received : _attributeTokenToPid(pid, pool, token, received);
            if (returnResults) amounts[resultIndices[i]] = net;
        }
    }

    /// @dev A Merkle reward token matching an approved locker deposit token is
    ///      allocated only to that token's PID, never among other pools.
    function _attributeClaimedLockerReward(address token, uint256 amount) internal {
        uint256 pidPlusOne = approvedLockerRewardPidPlusOne[token];
        if (pidPlusOne == 0) {
            // An unapproved locker deposit token must not silently become owner revenue.
            if (_lockerDepositTokens[token]) revert LockerRewardNotApproved(token);
            return;
        }
        uint256 pid = pidPlusOne - 1;
        Pool storage pool = pools[pid];
        if (pool.totalStaked != 0) _attributeTokenToPid(pid, pool, token, amount);
    }

    function _attributeTokenToPid(uint256 pid, Pool storage pool, address token, uint256 gross)
        internal returns (uint256 net)
    {
        net = _chargeFees(pid, token, gross);
        _rewardTokenReserves[token] += net;
        accRewardPerShare[pid][token] += net * ACC_PRECISION / pool.totalStaked;
        emit RewardAttributed(pid, token, gross, net);
    }

    /// @dev The original accumulated-rewards-per-share/debt checkpoint is authoritative.
    ///      Set debt to post-change principal in this same traversal, preserving
    ///      rewards earned by the old principal before a deposit or withdrawal.
    function _checkpoint(uint256 pid, address strategy, uint256 newPrincipal) internal {
        Pool storage pool = _pool(pid);
        Position storage position = positions[pid][strategy];
        for (uint256 i; i < pool.rewardTokens.length; ++i) {
            address token = pool.rewardTokens[i];
            uint256 earned = _checkpointReward(pid, position, token, newPrincipal);
            if (earned != 0) position.claimable[token] += earned;
        }
    }

    /// @dev One debt calculation serves stored accrual and direct claims.
    function _checkpointReward(uint256 pid, Position storage position, address token, uint256 newPrincipal)
        internal returns (uint256 earned)
    {
        uint256 index = accRewardPerShare[pid][token];
        if (index == 0) return 0;
        uint256 debt = position.rewardDebt[token];
        uint256 oldPrincipal = position.principal;
        uint256 accumulated = oldPrincipal * index / ACC_PRECISION;
        if (accumulated > debt) earned = accumulated - debt;
        uint256 newDebt = newPrincipal == oldPrincipal ? accumulated : newPrincipal * index / ACC_PRECISION;
        if (newDebt != debt) position.rewardDebt[token] = newDebt;
    }

    function _canClaim(uint256 pid, address strategy) internal view returns (bool) {
        Pool storage pool = _pool(pid);
        Position storage position = positions[pid][strategy];
        if (depositorIndexPlusOne[pid][strategy] != 0 || position.principal > 0) return true;
        for (uint256 i; i < pool.rewardTokens.length; i++) {
            if (position.claimable[pool.rewardTokens[i]] > 0) return true;
        }
        return false;
    }

    function _chargeFees(uint256 pid, address token, uint256 amount) internal returns (uint256 net) {
        if (!poolFeeConfigSet[pid]) revert Errors.InvalidFee();
        FeeConfig memory config = poolFeeConfig[pid];
        if (amount == 0 || config.platformFeeBps == 0) return amount;
        uint256 platformFee = amount * config.platformFeeBps / FEE_DENOMINATOR;
        if (platformFee > 0) {
            if (config.platformFeeRecipient == address(this)) {
                _ownerRewardReserves[token] += platformFee;
            } else {
                IERC20(token).safeTransfer(config.platformFeeRecipient, platformFee);
            }
        }
        net = amount - platformFee;
    }

    function _checkpointGauge(address gauge, bytes4 selector) internal returns (bool) {
        (bool checkpointSuccess, bytes memory checkpointResult) =
            gauge.call(abi.encodeWithSelector(selector, address(this)));
        if (!checkpointSuccess) return false;
        if (selector != IStakeDaoGauge.user_checkpoint.selector) return true;
        if (checkpointResult.length < 32) return false;
        uint256 result;
        assembly ("memory-safe") { result := mload(add(checkpointResult, 32)) }
        return result == 1;
    }

    // ========================================================================
    // 12d. Internal Merkle and URD safety checks
    // ========================================================================

    /// @dev Merkle claim tokens must already be registered in a Hub reward registry.
    function _requireRegisteredRewardToken(address token) internal view {
        if (!_rewardTokenListed[token]) revert RewardTokenNotRegistered(token);
    }

    function _requireClaimChain(uint256 chainId) internal view {
        if (block.chainid != chainId) revert WrongClaimChain(chainId, block.chainid);
    }

    // ========================================================================
    // 12e. Internal Snapshot and delegation utilities
    // ========================================================================

    function _delegateVotingPower(address registry, string calldata space, address delegate) internal {
        if (registry == address(0) || delegate == address(0)) revert Errors.ZeroAddress();
        bytes32 spaceId = _snapshotSpaceId(space);
        ISnapshotDelegateRegistry(registry).setDelegate(spaceId, delegate);
        emit VotingPowerDelegated(registry, spaceId, space, delegate);
    }

    function _approveSnapshotVoteHash(bytes32 hash, bytes32 spaceId) internal {
        if (hash == bytes32(0)) revert ZeroSnapshotVoteHash();
        approvedSnapshotVoteHash[hash] = true;
        emit SnapshotVoteHashApproved(hash, spaceId);
    }

    function _snapshotDomainSeparator() internal pure returns (bytes32) {
        return keccak256(abi.encode(SNAPSHOT_DOMAIN_TYPEHASH, SNAPSHOT_NAME_HASH, SNAPSHOT_VERSION_HASH));
    }

    function _snapshotTypedDataHash(bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _snapshotDomainSeparator(), structHash));
    }

    function _snapshotSpaceId(string memory space) internal pure returns (bytes32 spaceId) {
        bytes memory spaceBytes = bytes(space);
        assembly {
            spaceId := mload(add(spaceBytes, 32))
        }
    }
}
