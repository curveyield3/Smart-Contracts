// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Temporary CREATE adapter for a single, atomic Ethereum Safe deployment.
/// @dev The Safe is the only caller. It preserves the original consecutive CREATE
///      strategy/vault address coupling; it does not change source vault/strategy logic.
///      The Safe must close it before the transaction finishes.
contract BoostHubSafeCreateDeployerV1 {
    address public constant SAFE = 0x47623C62f281807D615eeb4A2CEee9d97F9D3C49;
    uint256 public nextCreateNonce = 1; // EIP-161 contract nonce begins at 1
    bool public closed;

    error Unauthorized();
    error InvalidCreation();
    error UnexpectedAddress(address actual, address expected);
    error OwnershipTransferFailed();

    modifier onlySafe() {
        if (msg.sender != SAFE || closed) revert Unauthorized();
        _;
    }

    function create(bytes calldata creationCode, address expectedAddress, address newOwner)
        external onlySafe returns (address deployed)
    {
        if (creationCode.length == 0 || expectedAddress == address(0)) revert InvalidCreation();
        bytes memory code = creationCode;
        assembly { deployed := create(0, add(code, 0x20), mload(code)) }
        if (deployed != expectedAddress) revert UnexpectedAddress(deployed, expectedAddress);
        if (deployed.code.length == 0) revert InvalidCreation();
        unchecked { ++nextCreateNonce; }
        if (newOwner != address(0)) {
            (bool ok,) = deployed.call(abi.encodeWithSignature("transferOwnership(address)", newOwner));
            if (!ok) revert OwnershipTransferFailed();
        }
    }

    function close() external onlySafe {
        closed = true;
    }
}
