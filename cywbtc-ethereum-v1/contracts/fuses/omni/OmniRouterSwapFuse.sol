// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFuseCommon} from "../IFuseCommon.sol";

interface ICyExistingOmniRouter {
    function easyswap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut);
}

/// @notice Only approves and forwards an IPOR-authorized token swap to the EXISTING OmniRouter.
/// @dev No route selection, pricing, slippage policy, custody or second swap implementation.
contract OmniRouterSwapFuse is IFuseCommon {
    using SafeERC20 for IERC20;

    uint256 public constant MARKET_ID = 12; // IPOR universal token swapper namespace
    address public immutable ROUTER;

    constructor(address router_) {
        require(router_ != address(0), "ZERO_ADDRESS");
        ROUTER = router_;
    }

    function enter(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut) {
        IERC20(tokenIn).forceApprove(ROUTER, amountIn);
        amountOut = ICyExistingOmniRouter(ROUTER).easyswap(tokenIn, tokenOut, amountIn);
    }
}
