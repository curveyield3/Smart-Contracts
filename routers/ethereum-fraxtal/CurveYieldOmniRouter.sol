// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/**
 * @title CurveYieldOmniRouter
 * @notice ERC20 exact-input routes across ABI-compatible V2/V3/V4/Curve execution targets.
 * @dev An owner configures explicit ABI argument templates and historical-rate oracle calls.
 *      For v4 the execution target is an approved PoolManager adapter, not a pool contract.
 *      A route oracle MUST quote one whole tokenIn in whole tokenOut, scaled by 10**rateDecimals.
 *      Configuring current spot-price, get_dy or v4 quoter as an oracle is unsafe.
 *      Solidity cannot resolve an ABI method's name alone: a complete signature is required
 *      (e.g. "price_oracle()", "price_oracle(uint256)").
 */
library RouterFullMath {
    // Full precision floor(a*b / denominator), adapted from the standard mulDiv identity.
    function mulDiv(uint256 a,uint256 b,uint256 denominator) internal pure returns(uint256 result) {
        require(denominator != 0,"DIV_ZERO");
        unchecked {
            uint256 p0; uint256 p1;
            assembly {
                let mm := mulmod(a,b,not(0))
                p0 := mul(a,b)
                p1 := sub(sub(mm,p0),lt(mm,p0))
            }
            if(p1 == 0) return p0 / denominator;
            require(denominator > p1,"MULDIV_OVERFLOW");
            uint256 remainder;
            assembly { remainder := mulmod(a,b,denominator) }
            assembly {
                p1 := sub(p1,gt(remainder,p0))
                p0 := sub(p0,remainder)
            }
            uint256 twos = denominator & (~denominator + 1);
            assembly {
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
        address poolAddress;        // swap execution target; v4 points to a v4 adapter
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

    // Updates a route in-place; never appends a duplicate for the same endpoint pair.
    function setRoute(address tokenIn,address tokenOut,Hop[] calldata pathway) external onlyOwner {
        bytes32 key=_key(tokenIn,tokenOut);
        _replaceRoute(key,tokenIn,tokenOut,pathway);
        emit RouteSet(tokenIn,tokenOut,pathway.length);
    }

    // Nonempty pathway = configure a new route/replace existing route.
    // Empty pathway = reconfigure existing route, without changing its swaps.
    function setRouteConfig(
        address tokenIn,address tokenOut,Hop[] calldata pathway,
        uint16 routeFeeBps,uint16 routeSlippageBps
    ) external onlyOwner {
        require(routeFeeBps<=MAX_FEE_BPS,"ROUTE_FEE_CAP");
        require(routeSlippageBps<=MAX_ROUTE_SLIPPAGE_BPS,"ROUTE_SLIPPAGE_CAP");
        bytes32 key=_key(tokenIn,tokenOut);
        if(pathway.length!=0) {
            _replaceRoute(key,tokenIn,tokenOut,pathway);
            emit RouteSet(tokenIn,tokenOut,pathway.length);
        } else {
            require(routes[key].pathway.length>0,"ROUTE_MISSING");
        }
        Route storage r=routes[key];
        r.feeBps=routeFeeBps;
        r.slippageGuardBps=routeSlippageBps;
        r.configured=true;
        emit RouteConfigSet(tokenIn,tokenOut,routeFeeBps,routeSlippageBps);
    }

    function routeLength(address tokenIn,address tokenOut) external view returns(uint256){
        return routes[_key(tokenIn,tokenOut)].pathway.length;
    }
    function routeFor(address tokenIn,address tokenOut) external view returns(Hop[] memory){
        return routes[_key(tokenIn,tokenOut)].pathway;
    }
    function routeConfig(address tokenIn,address tokenOut) external view returns(uint16 routeFeeBps,uint16 slippageBps,bool configured){
        Route storage r=routes[_key(tokenIn,tokenOut)];
        return(_effectiveFee(r),_effectiveSlippage(r),r.configured);
    }

    // An oracle rate is the quantity of tokenOut per one whole tokenIn, scaled by 1e18.
    // Returns the aggregate historical rate over the complete configured route.
    function price_oracle(address tokenIn,address tokenOut) external view returns(uint256){
        uint256 unitIn=_unit(tokenIn);
        uint256 outputRaw=_estimateGross(_route(tokenIn,tokenOut),unitIn);
        return RouterFullMath.mulDiv(outputRaw,1e18,_unit(tokenOut));
    }
    // Deterministic oracle-derived net estimate. Not an executable spot/price-impact quote.
    function estimate_exact_output(address tokenIn,address tokenOut,uint256 amountIn)
        external view returns(uint256 amount_out)
    {
        Route storage r=_route(tokenIn,tokenOut);
        uint256 gross=_estimateGross(r,amountIn);
        return RouterFullMath.mulDiv(gross,10000-_effectiveFee(r),10000);
    }
    // Worst-case per-hop slippage guard compounded across a mixed route; net of fee.
    function guardedMinOut(address tokenIn,address tokenOut,uint256 amountIn)
        external view returns(uint256 amountOut)
    {
        Route storage r=_route(tokenIn,tokenOut);
        uint256 gross=_estimateGross(r,amountIn);
        for(uint256 i=0;i<r.pathway.length;i++){
            gross=RouterFullMath.mulDiv(gross,10000-_effectiveSlippage(r),10000);
        }
        return RouterFullMath.mulDiv(gross,10000-r.feeBps,10000);
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
                _safeTransfer(hop.tokenIn,hop.poolAddress,currentAmount);
            } else {
                _safeApprove(hop.tokenIn,hop.poolAddress,0);
                _safeApprove(hop.tokenIn,hop.poolAddress,currentAmount);
            }
            bytes memory args=_fill(hop.requiredAbiInputs,hop.writeFields,currentAmount,minimum,hop.tokenIn,hop.tokenOut);
            (bool ok,bytes memory ret)=hop.poolAddress.call(abi.encodePacked(hop.writeFunctionID,args));
            if(!ok) _revertWith(ret);
            if(!hop.transferBeforeCall) _safeApprove(hop.tokenIn,hop.poolAddress,0);
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

    function _replaceRoute(bytes32 key,address tokenIn,address tokenOut,Hop[] calldata pathway) internal {
        require(tokenIn!=address(0)&&tokenOut!=address(0)&&tokenIn!=tokenOut,"BAD_ENDPOINTS");
        require(pathway.length>0 && pathway.length<=MAX_HOPS,"HOP_COUNT");
        address current=tokenIn;
        for(uint256 i=0;i<pathway.length;i++){
            Hop calldata h=pathway[i];
            require(h.tokenIn==current && h.tokenOut!=address(0) && h.tokenIn!=h.tokenOut,"DISCONNECTED");
            require(h.poolAddress.code.length>0 && h.oracleAddress.code.length>0,"UNDEPLOYED_TARGET");
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
        bytes4 selector=bytes4(keccak256(bytes(hop.oracleReadFunctionName)));
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
            assembly { mstore(add(add(result,32),offset),value) }
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
        require(r.pathway.length>0,"ROUTE_MISSING");
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
        assembly { revert(add(reason,32),mload(reason)) }
    }
}
