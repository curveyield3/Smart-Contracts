// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Methods used by BoostHub; other vlBoost methods are not needed here.
interface IvlBoost {
    function delegatedIn(address user) external view returns (uint256);
    function checkpointUser(address user) external;
}
