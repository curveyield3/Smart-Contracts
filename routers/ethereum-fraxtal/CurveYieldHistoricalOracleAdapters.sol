// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {RouterFullMath} from "./CurveYieldOmniRouter.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

interface IHistoricalERC20 {
    function decimals() external view returns(uint8);
}
interface IHistoricalV2Pair {
    function token0() external view returns(address);
    function token1() external view returns(address);
    function price0CumulativeLast() external view returns(uint256);
    function price1CumulativeLast() external view returns(uint256);
    function getReserves() external view returns(uint112,uint112,uint32);
}
interface IHistoricalV3Pool {
    function token0() external view returns(address);
    function token1() external view returns(address);
    function observe(uint32[] calldata secondsAgos)
        external view returns(int56[] memory tickCumulatives,uint160[] memory secondsPerLiquidityCumulativeX128s);
}

/**
 * @notice Counterfactual cumulative Uniswap V2 prices, using permissionless historical checkpoints.
 * @dev quoteRate(pair,tokenIn,tokenOut) outputs an oracle rate scaled by 1e18,
 *      suitable for the omni router's oracleRateDecimals=18.
 *      A pair MUST be checkpointed and its observation must be 15 minutes to 1 day old.
 */
contract CurveYieldV2CumulativeOracle {
    uint32 public constant MIN_WINDOW = 900;
    uint32 public constant MAX_OBSERVATION_AGE = 86400;
    struct Observation {
        uint256 cumulative0;
        uint256 cumulative1;
        uint32 timestamp;
    }
    mapping(address => Observation[2]) public observations;

    event PairCheckpointed(address indexed pair,uint32 timestamp);

    function checkpoint(address pair) external {
        require(pair.code.length != 0,"NO_PAIR");
        (uint256 c0,uint256 c1,uint32 nowTs)=_cumulative(pair);
        Observation[2] storage s=observations[pair];
        require(s[1].timestamp==0 || uint32(nowTs - s[1].timestamp)>=MIN_WINDOW,"CHECKPOINT_TOO_SOON");
        s[0]=s[1];
        s[1]=Observation(c0,c1,nowTs);
        emit PairCheckpointed(pair,nowTs);
    }

    function quoteRate(address pair,address tokenIn,address tokenOut)
        external view returns(uint256 rateScaled1e18)
    {
        IHistoricalV2Pair p=IHistoricalV2Pair(pair);
        address t0=p.token0(); address t1=p.token1();
        require((tokenIn==t0&&tokenOut==t1)||(tokenIn==t1&&tokenOut==t0),"PAIR_MISMATCH");
        (uint256 nowC0,uint256 nowC1,uint32 nowTs)=_cumulative(pair);
        Observation storage obs=observations[pair][1];
        uint32 age;
        unchecked{age=nowTs-obs.timestamp;}
        if(obs.timestamp==0 || age<MIN_WINDOW){
            obs=observations[pair][0];
            unchecked{age=nowTs-obs.timestamp;}
        }
        require(obs.timestamp!=0 && age>=MIN_WINDOW && age<=MAX_OBSERVATION_AGE,"TWAP_NOT_READY");
        uint256 cumulativeDelta;
        unchecked{
            cumulativeDelta=tokenIn==t0 ? nowC0-obs.cumulative0 : nowC1-obs.cumulative1;
        }
        uint256 averageQ112=cumulativeDelta/age;
        uint8 decimalsIn=IHistoricalERC20(tokenIn).decimals();
        uint8 decimalsOut=IHistoricalERC20(tokenOut).decimals();
        require(decimalsIn<=18 && decimalsOut<=18,"DECIMALS_GT_18");
        // V2 cumulative prices are encoded in raw token units, Q112.
        rateScaled1e18=RouterFullMath.mulDiv(
            averageQ112, (10**uint256(decimalsIn))*1e18,
            (uint256(1)<<112)*(10**uint256(decimalsOut))
        );
        require(rateScaled1e18>0,"ZERO_RATE");
    }

    function _cumulative(address pair) internal view returns(uint256 c0,uint256 c1,uint32 nowTs){
        IHistoricalV2Pair p=IHistoricalV2Pair(pair);
        c0=p.price0CumulativeLast();
        c1=p.price1CumulativeLast();
        (uint112 reserve0,uint112 reserve1,uint32 lastTs)=p.getReserves();
        require(reserve0!=0&&reserve1!=0,"ZERO_RESERVE");
        nowTs=uint32(block.timestamp);
        unchecked{
            uint32 elapsed=nowTs-lastTs;
            if(elapsed!=0){
                c0+=((uint256(reserve1)<<112)/reserve0)*elapsed;
                c1+=((uint256(reserve0)<<112)/reserve1)*elapsed;
            }
        }
    }
}

/**
 * @notice Uniswap V3 time-weighted average tick converted into a normalized 1e18 rate.
 * @dev Requires a historical V3 observation window; observation cardinality must be sufficient.
 */
contract CurveYieldV3TickOracle {
    function quoteRate(address pool,address tokenIn,address tokenOut,uint32 window)
        external view returns(uint256 rateScaled1e18)
    {
        require(window>=900,"TWAP_TOO_SHORT");
        IHistoricalV3Pool p=IHistoricalV3Pool(pool);
        address token0=p.token0(); address token1=p.token1();
        require((tokenIn==token0&&tokenOut==token1)||(tokenIn==token1&&tokenOut==token0),"POOL_TOKENS");
        uint32[] memory ago=new uint32[](2);
        ago[0]=window; ago[1]=0;
        (int56[] memory cumulative,)=p.observe(ago);
        require(cumulative.length==2,"MISSING_OBSERVATION");
        int56 delta=cumulative[1]-cumulative[0];
        int56 secondsAgo=int56(uint56(window));
        int24 meanTick=int24(delta/secondsAgo);
        if(delta<0 && delta%secondsAgo!=0) meanTick--;
        uint160 sqrtPrice=TickMath.getSqrtPriceAtTick(meanTick);
        uint256 inUnit=10**uint256(IHistoricalERC20(tokenIn).decimals());
        uint256 outUnit=10**uint256(IHistoricalERC20(tokenOut).decimals());
        require(inUnit<=1e36 && outUnit<=1e36,"TOKEN_DECIMALS");
        uint256 quotedRaw;
        if(sqrtPrice<=type(uint128).max){
            uint256 ratioX192=uint256(sqrtPrice)*sqrtPrice;
            quotedRaw=tokenIn==token0
                ? RouterFullMath.mulDiv(ratioX192,inUnit,uint256(1)<<192)
                : RouterFullMath.mulDiv(uint256(1)<<192,inUnit,ratioX192);
        } else {
            uint256 ratioX128=RouterFullMath.mulDiv(sqrtPrice,sqrtPrice,uint256(1)<<64);
            quotedRaw=tokenIn==token0
                ? RouterFullMath.mulDiv(ratioX128,inUnit,uint256(1)<<128)
                : RouterFullMath.mulDiv(uint256(1)<<128,inUnit,ratioX128);
        }
        rateScaled1e18=RouterFullMath.mulDiv(quotedRaw,1e18,outUnit);
        require(rateScaled1e18>0,"ZERO_RATE");
    }
}
