// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IFXMintWithdrawalManagerButtons {
    function initializeFulfillWithdrawRequest(address user) external;
    function finalizeFulfillWithdrawRequest() external;
}

/// @notice Exactly two permissionless forwarding buttons; no business logic or state.
contract FulfillWithdrawExecutor {
    IFXMintWithdrawalManagerButtons public immutable MANAGER;

    constructor(address manager_) {
        MANAGER = IFXMintWithdrawalManagerButtons(manager_);
    }

    function InitializeFulfillWithdrawRequest(address user) external {
        MANAGER.initializeFulfillWithdrawRequest(user);
    }

    function FinalizeFulfillWithdrawRequest() external {
        MANAGER.finalizeFulfillWithdrawRequest();
    }
}
