// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurveYieldMorphoIRMsV6.sol";
import "./CurveYieldTriggerMasterIRMV3.sol";
import "./CurveYieldMorphoOwnerAndSplitterV5.sol";

/// @notice Factory V6 deploys and automatically enables direct-to-Morpho IRMs.
///         Enablement uses the production-V1-derived V3 core owner factory allowlist.
///         Owner addresses and interest parameters are explicit caller inputs.
///         For Trigger Master children use the master as morpho_ (no enable
///         call is necessary). For independent IRMs use the real Morpho core.
///         Child owner configures per-market settings after deploying.
///         Each implementation enforces its own hard 365% simple APR ceiling.

/// @notice Factory V6 directly calls the allowlisted Morpho governance V3 owner. Direct IRMs are enabled atomically after
///         creation; child IRMs (morpho_=master) never need core enablement.
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
abstract contract CurveYieldIRMFactoryBaseV6 {
    CurveYieldMorphoOwnerV3 public immutable governance;

    error InvalidGovernance();

    constructor(address governance_) {
        if (governance_.code.length == 0) revert InvalidGovernance();
        governance = CurveYieldMorphoOwnerV3(governance_);
    }

    function _enableWhenDirect(address morpho_, address irm) internal {
        if (morpho_ == address(governance.morpho())) {
            governance.enableIrm(irm);
        }
    }
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
contract CurveYieldCollateralYieldIRMFactoryV6 is CurveYieldIRMFactoryBaseV6 {
    constructor(address governance_) CurveYieldIRMFactoryBaseV6(governance_) {}

    event IrmCreated(address indexed irm, address indexed creator, address indexed morpho);

    function create(
        address morpho_,
        address owner_,
        address vault_,
        uint256 fallbackApr_,
        uint256 collateralCap_,
        uint256 borrowCap_
    ) external returns (address irm) {
        irm = address(new CurveYieldCollateralYieldIRMV3(
            morpho_, owner_, vault_, fallbackApr_, collateralCap_, borrowCap_
        ));
        _enableWhenDirect(morpho_, irm);
        emit IrmCreated(irm, msg.sender, morpho_);
    }
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
contract CurveYieldEulerUtilizationIRMFactoryV6 is CurveYieldIRMFactoryBaseV6 {
    constructor(address governance_) CurveYieldIRMFactoryBaseV6(governance_) {}

    event IrmCreated(address indexed irm, address indexed creator, address indexed morpho);

    function create(address morpho_, address owner_) external returns (address irm) {
        irm = address(new CurveYieldEulerUtilizationIRMV3(morpho_, owner_));
        _enableWhenDirect(morpho_, irm);
        emit IrmCreated(irm, msg.sender, morpho_);
    }
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
contract CurveYieldLinearUtilizationIRMFactoryV6 is CurveYieldIRMFactoryBaseV6 {
    constructor(address governance_) CurveYieldIRMFactoryBaseV6(governance_) {}

    event IrmCreated(address indexed irm, address indexed creator, address indexed morpho);

    function create(address morpho_, address owner_) external returns (address irm) {
        irm = address(new CurveYieldLinearUtilizationIRMV2(morpho_, owner_));
        _enableWhenDirect(morpho_, irm);
        emit IrmCreated(irm, msg.sender, morpho_);
    }
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
contract CurveYieldImmutableStaticIRMFactoryV6 is CurveYieldIRMFactoryBaseV6 {
    constructor(address governance_) CurveYieldIRMFactoryBaseV6(governance_) {}

    event IrmCreated(address indexed irm, address indexed creator, address indexed morpho);

    function create(address morpho_, uint256 apr_) external returns (address irm) {
        irm = address(new CurveYieldImmutableStaticIRMV2(morpho_, apr_));
        _enableWhenDirect(morpho_, irm);
        emit IrmCreated(irm, msg.sender, morpho_);
    }
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
contract CurveYieldGovernedStaticIRMFactoryV6 is CurveYieldIRMFactoryBaseV6 {
    constructor(address governance_) CurveYieldIRMFactoryBaseV6(governance_) {}

    event IrmCreated(address indexed irm, address indexed creator, address indexed morpho);

    function create(
        address morpho_,
        address owner_,
        uint256 minimumApr_,
        uint256 maximumApr_,
        uint256 initialApr_,
        uint256 maximumAprChangePerDay_,
        uint256 shiftWindowDays_,
        uint256 timelockDays_
    ) external returns (address irm) {
        irm = address(new CurveYieldGovernedStaticIRMV3(
            morpho_, owner_, minimumApr_, maximumApr_, initialApr_,
            maximumAprChangePerDay_, shiftWindowDays_, timelockDays_
        ));
        _enableWhenDirect(morpho_, irm);
        emit IrmCreated(irm, msg.sender, morpho_);
    }
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
contract CurveYieldTriggerMasterIRMFactoryV6 is CurveYieldIRMFactoryBaseV6 {
    constructor(address governance_) CurveYieldIRMFactoryBaseV6(governance_) {}

    event IrmCreated(address indexed irm, address indexed creator, address indexed morpho);

    function create(address morpho_, address owner_) external returns (address irm) {
        irm = address(new CurveYieldTriggerMasterIRMV3(morpho_, owner_));
        _enableWhenDirect(morpho_, irm);
        emit IrmCreated(irm, msg.sender, morpho_);
    }
}
