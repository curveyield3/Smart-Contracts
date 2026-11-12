// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/**
 * @title CurveYield System Component
 * @notice CurveYield is a decentralized NGO building optimized DeFi systems for the good of all.
 *
 * @dev CurveYield integrates specialized AMM infrastructure, tokenized yield strategies, credit
 * markets, and protocol-owned liquidity into a unified, capital-efficient liquidity stack governed
 * by an open, international DAO community.
 *
 * Protocol operations are enhanced by cross-chain bridging and messaging, MEV capture systems,
 * off-chain to on-chain automation, and peer-to-peer data networks.
 *
 * This contract is one component of the CurveYield system.
 *
 * CurveYield uses proven DeFi primitives where possible and adds targeted coordination and
 * capital-efficiency-enhancing contracts where needed. Users and integrators must review
 * CurveYield documentation before use.
 *
 * Learn more:
 * Documentation: https://docs.curveyield.com
 * dApp: https://curveyield.online
 * GitHub: https://github.com/curveyield
 *
 * Decentralized links may have limited or delayed availability during periods of high network activity:
 * https://curveyield.eth.limo
 * https://curveyield.dao
 *
 * Note: curveyield.dao may require a Brave Browser or an Unstoppable Domains browser plugin to use.
 */

import {RouterFullMath} from "./CurveYieldOmniRouter.sol";

interface IPriceReaderERC20 {function decimals() external view returns(uint8);}
interface IPriceReaderV2Pair {
    function token0() external view returns(address);
    function token1() external view returns(address);
    function price0CumulativeLast() external view returns(uint256);
    function price1CumulativeLast() external view returns(uint256);
    function getReserves() external view returns(uint112,uint112,uint32);
}

/**
 * @dev Shared historical-rate reader for the Omni Router. V3 tick TWAP remains
 * inside the router itself. This contract stores only permissionless V2
 * cumulative observations and computes Curve's pool EMA-to-EMA cross rates.
 *
 * Both quote functions return a uint256 scaled by 1e18:
 * "whole tokenOut received per one whole tokenIn" at the historical reference price.
 * The main router still applies each hop's slippage and verifies actual balances.
 */
contract CurveYieldHistoricalPriceReader {
    uint32 public constant MIN_V2_WINDOW = 900;
    uint32 public constant MAX_V2_OBSERVATION_AGE = 86400;
    struct Observation {uint256 cumulative0;uint256 cumulative1;uint32 timestamp;}
    mapping(address => Observation[2]) public v2Observations;
    event V2Checkpoint(address indexed pool,uint32 timestamp);

    function checkpointV2(address pair) external {
        require(pair.code.length>0,"PAIR_UNDEPLOYED");
        (uint256 c0,uint256 c1,uint32 nowTs)=_cumulatives(pair);
        Observation[2] storage o=v2Observations[pair];
        uint32 age;
        unchecked {age=nowTs-o[1].timestamp;}
        require(o[1].timestamp==0||age>=MIN_V2_WINDOW,"CHECKPOINT_TOO_SOON");
        o[0]=o[1];
        o[1]=Observation(c0,c1,nowTs);
        emit V2Checkpoint(pair,nowTs);
    }

    function v2Rate(address pair,address tokenIn,address tokenOut) external view returns(uint256 rate) {
        IPriceReaderV2Pair p=IPriceReaderV2Pair(pair);
        address t0=p.token0(),t1=p.token1();
        require((tokenIn==t0&&tokenOut==t1)||(tokenIn==t1&&tokenOut==t0),"V2_TOKENS");
        (uint256 c0,uint256 c1,uint32 nowTs)=_cumulatives(pair);
        Observation storage older=v2Observations[pair][1];
        uint32 elapsed;
        unchecked {elapsed=nowTs-older.timestamp;}
        if(older.timestamp==0||elapsed<MIN_V2_WINDOW){
            older=v2Observations[pair][0];
            unchecked {elapsed=nowTs-older.timestamp;}
        }
        require(older.timestamp!=0&&elapsed>=MIN_V2_WINDOW&&
                elapsed<=MAX_V2_OBSERVATION_AGE,"V2_HISTORY_NOT_READY");
        uint256 delta;
        unchecked {delta=tokenIn==t0?c0-older.cumulative0:c1-older.cumulative1;}
        uint256 averageQ112=delta/elapsed;
        uint8 dIn=IPriceReaderERC20(tokenIn).decimals();
        uint8 dOut=IPriceReaderERC20(tokenOut).decimals();
        require(dIn<=18&&dOut<=18,"V2_DECIMALS");
        rate=RouterFullMath.mulDiv(
            averageQ112,(10**uint256(dIn))*1e18,
            (uint256(1)<<112)*(10**uint256(dOut))
        );
        require(rate>0,"V2_ZERO_RATE");
    }

    function _cumulatives(address pair) private view returns(uint256 c0,uint256 c1,uint32 nowTs) {
        IPriceReaderV2Pair p=IPriceReaderV2Pair(pair);
        c0=p.price0CumulativeLast();
        c1=p.price1CumulativeLast();
        (uint112 r0,uint112 r1,uint32 updated)=p.getReserves();
        require(r0>0&&r1>0,"V2_EMPTY");
        nowTs=uint32(block.timestamp);
        unchecked {
            uint32 elapsed=nowTs-updated;
            if(elapsed>0) {
                c0+=((uint256(r1)<<112)/uint256(r0))*elapsed;
                c1+=((uint256(r0)<<112)/uint256(r1))*elapsed;
            }
        }
    }

    /**
     * @notice Relative historical EMA rate for supported 2/3-token Curve pools.
     * @param poolType 4=TwoCryptoNG; 5=TriCryptoNG; 7=StableSwapNG.
     * @param i Pool coin index to sell; j pool coin index to buy.
     * @dev Legacy StableSwap (poolType 6) has no universal EMA and is rejected.
     *      pools with proprietary oracle/coin-index logic require explicit
     *      audited replacement oracle configuration.
     */
    function curveRate(address pool,uint16 poolType,uint8 i,uint8 j,
                       address tokenIn,address tokenOut) external view returns(uint256 rate) {
        require(poolType==4||poolType==5||poolType==7,"CURVE_EMA_UNSUPPORTED");
        require(i!=j&&i<8&&j<8,"CURVE_INDICES");
        require(_coin(pool,i)==tokenIn&&_coin(pool,j)==tokenOut,"CURVE_TOKENS");
        if(poolType==4)require(i<=1&&j<=1,"CRYPTO_TWO_COINS");
        if(poolType==5)require(i<=2&&j<=2,"TRICRYPTO_THREE_COINS");
        uint256 rateIn=i==0?1e18:_component(pool,poolType,uint256(i)-1);
        uint256 rateOut=j==0?1e18:_component(pool,poolType,uint256(j)-1);
        require(rateIn>0&&rateOut>0,"CURVE_ZERO_EMA");
        rate=RouterFullMath.mulDiv(rateIn,1e18,rateOut);
        require(rate>0,"CURVE_DUST_EMA");
    }

    function _component(address pool,uint16 poolType,uint256 index)
        private view returns(uint256 result)
    {
        bytes memory payload=poolType==4
            ?abi.encodeWithSignature("price_oracle()")
            :abi.encodeWithSignature("price_oracle(uint256)",index);
        (bool ok,bytes memory answer)=pool.staticcall(payload);
        require(ok&&answer.length>=32,"CURVE_EMA_UNAVAILABLE");
        result=abi.decode(answer,(uint256));
        require(result>0,"CURVE_EMA_ZERO");
    }

    function _coin(address pool,uint8 index) private view returns(address coin) {
        (bool ok,bytes memory answer)=pool.staticcall(
            abi.encodeWithSignature("coins(uint256)",uint256(index))
        );
        if(!ok||answer.length<32){
            (ok,answer)=pool.staticcall(
                abi.encodeWithSignature("coins(int128)",int128(uint128(index)))
            );
        }
        require(ok&&answer.length>=32,"CURVE_COINS_UNAVAILABLE");
        coin=abi.decode(answer,(address));
        require(coin!=address(0),"CURVE_BAD_COIN");
    }
}
