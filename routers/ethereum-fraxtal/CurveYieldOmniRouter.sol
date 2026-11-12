// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

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
library RouterFullMath {
    // Full precision floor(a*b / denominator), adapted from the standard mulDiv identity.
    function mulDiv(uint256 a,uint256 b,uint256 denominator) internal pure returns(uint256 result) {
        require(denominator != 0,"DIV_ZERO");
        unchecked {
            uint256 p0; uint256 p1;
            assembly ("memory-safe") {
                let mm := mulmod(a,b,not(0))
                p0 := mul(a,b)
                p1 := sub(sub(mm,p0),lt(mm,p0))
            }
            if(p1 == 0) return p0 / denominator;
            require(denominator > p1,"MULDIV_OVERFLOW");
            uint256 remainder;
            assembly ("memory-safe") { remainder := mulmod(a,b,denominator) }
            assembly ("memory-safe") {
                p1 := sub(p1,gt(remainder,p0))
                p0 := sub(p0,remainder)
            }
            uint256 twos = denominator & (~denominator + 1);
            assembly ("memory-safe") {
                denominator := div(denominator,twos)
                p0 := div(p0,twos)
                twos := add(div(sub(0,twos),twos),1)
            }
            p0 |= p1 * twos;
            uint256 inverse = (3 * denominator) ^ 2;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            result = p0 * inverse;
        }
    }
}

interface IOmniERC20 {
    function balanceOf(address) external view returns(uint256);
    function decimals() external view returns(uint8);
}


interface IEmbeddedV2Pair {
    function token0() external view returns(address);
    function token1() external view returns(address);
    function getReserves() external view returns(uint112,uint112,uint32);
    function price0CumulativeLast() external view returns(uint256);
    function price1CumulativeLast() external view returns(uint256);
    function swap(uint256,uint256,address,bytes calldata) external;
}
interface IEmbeddedV3Pool {
    function token0() external view returns(address);
    function token1() external view returns(address);
    function observe(uint32[] calldata) external view returns(int56[] memory,uint160[] memory);
    function swap(address,bool,int256,uint160,bytes calldata) external returns(int256,int256);
}
interface IEmbeddedV4Manager {
    struct PoolKey {address currency0;address currency1;uint24 fee;int24 tickSpacing;address hooks;}
    struct SwapParams {bool zeroForOne;int256 amountSpecified;uint160 sqrtPriceLimitX96;}
    function unlock(bytes calldata) external returns(bytes memory);
    function swap(PoolKey calldata,SwapParams calldata,bytes calldata) external returns(int256);
    function sync(address) external;
    function settle() external payable returns(uint256);
    function take(address,address,uint256) external;
}
interface IEmbeddedBalancerV2Vault {
    enum SwapKind { GIVEN_IN, GIVEN_OUT }
    struct SingleSwap {
        bytes32 poolId; SwapKind kind; address assetIn; address assetOut;
        uint256 amount; bytes userData;
    }
    struct FundManagement {
        address sender;bool fromInternalBalance;address payable recipient;bool toInternalBalance;
    }
    function swap(SingleSwap calldata,FundManagement calldata,uint256,uint256) external payable returns(uint256);
    function getPool(bytes32) external view returns(address,uint8);
    function getPoolTokens(bytes32) external view returns(address[] memory,uint256[] memory,uint256);
}
interface IExternalRouterHop {
    // An extension receives exact ERC20 allowance only for this hop, never delegatecall.
    function executeHop(
        address pool,address tokenIn,address tokenOut,uint256 amountIn,uint256 minAmountOut,
        bytes32 poolId,bytes calldata poolData
    ) external returns(uint256);
}

/**
 * @dev ABI templates are pre-encoded argument bytes (NO selector); a patch points to a
 * 32-byte word at byteOffset. This also supports words nested inside dynamic ABI args.
 * Modes: 0 literal, 1 swapamount, 2 slippageguard, 3 currentblock+literal,
 * 4 timestamp+literal, 5 tokenIn, 6 tokenOut, 7 routerAddress.
 * Non-patched literal words stay in the provided template.
 */
contract CurveYieldOmniRouter {
    uint16 public constant DEFAULT_SLIPPAGE_BPS = 100;
    uint16 public constant MAX_DEFAULT_SLIPPAGE_BPS = 300;
    uint16 public constant MAX_ROUTE_SLIPPAGE_BPS = 500;
    uint16 public constant MAX_FEE_BPS = 50;
    uint8 public constant MAX_HOPS = 8;
    uint8 public constant MAX_PATCHES_PER_CALL = 24;
    uint16 public constant MAX_CALL_ARGUMENT_BYTES = 2048;

    enum InputKind { Literal, SwapAmount, SlippageGuard, CurrentBlockPlus, CurrentTimestampPlus, TokenIn, TokenOut, Router }
    struct AbiField {
        uint16 byteOffset;
        InputKind kind;
        uint256 literal;
    }
    struct Hop {
        address tokenIn;
        address tokenOut;
        address poolAddress;        // actual pool for V2/V3/Curve, PoolManager for V4
        address executionTarget;    // target contract called; periphery router or V4 adapter when applicable
        bytes4 writeFunctionID;
        bytes requiredAbiInputs;   // full ABI encoding after selector, including dynamic tails
        AbiField[] writeFields;    // dynamic word substitutions in requiredAbiInputs
        bool transferBeforeCall;   // direct V2 pair.swap needs tokens sent ahead of call
        address oracleAddress;     // historic-price source (not an instant swap quoter)
        string oracleReadFunctionName; // canonical signature, e.g. price_oracle(uint256)
        bytes oracleReadFunctionInputs;
        AbiField[] oracleFields;
        uint8 oracleRateDecimals;  // quote output whole-tokens per one whole input token
        bool invertOracle;         // invert source rate when tokens are reversed
    }
    // Stable built-in types remain part of this router. IDs >= 1000 are reserved
    // for independently deployed, owner-approved future pool-type extensions.
    uint16 public constant UNISWAP_V2 = 1;
    uint16 public constant UNISWAP_V3 = 2;
    uint16 public constant UNISWAP_V4 = 3;
    uint16 public constant CURVE_CRYPTOSWAP = 4;
    uint16 public constant CURVE_TRICRYPTO = 5;
    uint16 public constant CURVE_STABLESWAP = 6;
    uint16 public constant CURVE_STABLESWAP_NG = 7;
    uint16 public constant BALANCER_WEIGHTED = 8;
    uint16 public constant BALANCER_STABLE = 9;
    uint16 public constant EXTERNAL_TYPE_START = 1000;

    struct SimpleOracle {
        address oracleAddress; // zero = router's native V2/V3 or applicable Curve EMA
        bytes4 readFunctionID; // historical rate for 1 whole input token, NOT spot
        bytes requiredInputs; // ABI-encoded read arguments (without selector)
        bool invert;
        uint8 rateDecimals; // 0..18; builtin historical prices use 18
    }
    struct SimpleHop {
        uint16 poolType;
        address tokenOut;
        address swapContract; // V2/V3/Curve pool, V4 PoolManager, Balancer V2 Vault
        bytes32 poolId; // required for V4 (keccak PoolKey) and Balancer V2
        bytes poolData; // V2 feeBps, Curve (i,j), V4 (PoolKey, hookData), Balancer userData
        SimpleOracle oracle;
    }
    struct V2Observation {uint256 cumulative0;uint256 cumulative1;uint32 timestamp;}
    mapping(bytes32 => SimpleHop[]) private simpleRoutes;
    mapping(uint16 => address) public externalAdapters;
    mapping(address => V2Observation[2]) public v2Observations;
    address private activeV3Pool;
    address private activeV3TokenIn;
    uint256 private activeV3Amount;
    bool private v3CallbackConsumed;
    address private activeV4Manager;
    bool private v4CallbackConsumed;

    event ExternalAdapterConfigured(uint16 indexed poolType,address indexed adapter);
    event V2PriceCheckpointed(address indexed pair,uint32 timestamp);

    struct Route {
        Hop[] pathway;
        uint16 feeBps;
        uint16 slippageGuardBps;
        bool configured;
    }
    mapping(bytes32=>Route) private routes;

    address public owner;
    address public feeRecipient;
    uint16 public feeBps = 10;              // 0.10% default, capped at 0.50%
    uint16 public defaultSlippageGuardBps = DEFAULT_SLIPPAGE_BPS;
    uint256 private reentrancyStatus=1;
    event RouteSet(address indexed tokenIn,address indexed tokenOut,uint256 hopCount);
    event RouteConfigSet(address indexed tokenIn,address indexed tokenOut,uint16 feeBps,uint16 slippageBps);
    event SwapExecuted(address indexed sender,address indexed tokenIn,address indexed tokenOut,uint256 amountIn,uint256 amountOut);
    event OwnershipTransferred(address indexed oldOwner,address indexed newOwner);

    modifier onlyOwner(){require(msg.sender==owner,"NOT_OWNER");_;}
    modifier nonReentrant(){require(reentrancyStatus==1,"REENTRANCY");reentrancyStatus=2;_;reentrancyStatus=1;}

    constructor(address owner_,address feeRecipient_){
        require(block.chainid==1 || block.chainid==252,"ONLY_ETHEREUM_FRAXTAL");
        require(owner_!=address(0) && feeRecipient_!=address(0) && feeRecipient_!=address(this),"BAD_ADDRESS");
        owner=owner_;
        feeRecipient=feeRecipient_;
    }

    function transferOwnership(address nextOwner) external onlyOwner {
        require(nextOwner!=address(0),"BAD_OWNER");
        emit OwnershipTransferred(owner,nextOwner);
        owner=nextOwner;
    }
    function setFeeRecipient(address to) external onlyOwner {
        require(to!=address(0) && to!=address(this),"BAD_RECIPIENT");
        feeRecipient=to;
    }
    function setFeeBps(uint16 value) external onlyOwner {
        require(value<=MAX_FEE_BPS,"FEE_CAP");
        feeBps=value;
    }
    function setDefaultSlippageGuardBps(uint16 value) external onlyOwner {
        require(value<=MAX_DEFAULT_SLIPPAGE_BPS,"DEFAULT_SLIPPAGE_CAP");
        defaultSlippageGuardBps=value;
    }

    // Ordinary swaps need only a pool type, execution address/ID, hop output token,
    // optional pool-specific data, and optional historical oracle metadata.
    function setRoute(address tokenIn,address tokenOut,SimpleHop[] calldata pathway) external onlyOwner {
        bytes32 key=_key(tokenIn,tokenOut);
        _replaceSimple(key,tokenIn,tokenOut,pathway);
        emit RouteSet(tokenIn,tokenOut,pathway.length);
    }

    // An empty pathway updates only fee/slippage without replacing existing hops.
    function setRouteConfig(
        address tokenIn,address tokenOut,SimpleHop[] calldata pathway,
        uint16 routeFeeBps,uint16 routeSlippageBps
    ) external onlyOwner {
        require(routeFeeBps<=MAX_FEE_BPS,"ROUTE_FEE_CAP");
        require(routeSlippageBps<=MAX_ROUTE_SLIPPAGE_BPS,"ROUTE_SLIPPAGE_CAP");
        bytes32 key=_key(tokenIn,tokenOut);
        if(pathway.length!=0) {
            _replaceSimple(key,tokenIn,tokenOut,pathway);
            emit RouteSet(tokenIn,tokenOut,pathway.length);
        } else {
            require(simpleRoutes[key].length>0||routes[key].pathway.length>0,"ROUTE_MISSING");
        }
        routes[key].feeBps=routeFeeBps;
        routes[key].slippageGuardBps=routeSlippageBps;
        routes[key].configured=true;
        emit RouteConfigSet(tokenIn,tokenOut,routeFeeBps,routeSlippageBps);
    }

    // Preserve the advanced contract-agnostic ABI route method for exceptional pools.
    function setRouteAdvanced(address tokenIn,address tokenOut,Hop[] calldata pathway) external onlyOwner {
        bytes32 key=_key(tokenIn,tokenOut);
        _replaceRoute(key,tokenIn,tokenOut,pathway);
        delete simpleRoutes[key];
        emit RouteSet(tokenIn,tokenOut,pathway.length);
    }

    // Reserve external types for future pools; extensions cannot delegatecall the router.
    function setExternalAdapter(uint16 poolType,address adapter) external onlyOwner {
        require(poolType>=EXTERNAL_TYPE_START,"BUILTIN_TYPE_IMMUTABLE");
        require(adapter==address(0)||adapter.code.length>0,"INVALID_EXTENSION");
        externalAdapters[poolType]=adapter;
        emit ExternalAdapterConfigured(poolType,adapter);
    }

    function routeLength(address tokenIn,address tokenOut) external view returns(uint256){
        bytes32 key=_key(tokenIn,tokenOut);
        return simpleRoutes[key].length!=0?simpleRoutes[key].length:routes[key].pathway.length;
    }
    function routeForAdvanced(address tokenIn,address tokenOut) external view returns(Hop[] memory){
        return routes[_key(tokenIn,tokenOut)].pathway;
    }
    function routeFor(address tokenIn,address tokenOut) external view returns(SimpleHop[] memory){
        return simpleRoutes[_key(tokenIn,tokenOut)];
    }

    function routeConfig(address tokenIn,address tokenOut) external view returns(uint16 routeFeeBps,uint16 slippageBps,bool configured){
        Route storage r=routes[_key(tokenIn,tokenOut)];
        return(_effectiveFee(r),_effectiveSlippage(r),r.configured);
    }

    // An oracle rate is the quantity of tokenOut per one whole tokenIn, scaled by 1e18.
    // Returns the aggregate historical rate over the complete configured route.
    function price_oracle(address tokenIn,address tokenOut) external view returns(uint256){
        uint256 unitIn=_unit(tokenIn);
        uint256 outputRaw=_estimateRouteGross(tokenIn,tokenOut,unitIn);
        return RouterFullMath.mulDiv(outputRaw,1e18,_unit(tokenOut));
    }
    // Deterministic oracle-derived net estimate. Not an executable spot/price-impact quote.
    function estimate_exact_output(address tokenIn,address tokenOut,uint256 amountIn)
        external view returns(uint256 amount_out)
    {
        Route storage r=_route(tokenIn,tokenOut);
        uint256 gross=_estimateRouteGross(tokenIn,tokenOut,amountIn);
        return RouterFullMath.mulDiv(gross,10000-_effectiveFee(r),10000);
    }
    // Worst-case per-hop slippage guard compounded across a mixed route; net of fee.
    function guardedMinOut(address tokenIn,address tokenOut,uint256 amountIn)
        external view returns(uint256 amountOut)
    {
        Route storage r=_route(tokenIn,tokenOut);
        bytes32 key=_key(tokenIn,tokenOut);
        uint256 guarded=amountIn;
        if(simpleRoutes[key].length!=0){
            for(uint256 i=0;i<simpleRoutes[key].length;i++){
                address currentIn=i==0?tokenIn:simpleRoutes[key][i-1].tokenOut;
                uint256 expected=_simpleOracleQuote(simpleRoutes[key][i],currentIn,guarded);
                guarded=RouterFullMath.mulDiv(expected,10000-_effectiveSlippage(r),10000);
            }
            return RouterFullMath.mulDiv(guarded,10000-_effectiveFee(r),10000);
        }
        for(uint256 i=0;i<r.pathway.length;i++){
            uint256 expected=_oracleQuote(r.pathway[i],guarded);
            guarded=RouterFullMath.mulDiv(expected,10000-_effectiveSlippage(r),10000);
        }
        return RouterFullMath.mulDiv(guarded,10000-_effectiveFee(r),10000);
    }
    // 3-input swap; owner-selected route always applies its historical-price guard and fee.
    function easyswap(address tokenIn,address tokenOut,uint256 amountIn)
        external nonReentrant returns(uint256 amountOut)
    {
        return _swap(tokenIn,tokenOut,amountIn,0,msg.sender,block.timestamp);
    }
    // Preserve familiar exact-input interface for callers requiring minOut, recipient and deadline.
    function swapExactInput(
        address tokenIn,address tokenOut,uint256 amountIn,
        uint256 minNetAmountOut,address recipient,uint256 deadline
    ) external nonReentrant returns(uint256 netAmountOut){
        return _swap(tokenIn,tokenOut,amountIn,minNetAmountOut,recipient,deadline);
    }

    function _swap(address tokenIn,address tokenOut,uint256 amountIn,uint256 userMin,address recipient,uint256 deadline)
        internal returns(uint256 net)
    {
        require(block.timestamp<=deadline,"EXPIRED");
        require(amountIn>0 && recipient!=address(0) && recipient!=address(this),"BAD_SWAP");
        Route storage r=_route(tokenIn,tokenOut);
        if(simpleRoutes[_key(tokenIn,tokenOut)].length!=0) {
            return _swapSimple(tokenIn,tokenOut,amountIn,userMin,recipient,r);
        }
        uint256 originalInputBalance=IOmniERC20(tokenIn).balanceOf(address(this));
        _safeTransferFrom(tokenIn,msg.sender,address(this),amountIn);
        uint256 currentAmount=amountIn;
        uint16 slip=_effectiveSlippage(r);
        for(uint256 i=0;i<r.pathway.length;i++) {
            Hop storage hop=r.pathway[i];
            uint256 expected=_oracleQuote(hop,currentAmount);
            uint256 minimum=RouterFullMath.mulDiv(expected,10000-slip,10000);
            require(minimum>0,"DUST_MINIMUM");
            uint256 beforeIn=IOmniERC20(hop.tokenIn).balanceOf(address(this));
            uint256 beforeOut=IOmniERC20(hop.tokenOut).balanceOf(address(this));
            if(hop.transferBeforeCall){
                _safeTransfer(hop.tokenIn,hop.executionTarget,currentAmount);
            } else {
                _safeApprove(hop.tokenIn,hop.executionTarget,0);
                _safeApprove(hop.tokenIn,hop.executionTarget,currentAmount);
            }
            bytes memory args=_fill(hop.requiredAbiInputs,hop.writeFields,currentAmount,minimum,hop.tokenIn,hop.tokenOut);
            (bool ok,bytes memory ret)=hop.executionTarget.call(abi.encodePacked(hop.writeFunctionID,args));
            if(!ok) _revertWith(ret);
            if(!hop.transferBeforeCall) _safeApprove(hop.tokenIn,hop.executionTarget,0);
            uint256 afterIn=IOmniERC20(hop.tokenIn).balanceOf(address(this));
            require(afterIn<=beforeIn && beforeIn-afterIn==currentAmount,"HOP_INPUT_NOT_FULLY_SPENT");
            uint256 afterOut=IOmniERC20(hop.tokenOut).balanceOf(address(this));
            require(afterOut>=beforeOut,"OUTPUT_BALANCE_DECREASED");
            currentAmount=afterOut-beforeOut;
            require(currentAmount>=minimum,"HOP_SLIPPAGE");
        }
        uint256 fee=RouterFullMath.mulDiv(currentAmount,_effectiveFee(r),10000);
        net=currentAmount-fee;
        require(net>=userMin,"MIN_NET");
        if(fee!=0) _safeTransfer(tokenOut,feeRecipient,fee);
        _safeTransfer(tokenOut,recipient,net);
        require(IOmniERC20(tokenIn).balanceOf(address(this))>=originalInputBalance,"INPUT_BALANCE_LOSS");
        emit SwapExecuted(msg.sender,tokenIn,tokenOut,amountIn,net);
    }


    // Owner-specified simple paths are mapped to built-in execution code, not
    // user-supplied ABI patch lists. A future pool type uses a separately
    // registered external adapter with exact input allowance.
    function _replaceSimple(bytes32 key,address tokenIn,address tokenOut,SimpleHop[] calldata pathway)
        internal
    {
        require(tokenIn!=address(0)&&tokenOut!=address(0)&&tokenIn!=tokenOut,"BAD_ENDPOINTS");
        require(pathway.length>0 && pathway.length<=MAX_HOPS,"HOP_COUNT");
        address current=tokenIn;
        for(uint256 i=0;i<pathway.length;i++){
            SimpleHop calldata h=pathway[i];
            require(h.tokenOut!=address(0)&&h.tokenOut!=current&&h.swapContract.code.length>0,"BAD_HOP");
            require(current.code.length>0 && h.tokenOut.code.length>0,"INVALID_TOKENS");
            require(h.poolData.length<=MAX_CALL_ARGUMENT_BYTES,"POOL_DATA_LIMIT");
            require(h.oracle.requiredInputs.length<=MAX_CALL_ARGUMENT_BYTES,"ORACLE_DATA_LIMIT");
            require(h.oracle.rateDecimals<=18,"ORACLE_DECIMALS");
            for(uint256 j=0;j<i;j++) require(pathway[j].tokenOut!=h.tokenOut,"REPEATED_TOKEN");
            require(tokenIn!=h.tokenOut,"ROUTE_CYCLE");

            if(h.poolType==UNISWAP_V2){
                IEmbeddedV2Pair pair=IEmbeddedV2Pair(h.swapContract);
                require((pair.token0()==current&&pair.token1()==h.tokenOut)||
                        (pair.token1()==current&&pair.token0()==h.tokenOut),"V2_TOKENS");
                if(h.poolData.length!=0){
                    uint16 fee=abi.decode(h.poolData,(uint16));
                    require(fee<=1000,"V2_FEE_CAP");
                }
            } else if(h.poolType==UNISWAP_V3){
                IEmbeddedV3Pool pool=IEmbeddedV3Pool(h.swapContract);
                require((pool.token0()==current&&pool.token1()==h.tokenOut)||
                        (pool.token1()==current&&pool.token0()==h.tokenOut),"V3_TOKENS");
                if(h.poolData.length!=0) require(abi.decode(h.poolData,(uint32))>=900,"V3_TWAP_WINDOW");
            } else if(h.poolType==UNISWAP_V4){
                (IEmbeddedV4Manager.PoolKey memory key4,bytes memory hookData)=
                    abi.decode(h.poolData,(IEmbeddedV4Manager.PoolKey,bytes));
                require((key4.currency0==current&&key4.currency1==h.tokenOut)||
                        (key4.currency1==current&&key4.currency0==h.tokenOut),"V4_TOKENS");
                require(key4.currency0<key4.currency1,"V4_SORT");
                require(keccak256(abi.encode(key4))==h.poolId,"V4_POOL_ID");
                require(hookData.length<=1024,"V4_HOOK_DATA");
            } else if(_isCurve(h.poolType)){
                (uint8 coinIn,uint8 coinOut)=abi.decode(h.poolData,(uint8,uint8));
                require(coinIn!=coinOut,"CURVE_INDEX");
                require(_curveCoin(h.swapContract,coinIn)==current &&
                        _curveCoin(h.swapContract,coinOut)==h.tokenOut,"CURVE_COIN_MISMATCH");
            } else if(h.poolType==BALANCER_WEIGHTED||h.poolType==BALANCER_STABLE){
                (address balancerPool,)=IEmbeddedBalancerV2Vault(h.swapContract).getPool(h.poolId);
                require(balancerPool!=address(0),"BALANCER_POOL_ID");
                (address[] memory tokens,,)=IEmbeddedBalancerV2Vault(h.swapContract).getPoolTokens(h.poolId);
                bool foundInput;bool foundOutput;
                for(uint256 k=0;k<tokens.length;k++){
                    if(tokens[k]==current) foundInput=true;
                    if(tokens[k]==h.tokenOut) foundOutput=true;
                }
                require(foundInput&&foundOutput,"BALANCER_TOKEN_MISMATCH");
            } else {
                require(h.poolType>=EXTERNAL_TYPE_START,"UNKNOWN_POOL_TYPE");
                require(externalAdapters[h.poolType]!=address(0),"EXTERNAL_ADAPTER_MISSING");
            }

            if(h.oracle.oracleAddress!=address(0)){
                require(h.oracle.oracleAddress.code.length>0&&h.oracle.readFunctionID!=bytes4(0),"BAD_ORACLE");
            } else {
                require(h.poolType==UNISWAP_V2||h.poolType==UNISWAP_V3||
                    h.poolType==CURVE_CRYPTOSWAP||h.poolType==CURVE_TRICRYPTO||
                    h.poolType==CURVE_STABLESWAP_NG,"EXTERNAL_HISTORICAL_ORACLE_REQUIRED");
            }
            current=h.tokenOut;
        }
        require(current==tokenOut,"WRONG_FINAL_TOKEN");
        delete simpleRoutes[key];
        for(uint256 i=0;i<pathway.length;i++) simpleRoutes[key].push(pathway[i]);
        delete routes[key].pathway;
    }

    // Pool implementations disagree on coins(uint256) vs coins(int128).
    // Validate actual coin membership before allowing a built-in Curve route.
    function _curveCoin(address pool,uint8 index) private view returns(address token){
        (bool ok,bytes memory out)=pool.staticcall(
            abi.encodeWithSignature("coins(uint256)",uint256(index))
        );
        if(!ok || out.length<32) {
            (ok,out)=pool.staticcall(
                abi.encodeWithSignature("coins(int128)",int128(uint128(index)))
            );
        }
        require(ok&&out.length>=32,"CURVE_COINS_NOT_READABLE");
        token=abi.decode(out,(address));
        require(token!=address(0),"CURVE_ZERO_COIN");
    }

    function _isCurve(uint16 poolType) internal pure returns(bool){
        return poolType==CURVE_CRYPTOSWAP||poolType==CURVE_TRICRYPTO||
            poolType==CURVE_STABLESWAP||poolType==CURVE_STABLESWAP_NG;
    }

    function _swapSimple(
        address tokenIn,address tokenOut,uint256 amountIn,
        uint256 userMin,address recipient,Route storage r
    ) private returns(uint256 net){
        SimpleHop[] storage hops=simpleRoutes[_key(tokenIn,tokenOut)];
        uint256 originalBalance=IOmniERC20(tokenIn).balanceOf(address(this));
        _safeTransferFrom(tokenIn,msg.sender,address(this),amountIn);
        require(IOmniERC20(tokenIn).balanceOf(address(this))==originalBalance+amountIn,"NONSTANDARD_INPUT");
        uint256 amount=amountIn;
        uint16 slippage=_effectiveSlippage(r);
        for(uint256 i=0;i<hops.length;i++){
            address from=i==0?tokenIn:hops[i-1].tokenOut;
            amount=_swapSimpleHop(hops[i],from,amount,slippage);
        }
        uint256 protocolFee=RouterFullMath.mulDiv(amount,_effectiveFee(r),10000);
        net=amount-protocolFee;
        require(net>=userMin,"MIN_NET");
        if(protocolFee!=0) _safeTransfer(tokenOut,feeRecipient,protocolFee);
        _safeTransfer(tokenOut,recipient,net);
        require(IOmniERC20(tokenIn).balanceOf(address(this))>=originalBalance,"INPUT_BALANCE_LOSS");
        emit SwapExecuted(msg.sender,tokenIn,tokenOut,amountIn,net);
    }

    function _swapSimpleHop(
        SimpleHop storage hop,address tokenIn,uint256 amount,uint16 slippage
    ) private returns(uint256 outAmount){
        uint256 minHop=RouterFullMath.mulDiv(
            _simpleOracleQuote(hop,tokenIn,amount),10000-slippage,10000
        );
        require(minHop>0,"DUST_MINIMUM");
        address tokenOut=hop.tokenOut;
        uint256 beforeIn=IOmniERC20(tokenIn).balanceOf(address(this));
        uint256 beforeOut=IOmniERC20(tokenOut).balanceOf(address(this));
        _executeSimpleHop(hop,tokenIn,amount,minHop);
        uint256 afterIn=IOmniERC20(tokenIn).balanceOf(address(this));
        uint256 afterOut=IOmniERC20(tokenOut).balanceOf(address(this));
        require(afterIn<=beforeIn && beforeIn-afterIn==amount,"HOP_INPUT_NOT_FULLY_SPENT");
        require(afterOut>=beforeOut,"OUTPUT_BALANCE_DECREASED");
        outAmount=afterOut-beforeOut;
        require(outAmount>=minHop,"HOP_SLIPPAGE");
    }

    function _executeSimpleHop(SimpleHop storage hop,address tokenIn,uint256 amount,uint256 minOut) internal {
        uint16 t=hop.poolType;
        if(t==UNISWAP_V2){
            _executeV2(hop,tokenIn,amount,minOut);
        } else if(t==UNISWAP_V3){
            _executeV3(hop,tokenIn,amount);
        } else if(t==UNISWAP_V4){
            _executeV4(hop,tokenIn,amount);
        } else if(_isCurve(t)){
            _executeCurve(hop,tokenIn,amount,minOut);
        } else if(t==BALANCER_WEIGHTED||t==BALANCER_STABLE){
            _executeBalancerV2(hop,tokenIn,amount,minOut);
        } else {
            address adapter=externalAdapters[t];
            require(adapter!=address(0)&&adapter.code.length>0,"EXTENSION_NOT_ACTIVE");
            _safeApprove(tokenIn,adapter,0);
            _safeApprove(tokenIn,adapter,amount);
            IExternalRouterHop(adapter).executeHop(
                hop.swapContract,tokenIn,hop.tokenOut,amount,minOut,hop.poolId,hop.poolData
            );
            _safeApprove(tokenIn,adapter,0);
        }
    }

    function _executeV2(SimpleHop storage hop,address tokenIn,uint256 amount,uint256 minOut) private {
        IEmbeddedV2Pair pair=IEmbeddedV2Pair(hop.swapContract);
        (uint112 r0,uint112 r1,)=pair.getReserves();
        require(r0>0&&r1>0,"V2_NO_LIQUIDITY");
        bool token0In=tokenIn==pair.token0();
        uint256 reserveIn=token0In?uint256(r0):uint256(r1);
        uint256 reserveOut=token0In?uint256(r1):uint256(r0);
        uint16 bps=hop.poolData.length==0?30:abi.decode(hop.poolData,(uint16));
        uint256 netIn=amount*(10000-uint256(bps));
        uint256 output=RouterFullMath.mulDiv(netIn,reserveOut,reserveIn*10000+netIn);
        require(output>=minOut && output!=0,"V2_INSUFFICIENT_OUTPUT");
        _safeTransfer(tokenIn,hop.swapContract,amount);
        pair.swap(token0In?0:output,token0In?output:0,address(this),"");
    }

    function _executeCurve(SimpleHop storage hop,address tokenIn,uint256 amount,uint256 minimum) private {
        (uint8 i,uint8 j)=abi.decode(hop.poolData,(uint8,uint8));
        _safeApprove(tokenIn,hop.swapContract,0);
        _safeApprove(tokenIn,hop.swapContract,amount);
        bytes memory payload;
        if(hop.poolType==CURVE_STABLESWAP||hop.poolType==CURVE_STABLESWAP_NG) {
            payload=abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)",
                int128(uint128(i)),int128(uint128(j)),amount,minimum);
        } else {
            payload=abi.encodeWithSignature("exchange(uint256,uint256,uint256,uint256)",
                uint256(i),uint256(j),amount,minimum);
        }
        (bool ok,bytes memory reason)=hop.swapContract.call(payload);
        if(!ok) _revertWith(reason);
        _safeApprove(tokenIn,hop.swapContract,0);
    }

    function _executeBalancerV2(SimpleHop storage hop,address tokenIn,uint256 amount,uint256 minOut) private {
        IEmbeddedBalancerV2Vault vault=IEmbeddedBalancerV2Vault(hop.swapContract);
        _safeApprove(tokenIn,hop.swapContract,0);
        _safeApprove(tokenIn,hop.swapContract,amount);
        IEmbeddedBalancerV2Vault.SingleSwap memory single=IEmbeddedBalancerV2Vault.SingleSwap({
            poolId:hop.poolId,kind:IEmbeddedBalancerV2Vault.SwapKind.GIVEN_IN,
            assetIn:tokenIn,assetOut:hop.tokenOut,amount:amount,userData:hop.poolData
        });
        IEmbeddedBalancerV2Vault.FundManagement memory funds=IEmbeddedBalancerV2Vault.FundManagement({
            sender:address(this),fromInternalBalance:false,recipient:payable(address(this)),toInternalBalance:false
        });
        vault.swap(single,funds,minOut,block.timestamp);
        _safeApprove(tokenIn,hop.swapContract,0);
    }


    // Native Uniswap V3 support. Unlike a helper adapter, this router itself
    // authenticates the pool's callback and transfers the actual owed tokens.
    function _executeV3(SimpleHop storage hop,address tokenIn,uint256 amount) private {
        require(activeV3Pool==address(0),"NESTED_V3");
        bool zeroForOne=tokenIn<hop.tokenOut;
        require(amount<=uint256(type(int256).max),"AMOUNT_TOO_LARGE");
        activeV3Pool=hop.swapContract;
        activeV3TokenIn=tokenIn;
        activeV3Amount=amount;
        v3CallbackConsumed=false;
        IEmbeddedV3Pool(hop.swapContract).swap(
            address(this),zeroForOne,int256(amount),
            zeroForOne?uint160(4295128740):uint160(1461446703485210103287273052203988822378723970341),""
        );
        require(v3CallbackConsumed,"V3_CALLBACK_MISSING");
        activeV3Pool=address(0);
        activeV3TokenIn=address(0);
        activeV3Amount=0;
    }

    function uniswapV3SwapCallback(int256 amount0Delta,int256 amount1Delta,bytes calldata)
        external
    {
        require(reentrancyStatus==2 && msg.sender==activeV3Pool&&
                activeV3Pool!=address(0)&&!v3CallbackConsumed,"UNAUTHORIZED_V3_CALLBACK");
        require((amount0Delta>0&&amount1Delta<=0)||(amount1Delta>0&&amount0Delta<=0),"INVALID_V3_DELTAS");
        bool zeroForOne=activeV3TokenIn==IEmbeddedV3Pool(msg.sender).token0();
        int256 owed=zeroForOne?amount0Delta:amount1Delta;
        require(owed>0&&uint256(owed)<=activeV3Amount,"V3_INPUT_DELTA");
        v3CallbackConsumed=true;
        _safeTransfer(activeV3TokenIn,msg.sender,uint256(owed));
    }

    // Uniswap v4 pools live inside a PoolManager, not at individual pool addresses.
    // poolId = keccak256(abi.encode(PoolKey)); poolData = abi.encode(PoolKey,hookData).
    function _executeV4(SimpleHop storage hop,address tokenIn,uint256 amount) private {
        require(activeV4Manager==address(0),"NESTED_V4");
        require(amount<=uint256(uint128(type(int128).max)),"V4_INPUT_LIMIT");
        (IEmbeddedV4Manager.PoolKey memory key4,bytes memory hookData)=
            abi.decode(hop.poolData,(IEmbeddedV4Manager.PoolKey,bytes));
        require(keccak256(abi.encode(key4))==hop.poolId,"V4_POOL_ID");
        activeV4Manager=hop.swapContract;
        v4CallbackConsumed=false;
        IEmbeddedV4Manager(hop.swapContract).unlock(
            abi.encode(key4,tokenIn,hop.tokenOut,amount,hookData)
        );
        require(v4CallbackConsumed,"V4_CALLBACK_MISSING");
        activeV4Manager=address(0);
    }

    function unlockCallback(bytes calldata payload) external returns(bytes memory){
        require(reentrancyStatus==2 && msg.sender==activeV4Manager &&
                activeV4Manager!=address(0)&&!v4CallbackConsumed,"UNAUTHORIZED_V4_CALLBACK");
        v4CallbackConsumed=true;
        (IEmbeddedV4Manager.PoolKey memory key4,address tokenIn,address tokenOut,
            uint256 amount,bytes memory hookData)=abi.decode(payload,
                (IEmbeddedV4Manager.PoolKey,address,address,uint256,bytes));
        require((tokenIn==key4.currency0&&tokenOut==key4.currency1)||
                (tokenIn==key4.currency1&&tokenOut==key4.currency0),"V4_TOKENS");
        bool zeroForOne=tokenIn==key4.currency0;
        IEmbeddedV4Manager manager=IEmbeddedV4Manager(msg.sender);
        IEmbeddedV4Manager.SwapParams memory params=IEmbeddedV4Manager.SwapParams({
            zeroForOne:zeroForOne,amountSpecified:-int256(amount),
            sqrtPriceLimitX96:zeroForOne?uint160(4295128740):
                uint160(1461446703485210103287273052203988822378723970341)
        });
        int256 packedDelta=manager.swap(key4,params,hookData);
        int128 amount0=int128(packedDelta>>128);
        int128 amount1=int128(packedDelta);
        int128 inputDelta=zeroForOne?amount0:amount1;
        int128 outputDelta=zeroForOne?amount1:amount0;
        require(inputDelta<0 && outputDelta>0,"INVALID_V4_DELTA");
        uint256 owed=uint256(-int256(inputDelta));
        uint256 out=uint256(int256(outputDelta));
        require(owed<=amount,"V4_OVERSPEND");
        manager.sync(tokenIn);
        _safeTransfer(tokenIn,msg.sender,owed);
        require(manager.settle()==owed,"V4_SETTLE");
        manager.take(tokenOut,address(this),out);
        return abi.encode(out);
    }


    // V2 historical observations are stored in the router itself. No separate
    // deployed TWAP adapter is needed. Checkpoint each active V2 pool periodically.
    function checkpointV2(address pair) external {
        require(pair.code.length!=0,"PAIR_MISSING");
        (uint256 c0,uint256 c1,uint32 timestamp)=_v2Cumulative(pair);
        V2Observation[2] storage obs=v2Observations[pair];
        uint32 age;
        unchecked{age=timestamp-obs[1].timestamp;}
        require(obs[1].timestamp==0||age>=900,"CHECKPOINT_TOO_SOON");
        obs[0]=obs[1];
        obs[1]=V2Observation(c0,c1,timestamp);
        emit V2PriceCheckpointed(pair,timestamp);
    }

    function _v2Cumulative(address pair)
        private view returns(uint256 c0,uint256 c1,uint32 nowTs)
    {
        IEmbeddedV2Pair p=IEmbeddedV2Pair(pair);
        c0=p.price0CumulativeLast();
        c1=p.price1CumulativeLast();
        (uint112 r0,uint112 r1,uint32 updated)=p.getReserves();
        require(r0>0&&r1>0,"V2_EMPTY_POOL");
        nowTs=uint32(block.timestamp);
        unchecked {
            uint32 elapsed=nowTs-updated;
            if(elapsed>0){
                c0+=((uint256(r1)<<112)/r0)*elapsed;
                c1+=((uint256(r0)<<112)/r1)*elapsed;
            }
        }
    }

    // A read-only quote for a V2 input based on a 15min+ observation interval.
    function _v2HistoricalQuote(address pool,address tokenIn,uint256 amount)
        private view returns(uint256)
    {
        IEmbeddedV2Pair p=IEmbeddedV2Pair(pool);
        (uint256 c0,uint256 c1,uint32 nowTs)=_v2Cumulative(pool);
        V2Observation storage obs=v2Observations[pool][1];
        uint32 elapsed;
        unchecked{elapsed=nowTs-obs.timestamp;}
        if(obs.timestamp==0||elapsed<900){
            obs=v2Observations[pool][0];
            unchecked{elapsed=nowTs-obs.timestamp;}
        }
        require(obs.timestamp!=0 && elapsed>=900 && elapsed<=86400,"V2_TWAP_NOT_READY");
        uint256 delta;
        unchecked{
            delta=tokenIn==p.token0()?c0-obs.cumulative0:c1-obs.cumulative1;
        }
        uint256 averageQ112=delta/elapsed;
        uint256 quoted=RouterFullMath.mulDiv(amount,averageQ112,uint256(1)<<112);
        require(quoted>0,"V2_ORACLE_ZERO");
        return quoted;
    }

    // V3 native observe() provides a historical cumulative tick.
    function _v3HistoricalQuote(SimpleHop storage hop,address tokenIn,uint256 amount)
        private view returns(uint256)
    {
        uint32 window=hop.poolData.length==0?900:abi.decode(hop.poolData,(uint32));
        require(window>=900,"V3_MIN_TWAP");
        uint32[] memory secondsAgo=new uint32[](2);
        secondsAgo[0]=window;
        (int56[] memory cumulative,)=IEmbeddedV3Pool(hop.swapContract).observe(secondsAgo);
        require(cumulative.length==2,"V3_OBSERVATIONS");
        int56 delta=cumulative[1]-cumulative[0];
        int56 secondsInt=int56(uint56(window));
        int24 tick=int24(delta/secondsInt);
        if(delta<0 && delta%secondsInt!=0) tick--;
        uint160 sqrtRatio=TickMath.getSqrtPriceAtTick(tick);
        if(sqrtRatio<=type(uint128).max){
            uint256 ratioX192=uint256(sqrtRatio)*sqrtRatio;
            return tokenIn==IEmbeddedV3Pool(hop.swapContract).token0()
                ?RouterFullMath.mulDiv(ratioX192,amount,uint256(1)<<192)
                :RouterFullMath.mulDiv(uint256(1)<<192,amount,ratioX192);
        }
        uint256 ratioX128=RouterFullMath.mulDiv(sqrtRatio,sqrtRatio,uint256(1)<<64);
        return tokenIn==IEmbeddedV3Pool(hop.swapContract).token0()
            ?RouterFullMath.mulDiv(ratioX128,amount,uint256(1)<<128)
            :RouterFullMath.mulDiv(uint256(1)<<128,amount,ratioX128);
    }

    // Curve CryptoSwap, TriCrypto and StableSwap-NG expose EMA price_oracle().
    // Legacy StableSwap has no universal historical oracle and must use an
    // explicit external historical oracle.
    function _curveHistoricalRate(SimpleHop storage hop) private view returns(uint256){
        (uint8 i,uint8 j)=abi.decode(hop.poolData,(uint8,uint8));
        uint256 rateIn=1e18;
        uint256 rateOut=1e18;
        if(i>0) rateIn=_curveOracleComponent(hop.swapContract,hop.poolType,uint256(i)-1);
        if(j>0) rateOut=_curveOracleComponent(hop.swapContract,hop.poolType,uint256(j)-1);
        require(rateIn>0 && rateOut>0,"CURVE_ORACLE_ZERO");
        return RouterFullMath.mulDiv(rateIn,1e18,rateOut);
    }

    function _curveOracleComponent(address pool,uint16 poolType,uint256 index)
        private view returns(uint256)
    {
        bytes memory callData=poolType==CURVE_CRYPTOSWAP
            ?abi.encodeWithSignature("price_oracle()")
            :abi.encodeWithSignature("price_oracle(uint256)",index);
        (bool ok,bytes memory out)=pool.staticcall(callData);
        if(!ok) _revertWith(out);
        require(out.length>=32,"CURVE_EMA_MISSING");
        uint256 rate=abi.decode(out,(uint256));
        require(rate!=0,"CURVE_ORACLE_ZERO");
        return rate;
    }

    function _simpleOracleQuote(SimpleHop storage hop,address tokenIn,uint256 amount)
        private view returns(uint256 output)
    {
        require(amount>0,"ZERO_AMOUNT");
        if(hop.oracle.oracleAddress==address(0) && hop.poolType==UNISWAP_V2){
            require(!hop.oracle.invert,"NATIVE_ORACLE_NOT_INVERTIBLE");
            return _v2HistoricalQuote(hop.swapContract,tokenIn,amount);
        }
        if(hop.oracle.oracleAddress==address(0) && hop.poolType==UNISWAP_V3){
            require(!hop.oracle.invert,"NATIVE_ORACLE_NOT_INVERTIBLE");
            return _v3HistoricalQuote(hop,tokenIn,amount);
        }
        uint256 rate;
        uint256 precision;
        if(hop.oracle.oracleAddress==address(0)){
            require(hop.poolType==CURVE_CRYPTOSWAP||hop.poolType==CURVE_TRICRYPTO||
                    hop.poolType==CURVE_STABLESWAP_NG,"HISTORICAL_ORACLE_REQUIRED");
            rate=_curveHistoricalRate(hop);
            precision=1e18;
        } else {
            (bool ok,bytes memory out)=hop.oracle.oracleAddress.staticcall(
                abi.encodePacked(hop.oracle.readFunctionID,hop.oracle.requiredInputs)
            );
            if(!ok) _revertWith(out);
            require(out.length>=32,"ORACLE_INVALID_OUTPUT");
            rate=abi.decode(out,(uint256));
            precision=10**uint256(hop.oracle.rateDecimals);
        }
        require(rate>0,"ORACLE_ZERO_RATE");
        if(hop.oracle.invert){
            rate=RouterFullMath.mulDiv(precision,precision,rate);
            require(rate>0,"INVERTED_RATE_ZERO");
        }
        uint256 inputUnit=_unit(tokenIn);
        uint256 outputUnit=_unit(hop.tokenOut);
        output=RouterFullMath.mulDiv(RouterFullMath.mulDiv(amount,rate,precision),
                                    outputUnit,inputUnit);
        require(output>0,"ORACLE_DUST");
    }

    function _replaceRoute(bytes32 key,address tokenIn,address tokenOut,Hop[] calldata pathway) internal {
        require(tokenIn!=address(0)&&tokenOut!=address(0)&&tokenIn!=tokenOut,"BAD_ENDPOINTS");
        require(pathway.length>0 && pathway.length<=MAX_HOPS,"HOP_COUNT");
        address current=tokenIn;
        for(uint256 i=0;i<pathway.length;i++){
            Hop calldata h=pathway[i];
            require(h.tokenIn==current && h.tokenOut!=address(0) && h.tokenIn!=h.tokenOut,"DISCONNECTED");
            require(h.poolAddress.code.length>0 && h.executionTarget.code.length>0 && h.oracleAddress.code.length>0,"UNDEPLOYED_TARGET");
            if(h.transferBeforeCall) require(h.executionTarget==h.poolAddress,"DIRECT_TRANSFER_TARGET");
            require(h.tokenIn.code.length>0 && h.tokenOut.code.length>0,"NOT_TOKEN");
            require(h.writeFunctionID!=bytes4(0),"MISSING_SWAP_SELECTOR");
            require(bytes(h.oracleReadFunctionName).length>2,"MISSING_ORACLE_SIG");
            require(h.oracleRateDecimals<=18,"ORACLE_PRECISION");
            require(h.requiredAbiInputs.length<=MAX_CALL_ARGUMENT_BYTES,"SWAP_ARGS_LIMIT");
            require(h.oracleReadFunctionInputs.length<=MAX_CALL_ARGUMENT_BYTES,"ORACLE_ARGS_LIMIT");
            _validatePatches(h.requiredAbiInputs,h.writeFields);
            _validatePatches(h.oracleReadFunctionInputs,h.oracleFields);
            // Prevent returning to any prior token: final input must remain fully consumable.
            for(uint256 j=0;j<i;j++) require(pathway[j].tokenIn!=h.tokenOut,"REPEATED_TOKEN");
            require(tokenIn!=h.tokenOut,"REPEATED_START");
            current=h.tokenOut;
        }
        require(current==tokenOut,"WRONG_FINAL_TOKEN");
        delete routes[key].pathway;
        for(uint256 i=0;i<pathway.length;i++){
            routes[key].pathway.push(pathway[i]);
        }
    }

    function _validatePatches(bytes calldata data,AbiField[] calldata fields) private pure {
        require(fields.length<=MAX_PATCHES_PER_CALL,"PATCH_COUNT");
        for(uint256 i=0;i<fields.length;i++){
            require(uint256(fields[i].byteOffset)%32==0 && uint256(fields[i].byteOffset)+32<=data.length,"PATCH_OFFSET");
            for(uint256 j=0;j<i;j++) require(fields[j].byteOffset!=fields[i].byteOffset,"PATCH_DUPLICATE");
        }
    }
    function _estimateRouteGross(address tokenIn,address tokenOut,uint256 amount)
        private view returns(uint256)
    {
        bytes32 key=_key(tokenIn,tokenOut);
        if(simpleRoutes[key].length==0) return _estimateGross(_route(tokenIn,tokenOut),amount);
        SimpleHop[] storage hops=simpleRoutes[key];
        require(amount>0,"ZERO_AMOUNT");
        for(uint256 i=0;i<hops.length;i++){
            address currentIn=i==0?tokenIn:hops[i-1].tokenOut;
            amount=_simpleOracleQuote(hops[i],currentIn,amount);
        }
        return amount;
    }

    function _estimateGross(Route storage r,uint256 amount) internal view returns(uint256){
        require(amount>0,"ZERO_AMOUNT");
        for(uint256 i=0;i<r.pathway.length;i++){
            amount=_oracleQuote(r.pathway[i],amount);
            require(amount>0,"ZERO_ORACLE_QUOTE");
        }
        return amount;
    }
    function _oracleQuote(Hop storage hop,uint256 inputRaw) internal view returns(uint256){
        bytes memory data=_fill(hop.oracleReadFunctionInputs,hop.oracleFields,inputRaw,0,hop.tokenIn,hop.tokenOut);
        bytes memory signature=bytes(hop.oracleReadFunctionName);
        // Accept a plain zero-argument name (e.g. "price_oracle") as well as "price_oracle()".
        bool hasParen;
        for(uint256 i=0;i<signature.length;i++){
            if(signature[i]==bytes1(0x28)){hasParen=true;break;}
        }
        if(!hasParen){
            require(data.length==0,"ORACLE_SIGNATURE_NEEDS_TYPES");
            signature=abi.encodePacked(signature,"()");
        }
        bytes4 selector=bytes4(keccak256(signature));
        (bool ok,bytes memory out)=hop.oracleAddress.staticcall(abi.encodePacked(selector,data));
        if(!ok) _revertWith(out);
        require(out.length>=32,"MALFORMED_ORACLE");
        uint256 rate=abi.decode(out,(uint256));
        require(rate>0,"ZERO_ORACLE_RATE");
        uint256 precision=10**uint256(hop.oracleRateDecimals);
        if(hop.invertOracle){
            rate=RouterFullMath.mulDiv(precision,precision,rate);
            require(rate>0,"INVERT_ORACLE_UNDERFLOW");
        }
        uint256 withRate=RouterFullMath.mulDiv(inputRaw,rate,precision);
        return RouterFullMath.mulDiv(withRate,_unit(hop.tokenOut),_unit(hop.tokenIn));
    }
    function _unit(address token) private view returns(uint256){
        uint8 d=IOmniERC20(token).decimals();
        require(d<=36,"TOKEN_DECIMALS");
        return 10**uint256(d);
    }
    function _fill(bytes storage templateData,AbiField[] storage fields,uint256 amount,uint256 guard,address tokenIn,address tokenOut)
        private view returns(bytes memory result)
    {
        result=templateData;
        for(uint256 i=0;i<fields.length;i++){
            AbiField storage p=fields[i];
            uint256 value;
            if(p.kind==InputKind.Literal) value=p.literal;
            else if(p.kind==InputKind.SwapAmount) value=amount;
            else if(p.kind==InputKind.SlippageGuard) value=guard;
            else if(p.kind==InputKind.CurrentBlockPlus) value=block.number+p.literal;
            else if(p.kind==InputKind.CurrentTimestampPlus) value=block.timestamp+p.literal;
            else if(p.kind==InputKind.TokenIn) value=uint160(tokenIn);
            else if(p.kind==InputKind.TokenOut) value=uint160(tokenOut);
            else if(p.kind==InputKind.Router) value=uint160(address(this));
            else revert("UNKNOWN_INPUT_KIND");
            uint256 offset=uint256(p.byteOffset);
            assembly ("memory-safe") { mstore(add(add(result,32),offset),value) }
        }
    }
    function _effectiveFee(Route storage r) private view returns(uint16){
        return r.configured?r.feeBps:feeBps;
    }
    function _effectiveSlippage(Route storage r) private view returns(uint16){
        return r.configured?r.slippageGuardBps:defaultSlippageGuardBps;
    }
    function _route(address tokenIn,address tokenOut) private view returns(Route storage r){
        r=routes[_key(tokenIn,tokenOut)];
        require(r.pathway.length>0||simpleRoutes[_key(tokenIn,tokenOut)].length>0,"ROUTE_MISSING");
    }
    function _key(address a,address b) private pure returns(bytes32){
        return keccak256(abi.encode(a,b));
    }
    function _safeTransfer(address token,address to,uint256 value) private {
        (bool ok,bytes memory ret)=token.call(abi.encodeWithSelector(0xa9059cbb,to,value));
        require(ok && (ret.length==0 || (ret.length>=32 && abi.decode(ret,(bool)))),"TRANSFER_FAILED");
    }
    function _safeTransferFrom(address token,address from,address to,uint256 value) private {
        (bool ok,bytes memory ret)=token.call(abi.encodeWithSelector(0x23b872dd,from,to,value));
        require(ok && (ret.length==0 || (ret.length>=32 && abi.decode(ret,(bool)))),"TRANSFER_FROM_FAILED");
    }
    function _safeApprove(address token,address spender,uint256 value) private {
        (bool ok,bytes memory ret)=token.call(abi.encodeWithSelector(0x095ea7b3,spender,value));
        require(ok && (ret.length==0 || (ret.length>=32 && abi.decode(ret,(bool)))),"APPROVE_FAILED");
    }
    function _revertWith(bytes memory reason) private pure {
        if(reason.length==0) revert("TARGET_REVERT");
        assembly ("memory-safe") { revert(add(reason,32),mload(reason)) }
    }
}
