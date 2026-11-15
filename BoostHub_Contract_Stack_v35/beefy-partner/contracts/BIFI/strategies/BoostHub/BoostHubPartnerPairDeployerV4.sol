// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../vaults/BeefyVaultV7Factory.sol";
import "../../interfaces/beefy/IStrategyV7.sol";
import "./StrategyConvexBoostHubPartnerV2.sol";
import "../Common/BaseAllToNativeFactoryStrat.sol";

/// @notice Minimal deployment helper: ONE external transaction creates and initializes
///         a Beefy V7 vault clone plus an independently deployed strategy,
///         avoiding uninitialized-proxy takeover.
/// @dev   No funds or ongoing administrative authority are held by this helper.
contract BoostHubPartnerPairDeployerV4 {
    address public immutable deployer;
    uint256 internal constant APPROVAL_DELAY = 21600;

    event PartnerPairCreated(address indexed strategy, address indexed vault, address indexed staking);

    constructor(address authorizedDeployer) {
        require(authorizedDeployer != address(0), "!deployer");
        deployer = authorizedDeployer;
    }

    function deployPair(
        address vaultFactory,
        address staking,
        address want,
        address beefyStrategyFactory,
        address omniSwapper,
        address strategist,
        address strategyOwner,
        address vaultOwner,
        string calldata vaultName,
        string calldata vaultSymbol
    ) external returns (address strategy, address vault) {
        require(msg.sender == deployer, "!deployer");
        require(vaultFactory.code.length > 0, "!vault-factory");
        require(staking.code.length > 0 && beefyStrategyFactory.code.length > 0, "!upstream");
        require(omniSwapper.code.length > 0 && want.code.length > 0, "!router-or-want");
        require(strategist != address(0) && strategyOwner != address(0) && vaultOwner != address(0), "!owner");

        BeefyVaultV7 partnerVault = BeefyVaultV7Factory(vaultFactory).cloneVault();
        vault = address(partnerVault);
        // The vault uses the existing official Beefy V7 clone factory. Our
        // independent strategy is deployed as its own implementation on both
        // chains; no Beefy beacon registration or strategy-factory clone.
        strategy = address(new StrategyConvexBoostHubPartnerV2());

        BaseAllToNativeFactoryStrat.Addresses memory config = BaseAllToNativeFactoryStrat.Addresses({
            want: want, depositToken: address(0), factory: beefyStrategyFactory,
            vault: vault, swapper: omniSwapper, strategist: strategist
        });
        address[] memory initialRewards = new address[](0);
        StrategyConvexBoostHubPartnerV2(payable(strategy)).initialize(staking, initialRewards, config);
        partnerVault.initialize(IStrategyV7(strategy), vaultName, vaultSymbol, APPROVAL_DELAY);

        require(StrategyConvexBoostHubPartnerV2(payable(strategy)).vault() == vault, "!strategy-vault");
        require(StrategyConvexBoostHubPartnerV2(payable(strategy)).want() == want, "!strategy-want");
        require(address(partnerVault.want()) == want, "!vault-want");
        require(address(partnerVault.strategy()) == strategy, "!vault-strategy");
        require(!StrategyConvexBoostHubPartnerV2(payable(strategy)).harvestOnDeposit(), "!harvest-default");

        StrategyConvexBoostHubPartnerV2(payable(strategy)).transferOwnership(strategyOwner);
        partnerVault.transferOwnership(vaultOwner);
        emit PartnerPairCreated(strategy, vault, staking);
    }
}
