// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;
import {CREATE3} from "solmate/src/utils/CREATE3.sol";

/// @notice Deploys the same address across chains independently of constructor arguments.
/// @dev Chain-independent salts permit different EOA deployers/nonces on each network.
///      The first caller can consume a salt; coordinate Ethereum/Fraxtal launches to avoid salt squatting.
contract BoostHubDeploymentFactory {
    function deploy(bytes32 salt, bytes calldata creationCode) external payable returns (address) {
        return CREATE3.deploy(salt, creationCode, msg.value);
    }

    function getDeployed(address /* deployer */, bytes32 salt) external view returns (address) {
        return CREATE3.getDeployed(salt);
    }
}
