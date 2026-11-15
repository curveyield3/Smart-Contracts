// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Signature copied from Beefy's IBeefySwapper.sol; no factory interaction.
interface IBeefySwapperV2 {
    function swap(address fromToken, address toToken, uint256 amountIn) external returns (uint256 amountOut);
    function getAmountOut(address fromToken, address toToken, uint256 amountIn) external view returns (uint256 amountOut);
}
