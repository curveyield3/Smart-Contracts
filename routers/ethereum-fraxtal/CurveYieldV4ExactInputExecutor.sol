// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IOmniV4Token {
    function balanceOf(address holder) external view returns(uint256);
}

interface IOmniV4PoolManager {
    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }
    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }
    function unlock(bytes calldata data) external returns(bytes memory);
    function swap(PoolKey calldata key,SwapParams calldata params,bytes calldata hookData) external returns(int256);
    function sync(address currency) external;
    function settle() external payable returns(uint256);
    function take(address currency,address recipient,uint256 amount) external;
}

/**
 * @title CurveYieldV4ExactInputExecutor
 * @notice Single-hop v4 PoolManager adapter for the CurveYieldOmniRouter ABI pathway.
 * @dev The route's poolAddress is THIS EXECUTOR; the v4 pool is a PoolKey inside ABI args.
 *      Only ERC20<->ERC20 swaps are supported (wrap native ETH before calling).
 *      The external omni router independently validates the historical price and actual output.
 *      Hook-provided execution data is passed unchanged; custom hooks require independent review.
 */
contract CurveYieldV4ExactInputExecutor {
    uint160 private constant MIN_SQRT_PRICE = 4295128739;
    uint160 private constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;

    IOmniV4PoolManager public immutable poolManager;
    address public immutable router;
    uint256 private active;

    constructor(address router_, address manager_) {
        require(block.chainid==1 || block.chainid==252,"WRONG_CHAIN");
        require(router_!=address(0) && router_.code.length>0,"ROUTER_REQUIRED");
        require(manager_!=address(0) && manager_.code.length>0,"MANAGER_REQUIRED");
        router=router_;
        poolManager=IOmniV4PoolManager(manager_);
    }

    // The input tokens are pulled from the router; output tokens go directly back to the router.
    function executeSwap(
        address tokenIn,address tokenOut,uint256 amountIn,uint256 minimum,
        IOmniV4PoolManager.PoolKey calldata key,bytes calldata hookData
    ) external returns(uint256 amountOut){
        require(msg.sender==router,"ONLY_ROUTER");
        require(active==0,"REENTRANCY");
        require(tokenIn!=address(0)&&tokenOut!=address(0)&&tokenIn!=tokenOut,"BAD_TOKENS");
        require(amountIn>0&&amountIn<=uint256(type(int128).max),"INVALID_INPUT");
        require(key.currency0!=address(0) && key.currency1!=address(0) && key.currency0<key.currency1,"BAD_POOL_KEY");
        require((tokenIn==key.currency0 && tokenOut==key.currency1) ||
                (tokenIn==key.currency1 && tokenOut==key.currency0),"KEY_MISMATCH");
        require(hookData.length<=1024,"HOOK_DATA_TOO_LONG");
        uint256 beforeIn=IOmniV4Token(tokenIn).balanceOf(address(this));
        uint256 beforeOut=IOmniV4Token(tokenOut).balanceOf(router);
        _safeTransferFrom(tokenIn,router,address(this),amountIn);
        require(IOmniV4Token(tokenIn).balanceOf(address(this))==beforeIn+amountIn,"NONSTANDARD_INPUT");
        active=1;
        poolManager.unlock(abi.encode(key,tokenIn,tokenOut,amountIn,hookData));
        active=0;
        uint256 afterOut=IOmniV4Token(tokenOut).balanceOf(router);
        require(afterOut>=beforeOut,"OUTPUT_DECREASED");
        amountOut=afterOut-beforeOut;
        require(amountOut>=minimum,"V4_SLIPPAGE");
        uint256 remainder=IOmniV4Token(tokenIn).balanceOf(address(this))-beforeIn;
        if(remainder!=0) _safeTransfer(tokenIn,router,remainder);
        require(IOmniV4Token(tokenIn).balanceOf(address(this))==beforeIn,"UNSETTLED_INPUT");
    }

    function unlockCallback(bytes calldata data) external returns(bytes memory){
        require(msg.sender==address(poolManager) && active==1,"INVALID_CALLBACK");
        (
            IOmniV4PoolManager.PoolKey memory key,
            address tokenIn,address tokenOut,uint256 amountIn,
            bytes memory hookData
        )=abi.decode(data,(IOmniV4PoolManager.PoolKey,address,address,uint256,bytes));
        bool zeroForOne=tokenIn==key.currency0;
        IOmniV4PoolManager.SwapParams memory params=IOmniV4PoolManager.SwapParams({
            zeroForOne:zeroForOne,
            amountSpecified:-int256(amountIn),
            sqrtPriceLimitX96:zeroForOne ? MIN_SQRT_PRICE+1 : MAX_SQRT_PRICE-1
        });
        int256 packedDelta=poolManager.swap(key,params,hookData);
        int128 amount0=int128(packedDelta>>128);
        int128 amount1=int128(packedDelta);
        int128 inputDelta=zeroForOne ? amount0 : amount1;
        int128 outputDelta=zeroForOne ? amount1 : amount0;
        require(inputDelta<0 && outputDelta>0,"UNEXPECTED_V4_DELTA");
        uint256 owed=uint256(-int256(inputDelta));
        uint256 toReceive=uint256(int256(outputDelta));
        require(owed<=amountIn,"OVERSPEND");
        poolManager.sync(tokenIn);
        _safeTransfer(tokenIn,address(poolManager),owed);
        require(poolManager.settle()==owed,"SETTLEMENT_MISMATCH");
        poolManager.take(tokenOut,router,toReceive);
        return abi.encode(toReceive);
    }

    function _safeTransfer(address token,address to,uint256 value) private {
        (bool ok,bytes memory ret)=token.call(abi.encodeWithSelector(0xa9059cbb,to,value));
        require(ok && (ret.length==0||(ret.length>=32&&abi.decode(ret,(bool)))),"TRANSFER_FAILED");
    }
    function _safeTransferFrom(address token,address from,address to,uint256 value) private {
        (bool ok,bytes memory ret)=token.call(abi.encodeWithSelector(0x23b872dd,from,to,value));
        require(ok && (ret.length==0||(ret.length>=32&&abi.decode(ret,(bool)))),"TRANSFER_FROM_FAILED");
    }
}
