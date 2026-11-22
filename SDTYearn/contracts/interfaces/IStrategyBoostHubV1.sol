// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategyBoostHubV1 {
    function vault() external view returns (address);
    function want() external view returns (address);
    function deposit() external;
    function withdraw(uint256 amount) external;
    function balanceOf() external view returns (uint256);
    function lockVaultProfit(uint256 amount) external;
}
