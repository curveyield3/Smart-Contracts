# CurveYield Omni Router — v7 fee-aware implementation

**Networks:** Ethereum (chain ID 1) and Fraxtal (chain ID 252).  
**Source:** `CurveYieldOmniRouter.sol` and `CurveYieldHistoricalPriceReader.sol` only.  
**Compiler target:** Solidity 0.8.28, optimizer **1 run**, via IR.  
**Status:** Compile-only; not audited, deployed or tested.

## Architecture

There is **one route representation and one swap accounting path**. Earlier v2 had both a full generic ABI executor and a basic built-in pool executor; the duplicate generic execution path has been removed to reduce the router's bytecode. The basic `setRoute` still accepts a pool type, swap contract, pool ID where needed, minimal pool data and historical-oracle configuration for each hop. No custom ABI patch list is required for supported built-in types.

Uniswap V3's `observe()` tick TWAP remains **inside the router**. The external `CurveYieldHistoricalPriceReader` contains the V2 cumulative-price checkpoints, Curve pool EMA rate conversion, and a read-only pool-fee lookup used by the route guard. Other pool types supply their own independently reviewed historical oracle. Every swap enforces one **aggregate route-wide oracle-derived minimum** on final output while continuing to verify actual token balance changes and full input consumption at every hop. The default router fee is taken once on the final output.

The original CurveYield branded contract header is preserved in both Solidity files.

## Simplified route entry points

```solidity
setRoute(address tokenIn, address tokenOut, SimpleHop[] calldata pathway)
setRouteConfig(address tokenIn, address tokenOut, SimpleHop[] calldata pathway,
               uint16 routeFeeBps, uint16 routeSlippageBps)
```

`setRoute` replaces the route for those endpoints; `setRouteConfig` replaces the pathway when supplied a nonempty array, otherwise changes just fee/slippage. There is no `removeRoute`.

```solidity
struct SimpleOracle {
    address oracleAddress; // 0: internal Uniswap V3 TWAP only
    bytes4 readFunctionID; // 4-byte historical-oracle function selector
    bytes requiredInputs;  // ABI-encoded oracle arguments, without selector
    bool invert;           // reverse rate if needed
    uint8 rateDecimals;    // oracle rate's precision, 0..18
}
struct SimpleHop {
    uint16 poolType;
    address tokenOut;
    address swapContract;
    bytes32 poolId;    // V4/Balancer PoolId; V3/Curve stable: fee snapshot written by router
    bytes poolData;    // encoded pool-specific parameters
    SimpleOracle oracle;
}
```

The token input of hop N+1 is inferred from the output of hop N. Each route supports at most 8 hops. The `price_oracle` read returns a 1e18-scaled historical output-token-per-input-token rate; `estimate_exact_output` estimates the output net of router fee, but **does not simulate market price impact**. `guardedMinOut` first discounts the aggregate historical-oracle output by the estimated trading fee of each supported pool, then applies the route-wide slippage allowance once and the router fee once. `price_oracle` and `estimate_exact_output` remain raw-oracle outputs and do **not** include pool trading-fee discounts.

## Built-in pool types

| ID | Pool type | swapContract | poolData | Oracle requirement |
|---|---|---|---|---|
| 1 | Uniswap V2 / compatible pair | Pair | `abi.encode(uint16 poolFeeBps)` (default 30) | External V2 historical-price reader |
| 2 | Uniswap V3 / compatible pool | Pool | `abi.encode(uint32 twapWindow)` (default 900 seconds) | Internal V3 TWAP when oracleAddress=0 |
| 3 | Uniswap V4 | PoolManager | `abi.encode(PoolKey,bytes hookData)` | External validated historical-price oracle |
| 4 | Curve two-token CryptoSwap | Pool | `abi.encode(uint8 i,uint8 j)` | External Curve EMA reader or validated oracle |
| 5 | Curve TriCrypto | Pool | `abi.encode(uint8 i,uint8 j)` | External Curve EMA reader or validated oracle |
| 6 | Curve legacy StableSwap | Pool | `abi.encode(uint8 i,uint8 j)` | External historical oracle; universal EMA not assumed |
| 7 | Curve StableSwap-NG | Pool | `abi.encode(uint8 i,uint8 j)` | External Curve EMA reader or validated oracle |
| 8 | Balancer V2 Weighted | Balancer V2 Vault | User data, usually empty | External historical oracle, poolId required |
| 9 | Balancer V2 Stable | Balancer V2 Vault | User data, usually empty | External historical oracle, poolId required |
| 1000+ | Additional pool types | Adapter-defined | Adapter-defined | External historical oracle |

Balancer V3 uses a different protocol architecture and is **not** covered by Balancer V2's built-in executor. Nonstandard Curve pools or unusual native-asset/underlying-swap variants are not assumed compatible without a specific additional pool-type adapter.

## External V2/Curve price reader

**Deployment order:** deploy `CurveYieldHistoricalPriceReader` first, then construct `CurveYieldOmniRouter(owner, feeRecipient, feeReaderAddress)`. The router's immutable fee-reader address must refer to the updated official reader. Deploy one reader per supported chain. The reader exposes:

```solidity
checkpointV2(address pair)
v2Rate(address pair, address tokenIn, address tokenOut) returns (uint256 rate1e18)
curveRate(address pool, uint16 poolType, uint8 i, uint8 j,
          address tokenIn, address tokenOut) returns (uint256 rate1e18)
poolFee(uint16 poolType, address pool, bytes32 cachedFee, bytes poolData)
    returns (uint256 feeRate1e10)
```

For V2, call `checkpointV2(pair)` permissionlessly and maintain observations: the historical observation used must be at least **900 seconds** old and no more than **86,400 seconds** old. The reader uses Uniswap V2's counterfactual cumulative prices to compute a historical average. A fresh pool without a valid checkpoint cannot be swapped through under the guarded route.

Configure V2 oracle metadata, for example:

```solidity
oracleAddress = deployedHistoricalReader;
readFunctionID = bytes4(keccak256("v2Rate(address,address,address)"));
requiredInputs = abi.encode(pair, tokenIn, tokenOut);
invert = false;
rateDecimals = 18;
```

For supported Curve CryptoSwap / TriCrypto / StableSwap-NG:

```solidity
oracleAddress = deployedHistoricalReader;
readFunctionID = bytes4(keccak256("curveRate(address,uint16,uint8,uint8,address,address)"));
requiredInputs = abi.encode(pool, poolType, i, j, tokenIn, tokenOut);
invert = false;
rateDecimals = 18;
```

The reader composes coin-oracle rates relative to coin 0 (the published Curve EMA convention), validates pool coins/indexes, and returns the correctly oriented whole-token exchange rate. Curve pools with wrapped lending/rebasing assets or different rate conventions need a verified alternative oracle. Never substitute a spot quote for a historical-rate oracle.

For V3 leave oracleAddress=0 to use the embedded `observe([window,0])` historical tick price. A configured external oracle overrides the embedded reader.

For V4 and Balancer, supply a historical oracle that returns one whole input token priced in whole output tokens. V4 lacks V3's native historical observations.

## Pool-fee adjustment for route-wide slippage

All recorded fees are used solely to establish the minimum *gross* route output. The CurveYield router's final 0.10% default fee is still charged separately and once.

- **Uniswap V2:** the fee is configured as optional `abi.encode(uint16 feeBps)` in `poolData`. Empty bytes mean 30 bps (0.30%). The pool fee is assumed, not discovered.
- **Uniswap V3:** at `setRoute` or nonempty `setRouteConfig`, the router reads the pool's immutable `fee()` (parts per 1e6) once and records it in the stored hop's `poolId` field. `poolData` continues to contain the optional V3 TWAP window.
- **Uniswap V4 static fee:** `PoolKey.fee` is already inside stored `poolData` (parts per 1e6). There is no additional fee getter or storage. The value `0x800000` signals a dynamic-fee pool, **not** a percentage: dynamic V4 pools receive no fee discount under this implementation. Hook-added charges also do not receive a fee discount.
- **Curve legacy StableSwap and StableSwap-NG:** at route setup, the router reads `fee()` (parts per 1e10) once and stores the base fee in the hop's otherwise unused `poolId`. Before calculating the guarded swap minimum, the reader calls `dynamic_fee(int128,int128)` on the configured pool. If unavailable for legacy StableSwap, it uses the cached base fee. StableSwap-NG without the expected getter fails closed.
- **Curve TwoCrypto-NG and TriCrypto-NG:** the reader calls the pool's live `fee()` (parts per 1e10) when calculating the guarded minimum, not the route-setup value.
- **Balancer V2 and external adapters:** no automatically inferred fee credit is applied. Their normal swap fees still count against the slippage allowance.

`routeHop` returns the stored fee snapshot for V3/Curve stable pools through `poolId`; the router overrides caller-supplied `poolId` for these types. V4 and Balancer `poolId` retain their normal pool-identifier meanings.

**Dynamic-fee limitation:** pre-swap `dynamic_fee(i,j)` and CryptoSwap `fee()` describe current pool state, not an exact guaranteed fee for the eventual amount-specific swap. A trade can alter the fee during its own execution. This approximate allowance can exceed the fee actually charged and therefore weaken the nominal 1% *additional* slippage guarantee. Deployment requires review of the specific Curve implementation and realistic swap sizes. Fee getters are source-bound requirements, not universal interfaces.

The fee-reader is an immutable deployment dependency. The pool-fee adjustment cannot be disabled on a per-route basis after deployment; unsupported or incorrectly formatted fee getters can make a route unusable.

## Future pool adapters

The owner can call:

```solidity
setExternalAdapter(uint16 poolType, address adapter)
```

Pool-type IDs **1000 and above** are available for future external integrations. IDs 1–9 remain built-in. An adapter implements:

```solidity
executeHop(address pool,address tokenIn,address tokenOut,uint256 amountIn,
           uint256 minAmountOut,bytes32 poolId,bytes calldata poolData)
           returns (uint256);
```

The router approves exactly the hop input amount, makes a normal external call (never `delegatecall`), revokes the approval, and verifies the exact input consumed and output received against the final route-wide historical-price guard. A new pool type does **not** require redeploying the router.

The former `setRouteAdvanced` ABI-patching engine was deliberately removed from the router to eliminate the duplicated and expensive second execution pipeline. Any future general-purpose arbitrary-ABI capability should live in a bounded external adapter using the same simple route engine.

## Owner-controlled rates and swap functions

- `feeBps` defaults to 10 bps (0.10%), owner cap 50 bps (0.50%); routes can override up to 50 bps.
- `defaultSlippageGuardBps` defaults to 150 bps (1.5%); owner default cap 300 bps (3%); routes can override up to 500 bps (5%).
- `easyswap(tokenIn,tokenOut,amountIn)` uses configured automatic protection, sends final output to caller.
- `swapExactInput(tokenIn,tokenOut,amountIn,minNetAmountOut,recipient,deadline)` also respects caller floor and deadline.
- `price_oracle` and `estimate_exact_output` use raw historical oracle quotes; `guardedMinOut` and swaps additionally apply supported pool-fee discounts before slippage.

## Source limitations and production requirements

This is a router-focused source package, **not** an avKAT package. There are no unrelated vault or governance files. The reader must be deployed first and passed into the router constructor. Both contracts must be configured on each chain with compatible pools, PoolManager addresses, and validated historical-price oracles. Native ETH requires wrapping; the built-in swap paths accept ERC20 tokens only.

GitHub compilation does not certify financial safety. The programmatic route configuration may be unsafe if the owner sets wrong token indexes, mismatched pool contracts, reversed oracles, incorrectly scaled rates, inaccurate pool fees, or malicious external adapters. Hooked V4 pools, Curve variants, and both Balancer versions require targeted integration analysis before deployment. No tests are introduced or executed under the existing no-tests instruction.
