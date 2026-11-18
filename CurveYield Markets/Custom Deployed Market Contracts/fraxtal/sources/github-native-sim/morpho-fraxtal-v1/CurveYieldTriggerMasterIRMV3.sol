// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurveYieldMorphoIRMsV6.sol";

interface ICYMasterCompatibleSubIrm is ICYIrm {
    function MORPHO() external view returns (address);
}

/// @title CurveYield Trigger Master IRM V2
/// @notice An IRM router with at most five priority groups and five OR rules
///         per group. The first matching group selects its registered sub-IRM;
///         when no rule matches, the registered default sub-IRM is selected.
/// @dev All registered child instances MUST be deployed with MORPHO=address(this)
///      rather than the underlying Morpho address. The master is their Morpho
///      compatibility bridge and forwards their market/accrueInterest calls
///      to the real core. This lets the existing V5 suite keep its configuration
///      guards and stateful accrual behavior. Every child is configured using
///      market params with irm=child; real markets use irm=address(this).
///      A single child/profile can be used by multiple groups, and by markets
///      with separate child market IDs.
///
///      Trigger changes take effect at an accrual boundary, never retroactively:
///      borrowRate charges the PREVIOUSLY ACTIVE child for the elapsed interval,
///      then evaluates rules to select the child for the NEXT interval. The
///      permissionless sync() function accrues and updates selections, including
///      for empty markets which Morpho may skip when accruing.
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
 * dApp: https://curveyield.com & https://curveyield.org
 *
 * Decentralized links may have limited or delayed availability during periods of high network activity:
 * https://curveyield.eth.limo
 * https://curveyield.dao
 *
 * Note: curveyield.dao may require a Brave Browser or an Unstoppable Domains browser plugin to use.
 */
contract CurveYieldTriggerMasterIRMV3 is CurveYieldIrmBase, ICYIrm, ICYMorpho {
    uint256 public constant MAX_GROUPS = 5;
    uint256 public constant MAX_OR_CONDITIONS = 5;
    uint256 public constant MAX_CALLDATA_BYTES = 512;
    uint256 public constant MAX_RETURN_BYTES = 512;
    uint256 public constant MAX_READ_GAS = 200_000;
    uint256 public constant DEFAULT_READ_GAS = 80_000;

    enum Comparison {
        ExactBytes, // equality of entire raw ABI-encoded return bytes
        Equal,      // uint256 equality of a 32-byte ABI scalar
        LessThan,   // unsigned uint256 strictly <
        GreaterThan // unsigned uint256 strictly >
    }

    struct Condition {
        address reader;
        bytes callData;
        Comparison comparison;
        bytes expected;
        uint32 gasLimit; // zero selects DEFAULT_READ_GAS
    }

    struct Group {
        address subIrm;
        Condition[] anyOf; // OR: first matching condition activates this group
    }

    address public owner;

    // The real market ID has params.irm=address(this).
    mapping(bytes32 => bool) public registeredMarket;
    mapping(bytes32 => CYMarketParams) private _realParams;
    mapping(bytes32 => address) public defaultIrm;
    mapping(bytes32 => address) public activeIrm;
    mapping(bytes32 => mapping(address => bool)) public approvedProfile;
    mapping(bytes32 => Group[]) private _groups;

    // A child IRM computes its own ID with params.irm=child. Binding that
    // ID to the real market lets V5 child configuration settle interest safely.
    mapping(bytes32 => bytes32) private _realIdForChildId;
    mapping(bytes32 => bool) private _boundChildId;

    error UnauthorizedProfile();
    error MarketUnregistered();
    error ProfileNotBound();
    error AlreadyRegistered();
    error InvalidTrigger();
    error MissingReturnData();

    event OwnershipTransferred(address indexed previousOwner, address indexed nextOwner);
    event MarketRegistered(bytes32 indexed marketId, address indexed defaultProfile);
    event ProfileApproved(bytes32 indexed marketId, address indexed profile);
    event DefaultUpdated(bytes32 indexed marketId, address indexed newDefault);
    event GroupsConfigured(bytes32 indexed marketId, uint256 count);
    event ActiveIrmChanged(bytes32 indexed marketId, address indexed previous, address indexed next);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address morpho_, address owner_) CurveYieldIrmBase(morpho_) {
        if (owner_ == address(0)) revert InvalidParameter();
        owner = owner_;
    }

    function transferOwnership(address nextOwner) external onlyOwner {
        if (nextOwner == address(0)) revert InvalidParameter();
        emit OwnershipTransferred(owner, nextOwner);
        owner = nextOwner;
    }

    /// @notice Register the real Morpho market and its initial fallback model.
    /// @dev Register the market FIRST, then configure the child profile using
    ///      childParams (irm=child). This binds the child's market ID to the
    ///      actual Morpho ID before the child checks its market state.
    ///      Complete the default's configuration before market creation or
    ///      before the first live accrual.
    function registerMarket(CYMarketParams memory params, address initialDefault)
        external onlyOwner
    {
        _requireThisIrm(params);
        bytes32 realId = _id(params);
        if (registeredMarket[realId]) revert AlreadyRegistered();
        registeredMarket[realId] = true;
        _realParams[realId] = params;
        _approve(realId, params, initialDefault);
        defaultIrm[realId] = initialDefault;
        activeIrm[realId] = initialDefault;
        emit MarketRegistered(realId, initialDefault);
    }

    /// @notice Approve and bind another predeployed child from the V5 IRM suite.
    /// @dev Reuse the same profile address in any number of trigger groups.
    ///      Each child must have its immutable MORPHO pointing to this master.
    function approveProfile(CYMarketParams memory params, address child)
        external onlyOwner
    {
        bytes32 realId = _checkMarket(params);
        _approve(realId, params, child);
    }

    /// @notice Change fallback only AFTER settling any elapsed interest under
    ///         the previously active model; then reevaluate the current rules.
    function setDefault(CYMarketParams memory params, address child)
        external onlyOwner
    {
        bytes32 realId = _checkMarket(params);
        _requireApproved(realId, child);
        _settle(params);
        defaultIrm[realId] = child;
        emit DefaultUpdated(realId, child);
        _refresh(realId);
    }

    /// @notice Atomically replace the entire ordered stack. Up to five priority
    ///         groups, each with 1-5 OR conditions. Same child may repeat.
    /// @dev Existing interest is accrued before changing trigger eligibility.
    ///      Failing or malformed external reads count as nonmatches; the
    ///      default is always used when no condition passes.
    function configureGroups(CYMarketParams memory params, Group[] calldata newGroups)
        external onlyOwner
    {
        bytes32 realId = _checkMarket(params);
        if (newGroups.length > MAX_GROUPS) revert InvalidTrigger();
        for (uint256 i; i < newGroups.length; ++i) {
            Group calldata g = newGroups[i];
            if (g.anyOf.length == 0 || g.anyOf.length > MAX_OR_CONDITIONS)
                revert InvalidTrigger();
            _requireApproved(realId, g.subIrm);
            for (uint256 j; j < g.anyOf.length; ++j) {
                Condition calldata c = g.anyOf[j];
                if (
                    c.reader.code.length == 0 ||
                    c.callData.length < 4 ||
                    c.callData.length > MAX_CALLDATA_BYTES ||
                    c.expected.length == 0 ||
                    c.expected.length > MAX_RETURN_BYTES ||
                    (c.gasLimit != 0 && (c.gasLimit < 25_000 || c.gasLimit > MAX_READ_GAS)) ||
                    (c.comparison != Comparison.ExactBytes && c.expected.length != 32)
                ) revert InvalidTrigger();
            }
        }

        _settle(params);
        delete _groups[realId];
        for (uint256 i; i < newGroups.length; ++i) {
            _groups[realId].push();
            Group storage group = _groups[realId][_groups[realId].length - 1];
            group.subIrm = newGroups[i].subIrm;
            for (uint256 j; j < newGroups[i].anyOf.length; ++j) {
                group.anyOf.push(newGroups[i].anyOf[j]);
            }
        }
        emit GroupsConfigured(realId, newGroups.length);
        _refresh(realId);
    }

    /// @notice Permissionless current-state sync. The real Morpho market first
    ///         settles old interest at the old sub-IRM rate. Only then can a
    ///         newly matched sub-IRM become active.
    function sync(CYMarketParams memory params) external {
        bytes32 realId = _checkMarket(params);
        _settle(params);
        _refresh(realId);
    }

    /// @notice The Morpho-only accrual hook; the active child is charged for
    ///         the elapsed period, and trigger matches affect the next period.
    function borrowRate(CYMarketParams memory params, CYMarket memory marketState)
        external override onlyMorpho returns (uint256)
    {
        bytes32 realId = _checkMarket(params);
        address previous = activeIrm[realId];
        CYMarketParams memory childParams = _childParams(params, previous);
        uint256 rate = ICYIrm(previous).borrowRate(childParams, marketState);
        _refresh(realId);
        return rate > HARD_MAX_SPY ? HARD_MAX_SPY : rate;
    }

    function borrowRateView(CYMarketParams memory params, CYMarket memory marketState)
        external view override returns (uint256)
    {
        bytes32 realId = _checkMarket(params);
        address selected = activeIrm[realId];
        uint256 rate = ICYIrm(selected).borrowRateView(
            _childParams(params, selected), marketState
        );
        return rate > HARD_MAX_SPY ? HARD_MAX_SPY : rate;
    }

    /// @notice Preview the result of CURRENT trigger reads without changing
    ///         the effective rate or the currently active sub-IRM.
    function previewSelection(CYMarketParams memory params)
        external view returns (address model, uint256 groupIndex)
    {
        bytes32 realId = _checkMarket(params);
        return _select(realId);
    }

    function groupCount(CYMarketParams memory params)
        external view returns (uint256)
    {
        return _groups[_checkMarket(params)].length;
    }

    function getGroup(CYMarketParams memory params, uint256 index)
        external view returns (Group memory)
    {
        return _groups[_checkMarket(params)][index];
    }

    /// @notice Compatibility for V5 child _accrueExisting() lookups.
    function market(bytes32 childMarketId)
        external view override returns (CYMarket memory)
    {
        if (!_boundChildId[childMarketId]) revert ProfileNotBound();
        return ICYMorpho(MORPHO).market(_realIdForChildId[childMarketId]);
    }

    /// @notice Compatibility for V5 child setter accrual. Child MUST pass its
    ///         own market params so the active real model can settle safely.
    ///         A random address cannot trigger the bridge.
    function accrueInterest(CYMarketParams calldata childParams) external override {
        if (childParams.irm != msg.sender) revert UnauthorizedProfile();
        bytes32 childId = keccak256(abi.encode(childParams));
        if (!_boundChildId[childId]) revert ProfileNotBound();
        bytes32 realId = _realIdForChildId[childId];
        if (!approvedProfile[realId][msg.sender]) revert UnauthorizedProfile();
        ICYMorpho(MORPHO).accrueInterest(_realParams[realId]);
    }

    /// @dev Morpho reverts when asked to accrue a market not yet created.
    ///      Pre-create setup must therefore skip accrual until lastUpdate is set.
    function _settle(CYMarketParams memory params) internal {
        if (ICYMorpho(MORPHO).market(_id(params)).lastUpdate != 0) {
            ICYMorpho(MORPHO).accrueInterest(params);
        }
    }

    function _checkMarket(CYMarketParams memory params)
        internal view returns (bytes32 realId)
    {
        _requireThisIrm(params);
        realId = _id(params);
        if (!registeredMarket[realId]) revert MarketUnregistered();
    }

    function _approve(bytes32 realId, CYMarketParams memory realParams, address child)
        internal
    {
        if (child == address(0) || child.code.length == 0) revert InvalidParameter();
        // V5 children check msg.sender == their immutable MORPHO. They must
        // point to this router, not the underlying Morpho core.
        try ICYMasterCompatibleSubIrm(child).MORPHO() returns (address configuredMorpho) {
            if (configuredMorpho != address(this)) revert InvalidParameter();
        } catch {
            revert InvalidParameter();
        }
        CYMarketParams memory childP = _childParams(realParams, child);
        bytes32 childId = _id(childP);
        if (_boundChildId[childId] && _realIdForChildId[childId] != realId)
            revert InvalidParameter();
        _boundChildId[childId] = true;
        _realIdForChildId[childId] = realId;
        approvedProfile[realId][child] = true;
        emit ProfileApproved(realId, child);
    }

    function _requireApproved(bytes32 realId, address child) internal view {
        if (!approvedProfile[realId][child]) revert UnauthorizedProfile();
    }

    function _childParams(CYMarketParams memory params, address child)
        internal pure returns (CYMarketParams memory)
    {
        params.irm = child;
        return params;
    }

    function _refresh(bytes32 realId) internal {
        (address selected,) = _select(realId);
        address previous = activeIrm[realId];
        if (previous != selected) {
            activeIrm[realId] = selected;
            emit ActiveIrmChanged(realId, previous, selected);
        }
    }

    function _select(bytes32 realId)
        internal view returns (address selected, uint256 groupIndex)
    {
        Group[] storage groups = _groups[realId];
        for (uint256 i; i < groups.length; ++i) {
            for (uint256 j; j < groups[i].anyOf.length; ++j) {
                if (_match(groups[i].anyOf[j])) return (groups[i].subIrm, i);
            }
        }
        return (defaultIrm[realId], type(uint256).max);
    }

    function _match(Condition storage condition) internal view returns (bool) {
        bytes memory payload = condition.callData;
        address reader = condition.reader;
        uint256 requestedGas = condition.gasLimit == 0
            ? DEFAULT_READ_GAS : condition.gasLimit;
        bytes memory output;
        bool ok;

        // Bound both execution gas and return-data allocation. A malicious
        // reader must not force the whole Morpho accrual to copy huge returns.
        assembly {
            ok := staticcall(requestedGas, reader, add(payload, 32), mload(payload), 0, 0)
            let n := returndatasize()
            // Do not dereference an uninitialized output pointer when a
            // successful target returns zero or excessive bytes.
            ok := and(ok, and(gt(n, 0), iszero(gt(n, 512))))
            if ok {
                output := mload(0x40)
                mstore(output, n)
                returndatacopy(add(output, 32), 0, n)
                mstore(0x40, add(add(output, 32), and(add(n, 31), not(31))))
            }
        }
        if (!ok || output.length == 0) return false;

        if (condition.comparison == Comparison.ExactBytes) {
            return keccak256(output) == keccak256(condition.expected);
        }
        if (output.length != 32) return false;
        uint256 actual = abi.decode(output, (uint256));
        uint256 expected = abi.decode(condition.expected, (uint256));
        if (condition.comparison == Comparison.Equal) return actual == expected;
        if (condition.comparison == Comparison.LessThan) return actual < expected;
        return actual > expected;
    }
}
