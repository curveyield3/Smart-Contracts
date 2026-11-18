// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

/// @notice Only the live Morpho functions needed by this package.
interface ICurveYieldMorphoCore {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function owner() external view returns (address);
    function feeRecipient() external view returns (address);
    function createMarket(MarketParams calldata params) external;
    function setFee(MarketParams calldata params, uint256 newFee) external;
    function setFeeRecipient(address recipient) external;
    function setOwner(address newOwner) external;
    function enableIrm(address irm) external;
    function enableLltv(uint256 lltv) external;
    function accrueInterest(MarketParams calldata params) external;
    function market(bytes32 id) external view returns (
        uint128 totalSupplyAssets,
        uint128 totalSupplyShares,
        uint128 totalBorrowAssets,
        uint128 totalBorrowShares,
        uint128 lastUpdate,
        uint128 fee
    );
    function position(bytes32 id, address account)
        external view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
    function withdraw(
        MarketParams calldata params,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256 assetsWithdrawn, uint256 sharesWithdrawn);
}

/// @notice The existing Safe retains control over all owner-only Morpho operations.
///         Only setFee may additionally be called by the one-time registered splitter.
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
contract CurveYieldMorphoOwnerV3 {
    ICurveYieldMorphoCore public immutable morpho;
    address public immutable safe;
    address public splitter;
    mapping(address => bool) public approvedFactory;

    error Unauthorized();
    error InvalidAddress();
    error SplitterAlreadyConfigured();
    error WrongSplitterMorpho();

    event SplitterConfigured(address indexed splitter);
    event FactoryAuthorizationChanged(address indexed factory, bool enabled);

    modifier onlySafe() {
        if (msg.sender != safe) revert Unauthorized();
        _;
    }

    constructor(address morpho_, address safe_) {
        if (morpho_ == address(0) || safe_ == address(0)) revert InvalidAddress();
        morpho = ICurveYieldMorphoCore(morpho_);
        safe = safe_;
    }

    /// @notice One-time Safe configuration avoids circular constructor dependencies.
    function configureSplitter(address newSplitter) external onlySafe {
        if (splitter != address(0)) revert SplitterAlreadyConfigured();
        if (newSplitter.code.length == 0) revert InvalidAddress();
        if (CurveYieldMorphoFeeSplitterV3(newSplitter).morpho() != morpho) revert WrongSplitterMorpho();
        if (address(CurveYieldMorphoFeeSplitterV3(newSplitter).governance()) != address(this))
            revert WrongSplitterMorpho();
        splitter = newSplitter;
        emit SplitterConfigured(newSplitter);
    }

    /// @notice Safe may set arbitrary allowed Morpho fees; splitter may only set the
    ///         fee computed during its own atomic createMarket flow.
    function setFee(ICurveYieldMorphoCore.MarketParams calldata params, uint256 newFee) external {
        if (msg.sender != safe && (msg.sender != splitter || splitter == address(0)))
            revert Unauthorized();
        if (msg.sender == splitter && morpho.feeRecipient() != splitter) revert Unauthorized();
        morpho.setFee(params, newFee);
    }

    /// @notice Safe-controlled factory allowlist; true grants, false revokes.
    function setFactory(address factory, bool enabled) external onlySafe {
        if (factory == address(0) || (enabled && factory.code.length == 0))
            revert InvalidAddress();
        approvedFactory[factory] = enabled;
        emit FactoryAuthorizationChanged(factory, enabled);
    }

    /// @notice The Safe retains direct access; allowlisted factories may also
    ///         enable newly created IRMs without requiring a separate approval.
    function enableIrm(address irm) external {
        if (msg.sender != safe && !approvedFactory[msg.sender]) revert Unauthorized();
        morpho.enableIrm(irm);
    }

    function enableLltv(uint256 lltv) external onlySafe {
        morpho.enableLltv(lltv);
    }

    function setFeeRecipient(address recipient) external onlySafe {
        morpho.setFeeRecipient(recipient);
    }

    /// @notice Safe may transfer the underlying Morpho ownership out of this
    ///         contract at any time, including back to the Safe itself.
    function setOwner(address newOwner) external onlySafe {
        morpho.setOwner(newOwner);
    }
}

/// @notice Safe-owned fee splitter V3. Accounting and fee mechanics are unchanged;
///         the Safe can redirect its governance controller after registration.
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
contract CurveYieldMorphoFeeSplitterV3 {
    uint256 public constant WAD = 1e18;
    uint256 public constant CURVEYIELD_BASE_FEE = 0.008e18;
    uint256 public constant MAX_CREATOR_FEE = 0.22e18;
    uint256 public constant CURVEYIELD_REVENUE_SHARE = 0.10e18;
    uint256 public constant MORPHO_MAX_FEE = 0.25e18;

    ICurveYieldMorphoCore public immutable morpho;
    CurveYieldMorphoOwnerV3 public governance;
    address public immutable safe;
    address public owner;
    address public pendingOwner;
    address public treasury;

    struct CreatorMarket {
        address creator;
        address receiver;
        uint128 creatorFee;
        uint128 totalFee;
        bool active;
    }

    mapping(bytes32 => CreatorMarket) public creatorMarket;
    mapping(bytes32 => uint256) public creatorOwedShares;
    mapping(bytes32 => uint256) public treasuryOwedShares;
    uint256 private _entered;

    error Unauthorized();
    error ZeroAddress();
    error InvalidFee();
    error MorphoFeeCapExceeded(uint256 requested, uint256 maximum);
    error AlreadyExists();
    error NotRegistered();
    error FeeRoutingInactive();
    error InvalidGovernance();
    error NoClaimableShares();
    error InsufficientAssets();
    error ShareAccountingMismatch();
    error Reentrant();

    event MarketRequested(bytes32 indexed id, address indexed creator, address indexed receiver,
                          uint256 creatorFee, uint256 totalFee);
    event MarketActivated(bytes32 indexed id, uint256 totalFee);
    event FeeSharesAccounted(bytes32 indexed id, uint256 creatorShares, uint256 treasuryShares);
    event FeeSharesRedeemed(bytes32 indexed id, address indexed receiver, bool forCreator,
                            uint256 shares, uint256 assets);
    event CreatorReceiverUpdated(bytes32 indexed id, address indexed receiver);
    event TreasuryUpdated(address indexed treasury);
    event GovernanceUpdated(address indexed previousGovernance, address indexed nextGovernance);
    event OwnershipTransferStarted(address indexed pendingOwner);
    event OwnershipTransferred(address indexed owner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_entered != 0) revert Reentrant();
        _entered = 1;
        _;
        _entered = 0;
    }

    constructor(address morpho_, address governance_, address owner_, address treasury_) {
        if (morpho_ == address(0) || governance_ == address(0) || owner_ == address(0)
            || treasury_ == address(0)) revert ZeroAddress();
        morpho = ICurveYieldMorphoCore(morpho_);
        CurveYieldMorphoOwnerV3 controller = CurveYieldMorphoOwnerV3(governance_);
        // Splitter administration starts at the Safe, not the controller.
        // The Safe permanently controls governance pointer changes.
        if (governance_.code.length == 0 ||
            address(controller.morpho()) != morpho_ ||
            controller.safe() != owner_) revert InvalidGovernance();
        governance = controller;
        safe = owner_;
        owner = owner_;
        treasury = treasury_;
        emit OwnershipTransferred(owner_);
        emit TreasuryUpdated(treasury_);
    }

    function feeBreakdown(uint256 creatorFee)
        public pure returns (uint256 totalFee, uint256 curveYieldFee, uint256 creatorFeeOut)
    {
        if (creatorFee > MAX_CREATOR_FEE) revert InvalidFee();
        curveYieldFee = CURVEYIELD_BASE_FEE + creatorFee * CURVEYIELD_REVENUE_SHARE / WAD;
        totalFee = creatorFee + curveYieldFee;
        if (totalFee > MORPHO_MAX_FEE) revert MorphoFeeCapExceeded(totalFee, MORPHO_MAX_FEE);
        creatorFeeOut = creatorFee;
    }

    function maxExecutableCreatorFee() external pure returns (uint256) {
        return (MORPHO_MAX_FEE - CURVEYIELD_BASE_FEE) * WAD /
               (WAD + CURVEYIELD_REVENUE_SHARE);
    }

    function marketId(ICurveYieldMorphoCore.MarketParams calldata params)
        public pure returns (bytes32)
    {
        return keccak256(abi.encode(params));
    }

    /// @notice One permissionless transaction: register creator, create market,
    ///         configure its actual Morpho fee, then activate creator accounting.
    ///         Any failed downstream operation reverts the ENTIRE market creation.
    function createMarket(
        ICurveYieldMorphoCore.MarketParams calldata params,
        address creatorReceiver,
        uint256 creatorFee
    ) external nonReentrant returns (bytes32 id) {
        if (creatorReceiver == address(0)) revert ZeroAddress();
        (uint256 totalFee,,) = feeBreakdown(creatorFee);
        if (morpho.owner() != address(governance) || morpho.feeRecipient() != address(this))
            revert FeeRoutingInactive();

        id = marketId(params);
        if (creatorMarket[id].creator != address(0)) revert AlreadyExists();

        creatorMarket[id] = CreatorMarket({
            creator: msg.sender,
            receiver: creatorReceiver,
            creatorFee: uint128(creatorFee),
            totalFee: uint128(totalFee),
            active: false
        });

        morpho.createMarket(params);
        governance.setFee(params, totalFee);
        creatorMarket[id].active = true;

        emit MarketRequested(id, msg.sender, creatorReceiver, creatorFee, totalFee);
        emit MarketActivated(id, totalFee);
    }

    function synchronize(ICurveYieldMorphoCore.MarketParams calldata params) external nonReentrant {
        bytes32 id = marketId(params);
        morpho.accrueInterest(params);
        _sync(id);
    }

    function claim(
        ICurveYieldMorphoCore.MarketParams calldata params,
        bool forCreator,
        uint256 maximumShares,
        uint256 minimumAssets
    ) external nonReentrant returns (uint256 assetsWithdrawn, uint256 sharesWithdrawn) {
        bytes32 id = marketId(params);
        morpho.accrueInterest(params);
        _sync(id);

        CreatorMarket storage cfg = creatorMarket[id];
        if (forCreator && cfg.creator == address(0)) revert NotRegistered();

        uint256 owed = forCreator ? creatorOwedShares[id] : treasuryOwedShares[id];
        sharesWithdrawn = maximumShares == 0 || maximumShares > owed ? owed : maximumShares;
        if (sharesWithdrawn == 0) revert NoClaimableShares();

        if (forCreator) creatorOwedShares[id] = owed - sharesWithdrawn;
        else treasuryOwedShares[id] = owed - sharesWithdrawn;

        address receiver = forCreator ? cfg.receiver : treasury;
        uint256 burnedShares;
        (assetsWithdrawn, burnedShares) = morpho.withdraw(
            params, 0, sharesWithdrawn, address(this), receiver
        );
        if (burnedShares != sharesWithdrawn) revert ShareAccountingMismatch();
        if (assetsWithdrawn == 0 || assetsWithdrawn < minimumAssets) revert InsufficientAssets();

        emit FeeSharesRedeemed(id, receiver, forCreator, sharesWithdrawn, assetsWithdrawn);
    }

    /// @notice The original creator or the CURRENT designated creator-fee
    ///         receiver may redirect the creator portion. The treasury is separate.
    function setCreatorReceiver(bytes32 id, address nextReceiver) external nonReentrant {
        CreatorMarket storage cfg = creatorMarket[id];
        if (cfg.creator == address(0)) revert NotRegistered();
        if (msg.sender != cfg.creator && msg.sender != cfg.receiver) revert Unauthorized();
        if (nextReceiver == address(0)) revert ZeroAddress();
        cfg.receiver = nextReceiver;
        emit CreatorReceiverUpdated(id, nextReceiver);
    }

    /// @notice Switch the fee/market controller without transferring ownership
    ///         of the splitter or altering any fee or share accounting.
    /// @dev The target may be unconfigured or already bound to this splitter.
    ///      For an unconfigured controller, Safe must first setGovernance, then
    ///      call target.configureSplitter(this), then transfer Morpho ownership.
    ///      Execute the steps atomically using a Safe batch to avoid disruption.
    function setGovernance(address nextGovernance) external {
        if (msg.sender != safe) revert Unauthorized();
        if (nextGovernance.code.length == 0) revert InvalidGovernance();
        CurveYieldMorphoOwnerV3 next = CurveYieldMorphoOwnerV3(nextGovernance);
        address registeredSplitter = next.splitter();
        if (address(next.morpho()) != address(morpho) ||
            next.safe() != safe ||
            (registeredSplitter != address(0) && registeredSplitter != address(this)))
            revert InvalidGovernance();
        address previous = address(governance);
        governance = next;
        emit GovernanceUpdated(previous, nextGovernance);
    }

    function setTreasury(address nextTreasury) external onlyOwner {
        if (nextTreasury == address(0)) revert ZeroAddress();
        treasury = nextTreasury;
        emit TreasuryUpdated(nextTreasury);
    }

    function transferOwnership(address nextOwner) external onlyOwner {
        if (nextOwner == address(0)) revert ZeroAddress();
        pendingOwner = nextOwner;
        emit OwnershipTransferStarted(nextOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert Unauthorized();
        owner = msg.sender;
        pendingOwner = address(0);
        emit OwnershipTransferred(msg.sender);
    }

    function _marketFee(bytes32 id) internal view returns (uint256 fee) {
        (,,,,, uint128 currentFee) = morpho.market(id);
        return currentFee;
    }

    function _sync(bytes32 id) internal {
        (uint256 totalShares,,) = morpho.position(id, address(this));
        uint256 accounted = creatorOwedShares[id] + treasuryOwedShares[id];
        if (totalShares < accounted) revert ShareAccountingMismatch();
        uint256 unaccounted = totalShares - accounted;
        if (unaccounted == 0) return;

        CreatorMarket storage cfg = creatorMarket[id];
        uint256 creatorNew = cfg.active && _marketFee(id) == cfg.totalFee
            ? unaccounted * uint256(cfg.creatorFee) / uint256(cfg.totalFee)
            : 0;
        creatorOwedShares[id] += creatorNew;
        treasuryOwedShares[id] += unaccounted - creatorNew;
        emit FeeSharesAccounted(id, creatorNew, unaccounted - creatorNew);
    }
}