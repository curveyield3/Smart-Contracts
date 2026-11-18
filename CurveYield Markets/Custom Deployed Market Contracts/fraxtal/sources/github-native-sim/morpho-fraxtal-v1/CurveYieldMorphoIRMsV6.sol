// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Morpho Blue ABI-compatible structs. The field order and widths are immutable.
struct CYMarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

struct CYMarket {
    uint128 totalSupplyAssets;
    uint128 totalSupplyShares;
    uint128 totalBorrowAssets;
    uint128 totalBorrowShares;
    uint128 lastUpdate;
    uint128 fee;
}

interface ICYIrm {
    function borrowRate(CYMarketParams memory params, CYMarket memory market) external returns (uint256);
    function borrowRateView(CYMarketParams memory params, CYMarket memory market) external view returns (uint256);
}

interface ICYMorpho {
    function accrueInterest(CYMarketParams calldata params) external;
    function market(bytes32 id) external view returns (CYMarket memory);
}

interface ICYYieldSource {
    function aprReady() external view returns (bool);
    function getAPR() external view returns (uint256);
}

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
abstract contract CurveYieldIrmBase {
    uint256 public constant WAD = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant HARD_MAX_APR = 3.65e18; // 365% simple APR; NOT compounded APY.
    uint256 public constant HARD_MAX_SPY = HARD_MAX_APR / SECONDS_PER_YEAR;
    address public immutable MORPHO;

    error NotMorpho();
    error InvalidParameter();
    error NotOwner();

    constructor(address morpho_) {
        if (morpho_ == address(0) || morpho_.code.length == 0) revert InvalidParameter();
        MORPHO = morpho_;
    }

    modifier onlyMorpho() {
        if (msg.sender != MORPHO) revert NotMorpho();
        _;
    }

    function _id(CYMarketParams memory p) internal pure returns (bytes32) {
        return keccak256(abi.encode(p));
    }

    function _requireThisIrm(CYMarketParams memory p) internal view {
        if (p.irm != address(this)) revert InvalidParameter();
    }

    function _accrueExisting(CYMarketParams memory p) internal {
        if (ICYMorpho(MORPHO).market(_id(p)).lastUpdate != 0) {
            ICYMorpho(MORPHO).accrueInterest(p);
        }
    }

    function _utilization(CYMarket memory m) internal pure returns (uint256 u) {
        if (m.totalSupplyAssets == 0) return 0;
        u = uint256(m.totalBorrowAssets) * WAD / uint256(m.totalSupplyAssets);
        if (u > WAD) u = WAD;
    }

    function _toSpy(uint256 apr) internal pure returns (uint256) {
        if (apr > HARD_MAX_APR) apr = HARD_MAX_APR;
        return apr / SECONDS_PER_YEAR;
    }

}

/// @notice V2 of the existing Fraxtal collateral-yield IRM. Existing deployed V1
/// markets are NOT modified. V2 preserves the V1 curve, yield-observation lag,
/// collateral-vault restriction, rebates and constructor ABI, while enforcing
/// borrow APR <= min(constructor cap, 365%, 5 * observed collateral APR).
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
contract CurveYieldCollateralYieldIRMV3 is CurveYieldIrmBase, ICYIrm {
    uint256 public constant MAX_MULTIPLIER = 10e18;
    uint256 public constant MAX_CONFIG_APR = 5e18;
    uint256 public constant MAX_YIELD_COST_MULTIPLIER = 5e18;

    struct Curve {
        uint256 minimumMultiplier;
        uint256 targetMultiplier;
        uint256 maximumMultiplier;
        uint256 targetUtilization;
        uint256 aprRebate;
    }

    address public owner;
    ICYYieldSource public immutable yieldVault;
    uint256 public immutable fallbackCollateralApr;
    uint256 public immutable maximumCollateralApr;
    uint256 public immutable maximumBorrowApr; // V1 constructor range; output always <= 365%

    mapping(bytes32 => Curve) public curves;
    mapping(bytes32 => bool) public configured;
    mapping(bytes32 => bool) public initialized;
    mapping(bytes32 => uint256) public cachedCollateralApr;

    event OwnershipTransferred(address indexed oldOwner, address indexed nextOwner);
    event CurveConfigured(bytes32 indexed id, uint256 minimum, uint256 target, uint256 maximum, uint256 utilization, uint256 rebate);
    event YieldObserved(bytes32 indexed id, uint256 apr);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(
        address morpho_, address owner_, address vault_,
        uint256 fallbackApr_, uint256 collateralCap_, uint256 borrowCap_
    ) CurveYieldIrmBase(morpho_) {
        if (owner_ == address(0) || vault_.code.length == 0 ||
            collateralCap_ > MAX_CONFIG_APR || fallbackApr_ > collateralCap_ ||
            borrowCap_ == 0 || borrowCap_ > MAX_CONFIG_APR) revert InvalidParameter();
        owner = owner_;
        yieldVault = ICYYieldSource(vault_);
        fallbackCollateralApr = fallbackApr_;
        maximumCollateralApr = collateralCap_;
        maximumBorrowApr = borrowCap_;
    }

    /// @notice Preserve the V1 external getter name for existing deployment tools.
    function morpho() external view returns (address) { return MORPHO; }

    function transferOwnership(address nextOwner) external onlyOwner {
        if (nextOwner == address(0)) revert InvalidParameter();
        emit OwnershipTransferred(owner, nextOwner);
        owner = nextOwner;
    }

    function setCurve(CYMarketParams memory p, Curve memory c) external onlyOwner {
        _requireThisIrm(p);
        if (p.collateralToken != address(yieldVault) ||
            c.minimumMultiplier > c.targetMultiplier ||
            c.targetMultiplier > c.maximumMultiplier ||
            c.maximumMultiplier > MAX_MULTIPLIER ||
            c.targetUtilization == 0 || c.targetUtilization >= WAD ||
            c.aprRebate > WAD) revert InvalidParameter();
        bytes32 id = _id(p);
        // Settle previous interest using the previous curve. A market created
        // without a curve may be configured if no borrowing occurred.
        CYMarket memory existing = ICYMorpho(MORPHO).market(id);
        if (existing.lastUpdate != 0) {
            if (configured[id]) ICYMorpho(MORPHO).accrueInterest(p);
            else if (existing.totalBorrowAssets != 0 || existing.totalBorrowShares != 0)
                revert InvalidParameter();
        }
        curves[id] = c;
        configured[id] = true;
        emit CurveConfigured(id, c.minimumMultiplier, c.targetMultiplier, c.maximumMultiplier, c.targetUtilization, c.aprRebate);
    }

    function borrowRate(CYMarketParams memory p, CYMarket memory m) external override onlyMorpho returns (uint256) {
        bytes32 id = _id(p);
        if (!configured[id]) revert InvalidParameter();
        uint256 apr = initialized[id] ? cachedCollateralApr[id] : _readApr();
        uint256 result = _rate(apr, curves[id], m);
        uint256 nextApr = _readApr();
        cachedCollateralApr[id] = nextApr;
        initialized[id] = true;
        emit YieldObserved(id, nextApr);
        return result;
    }

    function borrowRateView(CYMarketParams memory p, CYMarket memory m) external view override returns (uint256) {
        bytes32 id = _id(p);
        if (!configured[id]) revert InvalidParameter();
        return _rate(initialized[id] ? cachedCollateralApr[id] : _readApr(), curves[id], m);
    }

    function liveBorrowRateView(CYMarketParams memory p, CYMarket memory m) external view returns (uint256) {
        bytes32 id = _id(p);
        if (!configured[id]) revert InvalidParameter();
        return _rate(_readApr(), curves[id], m);
    }

    function effectiveMultiplier(CYMarketParams memory p, CYMarket memory m) external view returns (uint256) {
        bytes32 id = _id(p);
        if (!configured[id]) revert InvalidParameter();
        return _multiplier(curves[id], _utilization(m));
    }

    function _readApr() internal view returns (uint256 result) {
        result = fallbackCollateralApr;
        try yieldVault.aprReady() returns (bool ready) {
            if (ready) {
                try yieldVault.getAPR() returns (uint256 measured) { result = measured; } catch {}
            }
        } catch {}
        if (result > maximumCollateralApr) result = maximumCollateralApr;
    }

    function _multiplier(Curve memory c, uint256 utilization) internal pure returns (uint256) {
        if (utilization <= c.targetUtilization) {
            return c.minimumMultiplier +
                (c.targetMultiplier - c.minimumMultiplier) * utilization / c.targetUtilization;
        }
        return c.targetMultiplier +
            (c.maximumMultiplier - c.targetMultiplier) *
            (utilization - c.targetUtilization) / (WAD - c.targetUtilization);
    }

    function _rate(uint256 collateralApr, Curve memory c, CYMarket memory m) internal view returns (uint256) {
        uint256 borrowApr = collateralApr * _multiplier(c, _utilization(m)) / WAD;
        borrowApr = borrowApr > c.aprRebate ? borrowApr - c.aprRebate : 0;
        uint256 yieldCostCap = collateralApr * MAX_YIELD_COST_MULTIPLIER / WAD;
        if (borrowApr > yieldCostCap) borrowApr = yieldCostCap;
        if (borrowApr > maximumBorrowApr) borrowApr = maximumBorrowApr;
        return _toSpy(borrowApr);
    }
}

/// @notice Euler-inspired, fully configurable utilization-only borrowing curve.
/// @dev Four APR anchor rates are independently set: minimum at 0% utilization,
/// target at targetUtilization, kink at kinkUtilization, and maximum at 100%.
/// No collateral-yield inputs, vault calls, collateral oracle or yield multiplier.
/// Between 0% and target, and between target and kink, interpolate linearly.
/// Above kink use a convex curve, or a straight line if curvature is zero.
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
contract CurveYieldEulerUtilizationIRMV3 is CurveYieldIrmBase, ICYIrm {
    struct Curve {
        uint256 minimumApr;
        uint256 targetApr;
        uint256 kinkApr;
        uint256 maximumApr;
        uint256 targetUtilization;
        uint256 kinkUtilization;
        uint256 curvature;
    }

    address public owner;
    mapping(bytes32 => Curve) public curves;
    mapping(bytes32 => bool) public configured;

    event CurveConfigured(
        bytes32 indexed id,
        uint256 minimumApr,
        uint256 targetApr,
        uint256 kinkApr,
        uint256 maximumApr,
        uint256 targetUtilization,
        uint256 kinkUtilization,
        uint256 curvature
    );
    event OwnershipTransferred(address indexed oldOwner, address indexed nextOwner);

    constructor(address morpho_, address owner_) CurveYieldIrmBase(morpho_) {
        if (owner_ == address(0)) revert InvalidParameter();
        owner = owner_;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address nextOwner) external onlyOwner {
        if (nextOwner == address(0)) revert InvalidParameter();
        emit OwnershipTransferred(owner, nextOwner);
        owner = nextOwner;
    }

    /// @notice Set all four WAD-scaled annualized APR anchors, two utilization
    /// anchors, and the optional post-kink curvature for one isolated market.
    /// @dev On reconfiguration, previously accrued elapsed time uses the OLD
    /// curve. First configuration of a live market requires zero borrow debt.
    function setCurve(CYMarketParams memory p, Curve memory c) external onlyOwner {
        _requireThisIrm(p);
        if (
            c.minimumApr > c.targetApr ||
            c.targetApr > c.kinkApr ||
            c.kinkApr > c.maximumApr ||
            c.maximumApr > HARD_MAX_APR ||
            c.targetUtilization == 0 ||
            c.targetUtilization >= c.kinkUtilization ||
            c.kinkUtilization >= WAD ||
            c.curvature > 10e18
        ) revert InvalidParameter();

        bytes32 id = _id(p);
        CYMarket memory existing = ICYMorpho(MORPHO).market(id);
        if (existing.lastUpdate != 0) {
            if (configured[id]) {
                ICYMorpho(MORPHO).accrueInterest(p);
            } else if (existing.totalBorrowAssets != 0 || existing.totalBorrowShares != 0) {
                revert InvalidParameter();
            }
        }

        curves[id] = c;
        configured[id] = true;
        emit CurveConfigured(
            id, c.minimumApr, c.targetApr, c.kinkApr, c.maximumApr,
            c.targetUtilization, c.kinkUtilization, c.curvature
        );
    }

    function borrowRate(CYMarketParams memory p, CYMarket memory m)
        external view override onlyMorpho returns (uint256)
    {
        return _borrowRate(p, m);
    }

    function borrowRateView(CYMarketParams memory p, CYMarket memory m)
        external view override returns (uint256)
    {
        return _borrowRate(p, m);
    }

    /// @notice Read the APR without truncating to Morpho's per-second units.
    function borrowAprView(CYMarketParams memory p, CYMarket memory m)
        external view returns (uint256)
    {
        bytes32 id = _id(p);
        if (!configured[id]) revert InvalidParameter();
        return _apr(curves[id], _utilization(m));
    }

    function _borrowRate(CYMarketParams memory p, CYMarket memory m)
        internal view returns (uint256)
    {
        bytes32 id = _id(p);
        if (!configured[id]) revert InvalidParameter();
        return _toSpy(_apr(curves[id], _utilization(m)));
    }

    function _apr(Curve memory c, uint256 utilization) internal pure returns (uint256) {
        if (utilization <= c.targetUtilization) {
            return c.minimumApr +
                (c.targetApr - c.minimumApr) * utilization / c.targetUtilization;
        }
        if (utilization <= c.kinkUtilization) {
            return c.targetApr +
                (c.kinkApr - c.targetApr) *
                (utilization - c.targetUtilization) / (c.kinkUtilization - c.targetUtilization);
        }
        uint256 aboveKink = (utilization - c.kinkUtilization) * WAD /
            (WAD - c.kinkUtilization);
        // 0% progress at the kink and 100% progress at full utilization.
        uint256 denominator = WAD + c.curvature * (WAD - aboveKink) / WAD;
        uint256 progress = aboveKink * WAD / denominator;
        return c.kinkApr + (c.maximumApr - c.kinkApr) * progress / WAD;
    }
}

/// @title CurveYield Linear Utilization IRM V1
/// @notice A linear borrowing APR between minimum and maximum utilization.
/// @dev Exactly three owner-controlled parameters per Morpho market:
///      minimumApr (at zero utilization), maximumApr (at or above
///      maximumUtilization), and maximumUtilization itself.
///      No kink, target rate, collateral yield, or oracle dependency.
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
contract CurveYieldLinearUtilizationIRMV2 is CurveYieldIrmBase, ICYIrm {
    struct Curve {
        uint256 minimumApr;
        uint256 maximumApr;
        uint256 maximumUtilization;
    }

    address public owner;
    mapping(bytes32 => Curve) public curves;
    mapping(bytes32 => bool) public configured;

    event CurveConfigured(
        bytes32 indexed marketId,
        uint256 minimumApr,
        uint256 maximumApr,
        uint256 maximumUtilization
    );
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address morpho_, address owner_) CurveYieldIrmBase(morpho_) {
        if (owner_ == address(0)) revert InvalidParameter();
        owner = owner_;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidParameter();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Set the minimum/maximum APRs and utilization endpoint for one market.
    /// @dev Changes on initialized, configured markets accrue all previous interest
    ///      using the old curve. First-time setup on an existing market requires
    ///      no borrow assets or shares. Configuration before market creation works.
    function setCurve(CYMarketParams memory params, Curve memory curve) external onlyOwner {
        _requireThisIrm(params);
        if (
            curve.minimumApr > curve.maximumApr ||
            curve.maximumApr > HARD_MAX_APR ||
            curve.maximumUtilization == 0 ||
            curve.maximumUtilization > WAD
        ) revert InvalidParameter();

        bytes32 marketId = _id(params);
        CYMarket memory existing = ICYMorpho(MORPHO).market(marketId);
        if (existing.lastUpdate != 0) {
            if (configured[marketId]) {
                ICYMorpho(MORPHO).accrueInterest(params);
            } else if (
                existing.totalBorrowAssets != 0 || existing.totalBorrowShares != 0
            ) {
                revert InvalidParameter();
            }
        }

        curves[marketId] = curve;
        configured[marketId] = true;
        emit CurveConfigured(
            marketId, curve.minimumApr, curve.maximumApr, curve.maximumUtilization
        );
    }

    function borrowRate(CYMarketParams memory params, CYMarket memory market)
        external view override onlyMorpho returns (uint256)
    {
        return _borrowRate(params, market);
    }

    function borrowRateView(CYMarketParams memory params, CYMarket memory market)
        external view override returns (uint256)
    {
        return _borrowRate(params, market);
    }

    /// @notice Exact annualized APR in WAD, avoiding per-second truncation.
    function borrowAprView(CYMarketParams memory params, CYMarket memory market)
        external view returns (uint256)
    {
        bytes32 marketId = _id(params);
        if (!configured[marketId]) revert InvalidParameter();
        return _apr(curves[marketId], _utilization(market));
    }

    function _borrowRate(CYMarketParams memory params, CYMarket memory market)
        internal view returns (uint256)
    {
        bytes32 marketId = _id(params);
        if (!configured[marketId]) revert InvalidParameter();
        return _toSpy(_apr(curves[marketId], _utilization(market)));
    }

    function _apr(Curve memory curve, uint256 utilization)
        internal pure returns (uint256)
    {
        if (utilization >= curve.maximumUtilization) return curve.maximumApr;
        return curve.minimumApr +
            (curve.maximumApr - curve.minimumApr) *
            utilization / curve.maximumUtilization;
    }
}

/// @notice No owner, setters, storage or possible future rate changes.
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
contract CurveYieldImmutableStaticIRMV2 is CurveYieldIrmBase, ICYIrm {
    uint256 public immutable apr;
    uint256 public immutable ratePerSecond;

    constructor(address morpho_, uint256 apr_) CurveYieldIrmBase(morpho_) {
        if (apr_ > HARD_MAX_APR) revert InvalidParameter();
        apr = apr_;
        ratePerSecond = _toSpy(apr_);
    }

    function borrowRate(CYMarketParams memory, CYMarket memory) external view override onlyMorpho returns (uint256) {
        return ratePerSecond;
    }

    function borrowRateView(CYMarketParams memory, CYMarket memory) external view override returns (uint256) {
        return ratePerSecond;
    }
}

/// @title CurveYield Keeper-Governed Fixed Borrowing Rate IRM V2
/// @notice Each market has a fixed APR until owner/keeper target updates are
///         queued, timelocked, and executed as a bounded linear APR ramp.
/// @dev Constructor-fixed minimum, maximum, initial APR, allowed percentage-point
///      change per day, minimum ramp window and execution timelock.
///      All APR values are WAD-scaled annual simple interest, 1e18 = 100%.
///      Daily shift is ADDITIVE in APR percentage points, not multiplicative:
///      1% -> 25%, 100% -> 124%, or 124% -> 100% are 24-point shifts.
///      Note: a configured 7-30 day minimum shift window can make them slower.
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
contract CurveYieldGovernedStaticIRMV3 is CurveYieldIrmBase, ICYIrm {
    // 24 APR percentage points per day, equivalent to 1 point per hour.
    uint256 public constant HARD_MAX_APR_CHANGE_PER_DAY = 24e16;

    struct Ramp {
        uint256 startApr;
        uint256 targetApr;
        uint256 startTime;
        uint256 duration;
    }
    struct PendingTarget {
        uint256 targetApr;
        uint256 executableAt;
        bool active;
    }

    address public owner;
    uint256 public immutable minimumApr;
    uint256 public immutable maximumApr;
    uint256 public immutable initialApr;
    uint256 public immutable maximumAprChangePerDay;
    uint256 public immutable shiftWindow;
    uint256 public immutable timelock;
    mapping(address => bool) public keepers;
    mapping(bytes32 => Ramp) public ramps;
    mapping(bytes32 => bool) public configured;
    mapping(bytes32 => PendingTarget) public pendingTargets;

    event OwnershipTransferred(address indexed oldOwner, address indexed nextOwner);
    event KeeperUpdated(address indexed keeper, bool enabled);
    event TargetRateQueued(bytes32 indexed marketId, uint256 targetApr, uint256 executableAt);
    event TargetRateCancelled(bytes32 indexed marketId);
    event TargetRateActivated(bytes32 indexed marketId, uint256 startApr, uint256 targetApr, uint256 startTime, uint256 duration);

    error NotOwnerOrKeeper();
    error NoPendingTarget();
    error TimelockNotElapsed();

    constructor(
        address morpho_,
        address owner_,
        uint256 minimumApr_,
        uint256 maximumApr_,
        uint256 initialApr_,
        uint256 maximumAprChangePerDay_,
        uint256 shiftWindowDays_,
        uint256 timelockDays_
    ) CurveYieldIrmBase(morpho_) {
        if (
            owner_ == address(0) ||
            minimumApr_ > initialApr_ ||
            initialApr_ > maximumApr_ ||
            maximumApr_ > HARD_MAX_APR ||
            maximumAprChangePerDay_ == 0 ||
            maximumAprChangePerDay_ > HARD_MAX_APR_CHANGE_PER_DAY ||
            shiftWindowDays_ < 7 || shiftWindowDays_ > 30 ||
            timelockDays_ < 1 || timelockDays_ > 30
        ) revert InvalidParameter();
        owner = owner_;
        minimumApr = minimumApr_;
        maximumApr = maximumApr_;
        initialApr = initialApr_;
        maximumAprChangePerDay = maximumAprChangePerDay_;
        shiftWindow = shiftWindowDays_ * 1 days;
        timelock = timelockDays_ * 1 days;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOwnerOrKeeper() {
        if (msg.sender != owner && !keepers[msg.sender]) revert NotOwnerOrKeeper();
        _;
    }

    function transferOwnership(address nextOwner) external onlyOwner {
        if (nextOwner == address(0)) revert InvalidParameter();
        emit OwnershipTransferred(owner, nextOwner);
        owner = nextOwner;
    }

    /// @notice Owner grants a keeper with true, revokes with false.
    ///         Keepers can queue and activate APR changes, but cannot change
    ///         keeper permissions or ownership.
    function setKeeper(address keeper, bool enabled) external onlyOwner {
        if (keeper == address(0)) revert InvalidParameter();
        keepers[keeper] = enabled;
        emit KeeperUpdated(keeper, enabled);
    }

    /// @notice Queue a new target APR. Replacing an existing pending target
    ///         always restarts the entire timelock; nothing changes yet.
    /// @dev Both owner and current keepers may schedule changes. Applying them
    ///      after the timelock requires a separate on-chain transaction.
    function setTargetRate(CYMarketParams memory p, uint256 targetApr_)
        external onlyOwnerOrKeeper
    {
        _requireThisIrm(p);
        if (targetApr_ < minimumApr || targetApr_ > maximumApr)
            revert InvalidParameter();
        bytes32 id = _id(p);
        uint256 executableAt = block.timestamp + timelock;
        pendingTargets[id] = PendingTarget(targetApr_, executableAt, true);
        emit TargetRateQueued(id, targetApr_, executableAt);
    }

    /// @notice Owner can discard a pending change before or after it matures.
    function cancelTargetRate(CYMarketParams memory p) external onlyOwner {
        _requireThisIrm(p);
        bytes32 id = _id(p);
        if (!pendingTargets[id].active) revert NoPendingTarget();
        delete pendingTargets[id];
        emit TargetRateCancelled(id);
    }

    /// @notice Activate the queued target after the immutable 1-30 day timelock.
    /// @dev Previously accrued interest uses the OLD APR schedule, then the new
    ///      schedule starts at the current rate without an instantaneous jump.
    ///      Every change ramps over AT LEAST 7-30 days (constructor window).
    ///      If the daily-point ceiling requires more time, that longer duration
    ///      is used. An owner/keeper cannot bypass either bound.
    function executeTargetRate(CYMarketParams memory p)
        external onlyOwnerOrKeeper
    {
        _requireThisIrm(p);
        bytes32 id = _id(p);
        PendingTarget memory pending = pendingTargets[id];
        if (!pending.active) revert NoPendingTarget();
        if (block.timestamp < pending.executableAt) revert TimelockNotElapsed();

        _accrueExisting(p);
        uint256 startApr = _current(_ramp(id), block.timestamp);
        uint256 delta = startApr > pending.targetApr
            ? startApr - pending.targetApr
            : pending.targetApr - startApr;

        uint256 minimumDuration = delta == 0 ? 0 : shiftWindow;
        // Ceil(delta * oneDay / maxDailyShift), in WAD APR percentage points.
        // Configurable maxDailyShift may be 0.1%, 1%, 2%, ... up to 24% points.
        uint256 byDailyLimit = delta == 0
            ? 0
            : (delta * 1 days + maximumAprChangePerDay - 1) / maximumAprChangePerDay;
        uint256 duration = minimumDuration >= byDailyLimit ? minimumDuration : byDailyLimit;

        ramps[id] = Ramp(startApr, pending.targetApr, block.timestamp, duration);
        configured[id] = true;
        delete pendingTargets[id];
        emit TargetRateActivated(id, startApr, pending.targetApr, block.timestamp, duration);
    }

    /// @notice Current instantaneous annual borrow APR (WAD, not SPY).
    function currentApr(CYMarketParams memory p) external view returns (uint256) {
        return _current(_ramp(_id(p)), block.timestamp);
    }

    function borrowRate(CYMarketParams memory p, CYMarket memory m)
        external view override onlyMorpho returns (uint256)
    {
        return _borrowRate(p, m);
    }

    function borrowRateView(CYMarketParams memory p, CYMarket memory m)
        external view override returns (uint256)
    {
        return _borrowRate(p, m);
    }

    function _borrowRate(CYMarketParams memory p, CYMarket memory m)
        internal view returns (uint256)
    {
        Ramp memory r = _ramp(_id(p));
        uint256 from = uint256(m.lastUpdate);
        uint256 now_ = block.timestamp;
        if (from == 0 || from >= now_) return _toSpy(_current(r, now_));

        // Average the APR across the exact interval. Necessary because Morpho
        // applies this returned rate to the entire interval since last accrual.
        uint256 area = _integral(r, now_) - _integral(r, from);
        return _toSpy(area / (now_ - from));
    }

    function _ramp(bytes32 id) internal view returns (Ramp memory r) {
        if (configured[id]) return ramps[id];
        return Ramp(initialApr, initialApr, 0, 0);
    }

    function _current(Ramp memory r, uint256 at) internal pure returns (uint256) {
        if (at <= r.startTime) return r.startApr;
        if (r.duration == 0 || at - r.startTime >= r.duration) return r.targetApr;
        uint256 delta = r.startApr > r.targetApr
            ? r.startApr - r.targetApr : r.targetApr - r.startApr;
        uint256 part = delta * (at - r.startTime) / r.duration;
        return r.targetApr >= r.startApr ? r.startApr + part : r.startApr - part;
    }

    /// @dev Integral of APR-WAD from timestamp zero through 'at'.
    ///      When a pending change is executed, Morpho accrues its previous
    ///      schedule FIRST, so no unaccrued period overlaps overwritten ramps.
    function _integral(Ramp memory r, uint256 at) internal pure returns (uint256) {
        if (at <= r.startTime) return at * r.startApr;
        uint256 elapsed = at - r.startTime;
        uint256 base = r.startTime * r.startApr;
        if (r.duration == 0) return base + elapsed * r.targetApr;
        if (elapsed >= r.duration) {
            uint256 rampArea = r.duration * (r.startApr + r.targetApr) / 2;
            return base + rampArea + (elapsed - r.duration) * r.targetApr;
        }
        uint256 delta = r.startApr > r.targetApr
            ? r.startApr - r.targetApr : r.targetApr - r.startApr;
        uint256 triangular = delta * elapsed * elapsed / (2 * r.duration);
        uint256 rectangular = elapsed * r.startApr;
        return r.targetApr >= r.startApr
            ? base + rectangular + triangular
            : base + rectangular - triangular;
    }
}
