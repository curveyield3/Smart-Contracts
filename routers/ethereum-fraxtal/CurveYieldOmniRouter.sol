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
        if(!(denominator != 0)) revert ErrDivZero();
        unchecked {
            uint256 p0; uint256 p1;
            assembly ("memory-safe") {
                let mm := mulmod(a,b,not(0))
                p0 := mul(a,b)
                p1 := sub(sub(mm,p0),lt(mm,p0))
            }
            if(p1 == 0) return p0 / denominator;
            if(!(denominator > p1)) revert ErrMuldivOverflow();
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

error ErrAmountTooLarge();
error ErrApproveFailed();
error ErrBadAddress();
error ErrBadEndpoints();
error ErrBadHop();
error ErrBadOracle();
error ErrBadOwner();
error ErrBadRecipient();
error ErrBadSwap();
error ErrBalancerTokenMismatch();
error ErrBuiltinTypeImmutable();
error ErrCurveCoinMismatch();
error ErrCurveCoinsNotReadable();
error ErrCurveIndex();
error ErrCurveZeroCoin();
error ErrDefaultSlippageCap();
error ErrDivZero();
error ErrDustMinimum();
error ErrExpired();
error ErrExtensionNotActive();
error ErrExternalAdapterMissing();
error ErrExternalHistoricalOracleRequired();
error ErrFeeCap();
error ErrHistoricalReaderRequired();
error ErrHopCount();
error ErrHopInputNotFullySpent();
error ErrRouteSlippage();
error ErrInputBalanceLoss();
error ErrInvalidExtension();
error ErrInvalidTokens();
error ErrInvalidV3Deltas();
error ErrInvalidV4Delta();
error ErrInvertedRateZero();
error ErrMinNet();
error ErrMuldivOverflow();
error ErrNativeOracleNotInvertible();
error ErrNestedV3();
error ErrNestedV4();
error ErrNonstandardInput();
error ErrNotOwner();
error ErrOnlyEthereumFraxtal();
error ErrOracleDataLimit();
error ErrOracleDecimals();
error ErrOracleDust();
error ErrOracleInvalidOutput();
error ErrOracleZeroRate();
error ErrOutputBalanceDecreased();
error ErrPoolDataLimit();
error ErrReentrancy();
error ErrRepeatedToken();
error ErrRouteCycle();
error ErrRouteFeeCap();
error ErrRouteMissing();
error ErrRouteSlippageCap();
error ErrTokenDecimals();
error ErrTargetRevert();
error ErrTransferFailed();
error ErrTransferFromFailed();
error ErrUnauthorizedV3Callback();
error ErrUnauthorizedV4Callback();
error ErrUnknownPoolType();
error ErrV2FeeCap();
error ErrV2InsufficientOutput();
error ErrV2NoLiquidity();
error ErrV2Tokens();
error ErrV3CallbackMissing();
error ErrV3InputDelta();
error ErrV3Observations();
error ErrV3Tokens();
error ErrV3TwapWindow();
error ErrV4CallbackMissing();
error ErrV4HookData();
error ErrV4InputLimit();
error ErrV4Overspend();
error ErrV4PoolId();
error ErrV4Settle();
error ErrV4Sort();
error ErrV4Tokens();
error ErrWrongFinalToken();
error ErrZeroAmount();

interface IOmniERC20 {
    function balanceOf(address) external view returns(uint256);
    function decimals() external view returns(uint8);
}


interface IEmbeddedV2Pair {
    function token0() external view returns(address);
    function token1() external view returns(address);
    function getReserves() external view returns(uint112,uint112,uint32);
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
interface IEmbeddedCurveFee { function fee() external view returns(uint256); }
interface IEmbeddedFeeReader {
    function poolFee(uint16,address,bytes32,bytes calldata) external view returns(uint256);
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
 * @dev Pool-specific execution is embedded. Future pool types may use an
 * external adapter. The token flow and historical-price guard are enforced
 * by this router for the full route.
 */
contract CurveYieldOmniRouter {
    uint16 public constant DEFAULT_SLIPPAGE_BPS = 150;
    uint16 internal constant MAX_DEFAULT_SLIPPAGE_BPS = 300;
    uint16 internal constant MAX_ROUTE_SLIPPAGE_BPS = 500;
    uint16 internal constant MAX_FEE_BPS = 50;
    uint8 internal constant MAX_HOPS = 8;
    uint16 internal constant MAX_CALL_ARGUMENT_BYTES = 2048;

    // Stable built-in types remain part of this router. IDs >= 1000 are reserved
    // for independently deployed, owner-approved future pool-type extensions.
    uint16 internal constant UNISWAP_V2 = 1;
    uint16 internal constant UNISWAP_V3 = 2;
    uint16 internal constant UNISWAP_V4 = 3;
    uint16 internal constant CURVE_CRYPTOSWAP = 4;
    uint16 internal constant CURVE_TRICRYPTO = 5;
    uint16 internal constant CURVE_STABLESWAP = 6;
    uint16 internal constant CURVE_STABLESWAP_NG = 7;
    uint16 internal constant BALANCER_WEIGHTED = 8;
    uint16 internal constant BALANCER_STABLE = 9;
    uint16 internal constant EXTERNAL_TYPE_START = 1000;

    struct SimpleOracle {
        address oracleAddress; // zero invokes only the router's native V3 TWAP reader
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
    mapping(bytes32 => SimpleHop[]) private simpleRoutes;
    mapping(uint16 => address) public externalAdapters;
    address private activeV3Pool;
    bool private activeV3ZeroForOne;
    uint256 private activeV3Amount;
    bool private v3CallbackConsumed;
    address private activeV4Manager;
    bool private v4CallbackConsumed;

    event ExternalAdapterConfigured(uint16 indexed poolType,address indexed adapter);

    struct Route {
        uint16 feeBps;
        uint16 slippageGuardBps;
        bool configured;
    }
    mapping(bytes32=>Route) private routes;

    address public owner;
    address public feeRecipient;
    address public immutable feeReader;
    uint16 public feeBps = 10;              // 0.10% default, capped at 0.50%
    uint16 public defaultSlippageGuardBps = DEFAULT_SLIPPAGE_BPS;
    uint256 private reentrancyStatus=1;
    event RouteSet(address indexed tokenIn,address indexed tokenOut,uint256 hopCount);
    event RouteConfigSet(address indexed tokenIn,address indexed tokenOut,uint16 feeBps,uint16 slippageBps);
    event SwapExecuted(address indexed sender,address indexed tokenIn,address indexed tokenOut,uint256 amountIn,uint256 amountOut);
    event OwnershipTransferred(address indexed oldOwner,address indexed newOwner);

    modifier onlyOwner(){if(!(msg.sender==owner)) revert ErrNotOwner();_;}
    modifier nonReentrant(){if(!(reentrancyStatus==1)) revert ErrReentrancy();reentrancyStatus=2;_;reentrancyStatus=1;}

    constructor(address owner_,address feeRecipient_,address feeReader_){
        if(!(block.chainid==1 || block.chainid==252)) revert ErrOnlyEthereumFraxtal();
        if(!(owner_!=address(0) && feeRecipient_!=address(0) && feeRecipient_!=address(this))) revert ErrBadAddress();
        if(!(feeReader_.code.length>0)) revert ErrBadAddress();
        owner=owner_;
        feeRecipient=feeRecipient_;
        feeReader=feeReader_;
    }

    function transferOwnership(address nextOwner) external onlyOwner {
        if(!(nextOwner!=address(0))) revert ErrBadOwner();
        emit OwnershipTransferred(owner,nextOwner);
        owner=nextOwner;
    }
    function setFeeRecipient(address to) external onlyOwner {
        if(!(to!=address(0) && to!=address(this))) revert ErrBadRecipient();
        feeRecipient=to;
    }
    function setFeeBps(uint16 value) external onlyOwner {
        if(!(value<=MAX_FEE_BPS)) revert ErrFeeCap();
        feeBps=value;
    }
    function setDefaultSlippageGuardBps(uint16 value) external onlyOwner {
        if(!(value<=MAX_DEFAULT_SLIPPAGE_BPS)) revert ErrDefaultSlippageCap();
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
        if(!(routeFeeBps<=MAX_FEE_BPS)) revert ErrRouteFeeCap();
        if(!(routeSlippageBps<=MAX_ROUTE_SLIPPAGE_BPS)) revert ErrRouteSlippageCap();
        bytes32 key=_key(tokenIn,tokenOut);
        if(pathway.length!=0) {
            _replaceSimple(key,tokenIn,tokenOut,pathway);
            emit RouteSet(tokenIn,tokenOut,pathway.length);
        } else {
            if(!(simpleRoutes[key].length>0)) revert ErrRouteMissing();
        }
        routes[key].feeBps=routeFeeBps;
        routes[key].slippageGuardBps=routeSlippageBps;
        routes[key].configured=true;
        emit RouteConfigSet(tokenIn,tokenOut,routeFeeBps,routeSlippageBps);
    }

    // Reserve external types for future pools; extensions cannot delegatecall the router.
    function setExternalAdapter(uint16 poolType,address adapter) external onlyOwner {
        if(!(poolType>=EXTERNAL_TYPE_START)) revert ErrBuiltinTypeImmutable();
        if(!(adapter==address(0)||adapter.code.length>0)) revert ErrInvalidExtension();
        externalAdapters[poolType]=adapter;
        emit ExternalAdapterConfigured(poolType,adapter);
    }

    function routeLength(address tokenIn,address tokenOut) external view returns(uint256){
        bytes32 key=_key(tokenIn,tokenOut);
        return simpleRoutes[key].length;
    }
    // Read route hops individually to avoid an expensive nested-array ABI encoder.
    function routeHop(address tokenIn,address tokenOut,uint256 index) external view returns(SimpleHop memory){
        return simpleRoutes[_key(tokenIn,tokenOut)][index];
    }

    function routeConfig(address tokenIn,address tokenOut) external view returns(uint16 routeFeeBps,uint16 slippageBps,bool configured){
        Route storage r=routes[_key(tokenIn,tokenOut)];
        return(_effectiveFee(r),_effectiveSlippage(r),r.configured);
    }

    // An oracle rate is the quantity of tokenOut per one whole tokenIn, scaled by 1e18.
    // Returns the aggregate historical rate over the complete configured route.
    function price_oracle(address tokenIn,address tokenOut) external view returns(uint256){
        uint256 unitIn=_unit(tokenIn);
        uint256 outputRaw=_estimateRouteGross(tokenIn,tokenOut,unitIn,false);
        return RouterFullMath.mulDiv(outputRaw,1e18,_unit(tokenOut));
    }
    // Deterministic oracle-derived net estimate. Not an executable spot/price-impact quote.
    function estimate_exact_output(address tokenIn,address tokenOut,uint256 amountIn)
        external view returns(uint256 amount_out)
    {
        Route storage r=_route(tokenIn,tokenOut);
        uint256 gross=_estimateRouteGross(tokenIn,tokenOut,amountIn,false);
        return RouterFullMath.mulDiv(gross,10000-_effectiveFee(r),10000);
    }
    // Apply the route-wide historical slippage allowance and fee only once.
    function guardedMinOut(address tokenIn,address tokenOut,uint256 amountIn)
        external view returns(uint256 amountOut)
    {
        Route storage r=_route(tokenIn,tokenOut);
        uint256 guarded=RouterFullMath.mulDiv(
            _estimateRouteGross(tokenIn,tokenOut,amountIn,true),10000-_effectiveSlippage(r),10000
        );
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
        if(!(block.timestamp<=deadline)) revert ErrExpired();
        if(!(amountIn>0 && recipient!=address(0) && recipient!=address(this))) revert ErrBadSwap();
        Route storage r=_route(tokenIn,tokenOut);
        return _swapSimple(tokenIn,tokenOut,amountIn,userMin,recipient,r);
    }

    function _replaceSimple(bytes32 key,address tokenIn,address tokenOut,SimpleHop[] calldata pathway)
        internal
    {
        if(!(reentrancyStatus==1)) revert ErrReentrancy();
        reentrancyStatus=2;
        if(!(tokenIn!=address(0)&&tokenOut!=address(0)&&tokenIn!=tokenOut)) revert ErrBadEndpoints();
        if(!(pathway.length>0 && pathway.length<=MAX_HOPS)) revert ErrHopCount();
        delete simpleRoutes[key];
        address current=tokenIn;
        for(uint256 i=0;i<pathway.length;i++){
            SimpleHop calldata h=pathway[i];
            if(!(h.tokenOut!=address(0)&&h.tokenOut!=current&&h.swapContract.code.length>0)) revert ErrBadHop();
            if(!(current.code.length>0 && h.tokenOut.code.length>0)) revert ErrInvalidTokens();
            if(!(h.poolData.length<=MAX_CALL_ARGUMENT_BYTES)) revert ErrPoolDataLimit();
            if(!(h.oracle.requiredInputs.length<=MAX_CALL_ARGUMENT_BYTES)) revert ErrOracleDataLimit();
            if(!(h.oracle.rateDecimals<=18)) revert ErrOracleDecimals();
            for(uint256 j=0;j<i;j++) if(!(pathway[j].tokenOut!=h.tokenOut)) revert ErrRepeatedToken();
            if(!(tokenIn!=h.tokenOut)) revert ErrRouteCycle();

            if(h.poolType==UNISWAP_V2||h.poolType==UNISWAP_V3){
                IEmbeddedV2Pair pair=IEmbeddedV2Pair(h.swapContract);
                address t0=pair.token0();
                address t1=pair.token1();
                if(!((t0==current&&t1==h.tokenOut)||(t1==current&&t0==h.tokenOut))){
                    if(h.poolType==UNISWAP_V2) revert ErrV2Tokens();
                    revert ErrV3Tokens();
                }
                if(h.poolData.length!=0){
                    if(h.poolType==UNISWAP_V2){
                        if(!(abi.decode(h.poolData,(uint16))<=1000)) revert ErrV2FeeCap();
                    } else if(!(abi.decode(h.poolData,(uint32))>=900)) revert ErrV3TwapWindow();
                }
            } else if(h.poolType==UNISWAP_V4){
                (IEmbeddedV4Manager.PoolKey memory key4,bytes memory hookData)=
                    abi.decode(h.poolData,(IEmbeddedV4Manager.PoolKey,bytes));
                if(!((key4.currency0==current&&key4.currency1==h.tokenOut)||
                        (key4.currency1==current&&key4.currency0==h.tokenOut))) revert ErrV4Tokens();
                if(!(key4.currency0<key4.currency1)) revert ErrV4Sort();
                if(!(keccak256(abi.encode(key4))==h.poolId)) revert ErrV4PoolId();
                if(!(hookData.length<=1024)) revert ErrV4HookData();
            } else if(_isCurve(h.poolType)){
                (uint8 coinIn,uint8 coinOut)=abi.decode(h.poolData,(uint8,uint8));
                if(!(coinIn!=coinOut)) revert ErrCurveIndex();
                if(!(_curveCoin(h.swapContract,coinIn)==current &&
                        _curveCoin(h.swapContract,coinOut)==h.tokenOut)) revert ErrCurveCoinMismatch();
            } else if(h.poolType==BALANCER_WEIGHTED||h.poolType==BALANCER_STABLE){
                (address[] memory tokens,,)=IEmbeddedBalancerV2Vault(h.swapContract).getPoolTokens(h.poolId);
                bool foundInput;bool foundOutput;
                for(uint256 k=0;k<tokens.length;k++){
                    if(tokens[k]==current) foundInput=true;
                    if(tokens[k]==h.tokenOut) foundOutput=true;
                }
                if(!(foundInput&&foundOutput)) revert ErrBalancerTokenMismatch();
            } else {
                if(!(h.poolType>=EXTERNAL_TYPE_START)) revert ErrUnknownPoolType();
                if(!(externalAdapters[h.poolType]!=address(0))) revert ErrExternalAdapterMissing();
            }

            if(h.oracle.oracleAddress!=address(0)){
                if(!(h.oracle.oracleAddress.code.length>0&&h.oracle.readFunctionID!=bytes4(0))) revert ErrBadOracle();
            } else {
                if(!(h.poolType==UNISWAP_V3)) revert ErrExternalHistoricalOracleRequired();
            }
            simpleRoutes[key].push(h);
            if(h.poolType==UNISWAP_V3||h.poolType==CURVE_STABLESWAP||h.poolType==CURVE_STABLESWAP_NG){
                simpleRoutes[key][i].poolId=bytes32(IEmbeddedCurveFee(h.swapContract).fee());
            }
            current=h.tokenOut;
        }
        if(!(current==tokenOut)) revert ErrWrongFinalToken();
        reentrancyStatus=1;
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
        if(!(ok&&out.length>=32)) revert ErrCurveCoinsNotReadable();
        token=abi.decode(out,(address));
        if(!(token!=address(0))) revert ErrCurveZeroCoin();
    }

    function _isCurve(uint16 poolType) internal pure returns(bool){
        return poolType>=CURVE_CRYPTOSWAP&&poolType<=CURVE_STABLESWAP_NG;
    }

    function _swapSimple(
        address tokenIn,address tokenOut,uint256 amountIn,
        uint256 userMin,address recipient,Route storage r
    ) private returns(uint256 net){
        SimpleHop[] storage hops=simpleRoutes[_key(tokenIn,tokenOut)];
        uint256 minimum=RouterFullMath.mulDiv(
            _estimateRouteGross(tokenIn,tokenOut,amountIn,true),10000-_effectiveSlippage(r),10000
        );
        if(!(minimum>0)) revert ErrDustMinimum();
        uint256 originalBalance=IOmniERC20(tokenIn).balanceOf(address(this));
        _safeTransferFrom(tokenIn,msg.sender,address(this),amountIn);
        if(!(IOmniERC20(tokenIn).balanceOf(address(this))==originalBalance+amountIn)) revert ErrNonstandardInput();
        uint256 amount=amountIn;
        for(uint256 i=0;i<hops.length;i++){
            address from=i==0?tokenIn:hops[i-1].tokenOut;
            amount=_swapSimpleHop(hops[i],from,amount);
        }
        if(!(amount>=minimum)) revert ErrRouteSlippage();
        uint256 protocolFee=RouterFullMath.mulDiv(amount,_effectiveFee(r),10000);
        net=amount-protocolFee;
        if(!(net>=userMin)) revert ErrMinNet();
        if(protocolFee!=0) _safeTransfer(tokenOut,feeRecipient,protocolFee);
        _safeTransfer(tokenOut,recipient,net);
        if(!(IOmniERC20(tokenIn).balanceOf(address(this))>=originalBalance)) revert ErrInputBalanceLoss();
        emit SwapExecuted(msg.sender,tokenIn,tokenOut,amountIn,net);
    }

    function _swapSimpleHop(
        SimpleHop storage hop,address tokenIn,uint256 amount
    ) private returns(uint256 outAmount){
        address tokenOut=hop.tokenOut;
        uint256 beforeIn=IOmniERC20(tokenIn).balanceOf(address(this));
        uint256 beforeOut=IOmniERC20(tokenOut).balanceOf(address(this));
        _executeSimpleHop(hop,tokenIn,amount);
        uint256 afterIn=IOmniERC20(tokenIn).balanceOf(address(this));
        uint256 afterOut=IOmniERC20(tokenOut).balanceOf(address(this));
        if(!(afterIn<=beforeIn && beforeIn-afterIn==amount)) revert ErrHopInputNotFullySpent();
        if(!(afterOut>beforeOut)) revert ErrOutputBalanceDecreased();
        outAmount=afterOut-beforeOut;
    }

    function _executeSimpleHop(SimpleHop storage hop,address tokenIn,uint256 amount) internal {
        uint16 t=hop.poolType;
        if(t==UNISWAP_V2){
            _executeV2(hop,tokenIn,amount);
        } else if(t==UNISWAP_V3){
            _executeV3(hop,tokenIn,amount);
        } else if(t==UNISWAP_V4){
            _executeV4(hop,tokenIn,amount);
        } else {
            address spender=hop.swapContract;
            if(t>=EXTERNAL_TYPE_START){
                spender=externalAdapters[t];
                if(!(spender!=address(0)&&spender.code.length>0)) revert ErrExtensionNotActive();
            }
            _safeApprove(tokenIn,spender,0);
            _safeApprove(tokenIn,spender,amount);
            if(_isCurve(t)){
                _executeCurve(hop,tokenIn,amount);
            } else if(t==BALANCER_WEIGHTED||t==BALANCER_STABLE){
                _executeBalancerV2(hop,tokenIn,amount);
            } else {
                IExternalRouterHop(spender).executeHop(
                    hop.swapContract,tokenIn,hop.tokenOut,amount,0,hop.poolId,hop.poolData
                );
            }
            _safeApprove(tokenIn,spender,0);
        }
    }

    function _executeV2(SimpleHop storage hop,address tokenIn,uint256 amount) private {
        IEmbeddedV2Pair pair=IEmbeddedV2Pair(hop.swapContract);
        (uint112 r0,uint112 r1,)=pair.getReserves();
        if(!(r0>0&&r1>0)) revert ErrV2NoLiquidity();
        bool token0In=tokenIn==pair.token0();
        uint256 reserveIn=token0In?uint256(r0):uint256(r1);
        uint256 reserveOut=token0In?uint256(r1):uint256(r0);
        uint16 bps=hop.poolData.length==0?30:abi.decode(hop.poolData,(uint16));
        uint256 netIn=amount*(10000-uint256(bps));
        uint256 output=RouterFullMath.mulDiv(netIn,reserveOut,reserveIn*10000+netIn);
        if(!(output!=0)) revert ErrV2InsufficientOutput();
        _safeTransfer(tokenIn,hop.swapContract,amount);
        pair.swap(token0In?0:output,token0In?output:0,address(this),"");
    }

    function _executeCurve(SimpleHop storage hop,address tokenIn,uint256 amount) private {
        (uint8 i,uint8 j)=abi.decode(hop.poolData,(uint8,uint8));
        bytes4 selector=hop.poolType==CURVE_STABLESWAP||hop.poolType==CURVE_STABLESWAP_NG
            ?bytes4(keccak256("exchange(int128,int128,uint256,uint256)"))
            :bytes4(keccak256("exchange(uint256,uint256,uint256,uint256)"));
        bytes memory payload=abi.encodeWithSelector(selector,uint256(i),uint256(j),amount,0);
        (bool ok,bytes memory reason)=hop.swapContract.call(payload);
        if(!ok) _revertWith(reason);
    }

    function _executeBalancerV2(SimpleHop storage hop,address tokenIn,uint256 amount) private {
        IEmbeddedBalancerV2Vault vault=IEmbeddedBalancerV2Vault(hop.swapContract);
        IEmbeddedBalancerV2Vault.SingleSwap memory single=IEmbeddedBalancerV2Vault.SingleSwap({
            poolId:hop.poolId,kind:IEmbeddedBalancerV2Vault.SwapKind.GIVEN_IN,
            assetIn:tokenIn,assetOut:hop.tokenOut,amount:amount,userData:hop.poolData
        });
        IEmbeddedBalancerV2Vault.FundManagement memory funds=IEmbeddedBalancerV2Vault.FundManagement({
            sender:address(this),fromInternalBalance:false,recipient:payable(address(this)),toInternalBalance:false
        });
        vault.swap(single,funds,0,block.timestamp);
    }


    // Native Uniswap V3 support. Unlike a helper adapter, this router itself
    // authenticates the pool's callback and transfers the actual owed tokens.
    function _executeV3(SimpleHop storage hop,address tokenIn,uint256 amount) private {
        if(!(activeV3Pool==address(0))) revert ErrNestedV3();
        bool zeroForOne=tokenIn<hop.tokenOut;
        if(!(amount<=uint256(type(int256).max))) revert ErrAmountTooLarge();
        activeV3Pool=hop.swapContract;
        activeV3ZeroForOne=zeroForOne;
        activeV3Amount=amount;
        v3CallbackConsumed=false;
        IEmbeddedV3Pool(hop.swapContract).swap(
            address(this),zeroForOne,int256(amount),
            zeroForOne?uint160(4295128740):uint160(1461446703485210103287273052203988822378723970341),""
        );
        if(!(v3CallbackConsumed)) revert ErrV3CallbackMissing();
        activeV3Pool=address(0);
        activeV3Amount=0;
    }

    function uniswapV3SwapCallback(int256 amount0Delta,int256 amount1Delta,bytes calldata)
        external
    {
        if(!(reentrancyStatus==2 && msg.sender==activeV3Pool&&
                activeV3Pool!=address(0)&&!v3CallbackConsumed)) revert ErrUnauthorizedV3Callback();
        if(!((amount0Delta>0&&amount1Delta<=0)||(amount1Delta>0&&amount0Delta<=0))) revert ErrInvalidV3Deltas();
        bool zeroForOne=activeV3ZeroForOne;
        int256 owed=zeroForOne?amount0Delta:amount1Delta;
        if(!(owed>0&&uint256(owed)<=activeV3Amount)) revert ErrV3InputDelta();
        v3CallbackConsumed=true;
        address inputToken=zeroForOne
            ?IEmbeddedV3Pool(msg.sender).token0()
            :IEmbeddedV3Pool(msg.sender).token1();
        _safeTransfer(inputToken,msg.sender,uint256(owed));
    }

    // Uniswap v4 pools live inside a PoolManager, not at individual pool addresses.
    // poolId = keccak256(abi.encode(PoolKey)); poolData = abi.encode(PoolKey,hookData).
    function _executeV4(SimpleHop storage hop,address tokenIn,uint256 amount) private {
        if(!(activeV4Manager==address(0))) revert ErrNestedV4();
        if(!(amount<=uint256(uint128(type(int128).max)))) revert ErrV4InputLimit();
        (IEmbeddedV4Manager.PoolKey memory key4,bytes memory hookData)=
            abi.decode(hop.poolData,(IEmbeddedV4Manager.PoolKey,bytes));
        // PoolKey/PoolId matching was already validated and stored by setRoute.
        activeV4Manager=hop.swapContract;
        v4CallbackConsumed=false;
        IEmbeddedV4Manager(hop.swapContract).unlock(
            abi.encode(key4,tokenIn,hop.tokenOut,amount,hookData)
        );
        if(!(v4CallbackConsumed)) revert ErrV4CallbackMissing();
        activeV4Manager=address(0);
    }

    function unlockCallback(bytes calldata payload) external returns(bytes memory){
        if(!(reentrancyStatus==2 && msg.sender==activeV4Manager &&
                activeV4Manager!=address(0)&&!v4CallbackConsumed)) revert ErrUnauthorizedV4Callback();
        v4CallbackConsumed=true;
        (IEmbeddedV4Manager.PoolKey memory key4,address tokenIn,address tokenOut,
            uint256 amount,bytes memory hookData)=abi.decode(payload,
                (IEmbeddedV4Manager.PoolKey,address,address,uint256,bytes));
        if(!((tokenIn==key4.currency0&&tokenOut==key4.currency1)||
                (tokenIn==key4.currency1&&tokenOut==key4.currency0))) revert ErrV4Tokens();
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
        if(!(inputDelta<0 && outputDelta>0)) revert ErrInvalidV4Delta();
        uint256 owed=uint256(-int256(inputDelta));
        uint256 out=uint256(int256(outputDelta));
        if(!(owed<=amount)) revert ErrV4Overspend();
        manager.sync(tokenIn);
        _safeTransfer(tokenIn,msg.sender,owed);
        if(!(manager.settle()==owed)) revert ErrV4Settle();
        manager.take(tokenOut,address(this),out);
        return abi.encode(out);
    }


    // V3 native observe() provides a historical cumulative tick.
    function _v3HistoricalQuote(SimpleHop storage hop,address tokenIn,uint256 amount)
        private view returns(uint256)
    {
        uint32 window=hop.poolData.length==0?900:abi.decode(hop.poolData,(uint32));
        // The minimum window is validated once when setRoute installs this hop.
        uint32[] memory secondsAgo=new uint32[](2);
        secondsAgo[0]=window;
        (int56[] memory cumulative,)=IEmbeddedV3Pool(hop.swapContract).observe(secondsAgo);
        if(!(cumulative.length==2)) revert ErrV3Observations();
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

    function _simpleOracleQuote(SimpleHop storage hop,address tokenIn,uint256 amount)
        private view returns(uint256 output)
    {
        if(!(amount>0)) revert ErrZeroAmount();
        if(hop.oracle.oracleAddress==address(0) && hop.poolType==UNISWAP_V3){
            if(!(!hop.oracle.invert)) revert ErrNativeOracleNotInvertible();
            return _v3HistoricalQuote(hop,tokenIn,amount);
        }
        if(!(hop.oracle.oracleAddress!=address(0))) revert ErrHistoricalReaderRequired();
        (bool ok,bytes memory out)=hop.oracle.oracleAddress.staticcall(
            abi.encodePacked(hop.oracle.readFunctionID,hop.oracle.requiredInputs)
        );
        if(!ok) _revertWith(out);
        if(!(out.length>=32)) revert ErrOracleInvalidOutput();
        uint256 rate=abi.decode(out,(uint256));
        uint256 precision=10**uint256(hop.oracle.rateDecimals);
        if(!(rate>0)) revert ErrOracleZeroRate();
        if(hop.oracle.invert){
            rate=RouterFullMath.mulDiv(precision,precision,rate);
            if(!(rate>0)) revert ErrInvertedRateZero();
        }
        uint256 inputUnit=_unit(tokenIn);
        uint256 outputUnit=_unit(hop.tokenOut);
        output=RouterFullMath.mulDiv(RouterFullMath.mulDiv(amount,rate,precision),
                                    outputUnit,inputUnit);
        if(!(output>0)) revert ErrOracleDust();
    }

    function _estimateRouteGross(address tokenIn,address tokenOut,uint256 amount,bool adjustPoolFees)
        private view returns(uint256)
    {
        SimpleHop[] storage hops=simpleRoutes[_key(tokenIn,tokenOut)];
        if(!(hops.length!=0)) revert ErrRouteMissing();
        for(uint256 i=0;i<hops.length;i++){
            address input=i==0?tokenIn:hops[i-1].tokenOut;
            amount=_simpleOracleQuote(hops[i],input,amount);
            if(adjustPoolFees){
                uint256 poolFee=IEmbeddedFeeReader(feeReader).poolFee(
                    hops[i].poolType,hops[i].swapContract,hops[i].poolId,hops[i].poolData
                );
                amount=RouterFullMath.mulDiv(amount,1e10-poolFee,1e10);
            }
        }
        return amount;
    }
    function _unit(address token) private view returns(uint256){
        uint8 d=IOmniERC20(token).decimals();
        if(!(d<=36)) revert ErrTokenDecimals();
        return 10**uint256(d);
    }
    function _effectiveFee(Route storage r) private view returns(uint16){
        return r.configured?r.feeBps:feeBps;
    }
    function _effectiveSlippage(Route storage r) private view returns(uint16){
        return r.configured?r.slippageGuardBps:defaultSlippageGuardBps;
    }
    function _route(address tokenIn,address tokenOut) private view returns(Route storage r){
        bytes32 key=_key(tokenIn,tokenOut);
        r=routes[key];
        if(simpleRoutes[key].length==0) revert ErrRouteMissing();
    }
    function _key(address a,address b) private pure returns(bytes32){
        return keccak256(abi.encode(a,b));
    }
    function _safeTransfer(address token,address to,uint256 value) private {
        (bool ok,bytes memory ret)=token.call(abi.encodeWithSelector(0xa9059cbb,to,value));
        if(!(ok && (ret.length==0 || (ret.length>=32 && abi.decode(ret,(bool)))))) revert ErrTransferFailed();
    }
    function _safeTransferFrom(address token,address from,address to,uint256 value) private {
        (bool ok,bytes memory ret)=token.call(abi.encodeWithSelector(0x23b872dd,from,to,value));
        if(!(ok && (ret.length==0 || (ret.length>=32 && abi.decode(ret,(bool)))))) revert ErrTransferFromFailed();
    }
    function _safeApprove(address token,address spender,uint256 value) private {
        (bool ok,bytes memory ret)=token.call(abi.encodeWithSelector(0x095ea7b3,spender,value));
        if(!(ok && (ret.length==0 || (ret.length>=32 && abi.decode(ret,(bool)))))) revert ErrApproveFailed();
    }
    function _revertWith(bytes memory reason) private pure {
        if(reason.length==0) revert ErrTargetRevert();
        assembly ("memory-safe") { revert(add(reason,32),mload(reason)) }
    }
}
