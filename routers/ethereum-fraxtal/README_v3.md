# CurveYield Omni Router — v10 self-contained pool-fee accounting

**Networks:** Ethereum (chain ID 1) and Fraxtal (chain ID 252).  
**Deployable source:** `CurveYieldOmniRouter.sol` only. The previous optional historical reader is not bundled or required.  
**Compiler target:** Solidity 0.8.28, optimizer **1 run**, via IR.  
**Status:** Compile-only; not audited, deployed or tested.

## Architecture

There is **one route representation and one swap accounting path**. Earlier v2 had both a full generic ABI executor and a basic built-in pool executor; the duplicate generic execution path has been removed to reduce the router's bytecode. The basic `setRoute` still accepts a pool type, swap contract, pool ID where needed, minimal pool data and historical-oracle configuration for each hop. No custom ABI patch list is required for supported built-in types.

Uniswap V3's `observe()` tick TWAP remains **inside the router**. The router also calculates its own pool-fee allowances with cached fee snapshots and direct reads of supported Curve pools. No separate pool-fee reader is deployed. Non-V3 routes still require an independently reviewed **historical rate oracle**, which is distinct from a fee reader. Every swap enforces one **aggregate route-wide oracle-derived minimum** on final output while continuing to verify actual token balance changes and full input consumption at every hop. The default router fee is taken once on the final output.

The original CurveYield branded contract header is preserved in the router Solidity file.

**v8 bytecode-preserving refactor (retained in v10):** Curve exchange variants share one ABI encoder with their original selectors; V2/V3 routes share endpoint verification but retain distinct fee/TWAP validation and errors; Curve, Balancer V2 and adapter executors share the same reset-exact-allowance / execute / reset allowance sequence; Curve built-in types use a bounded contiguous ID check; and `guardedMinOut()` and swaps share their gross output minimum calculation. V3 TWAP mathematics remain embedded and unchanged. Exact input spend, output balance, route-wide oracle guard, and authenticated callbacks remain enforced.

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
| 1 | Uniswap V2 / compatible pair | Pair | `abi.encode(uint16 poolFeeBps)` (default 30) | Independently configured historical oracle |
| 2 | Uniswap V3 / compatible pool | Pool | `abi.encode(uint32 twapWindow)` (default 300 seconds; minimum 300) | Internal V3 TWAP when oracleAddress=0 |
| 3 | Uniswap V4 | PoolManager | `abi.encode(PoolKey,bytes hookData)` | External validated historical-price oracle |
| 4 | Curve two-token CryptoSwap | Pool | `abi.encode(uint8 i,uint8 j)` | Validated external historical oracle |
| 5 | Curve TriCrypto | Pool | `abi.encode(uint8 i,uint8 j)` | Validated external historical oracle |
| 6 | Curve legacy StableSwap | Pool | `abi.encode(uint8 i,uint8 j)` | External historical oracle; universal EMA not assumed |
| 7 | Curve StableSwap-NG | Pool | `abi.encode(uint8 i,uint8 j)` | Validated external historical oracle |
| 8 | Balancer V2 Weighted | Balancer V2 Vault | User data, usually empty | External historical oracle, poolId required |
| 9 | Balancer V2 Stable | Balancer V2 Vault | User data, usually empty | External historical oracle, poolId required |
| 1000+ | Additional pool types | Adapter-defined | Adapter-defined | External historical oracle |

Balancer V3 uses a different protocol architecture and is **not** covered by Balancer V2's built-in executor. Nonstandard Curve pools or unusual native-asset/underlying-swap variants are not assumed compatible without a specific additional pool-type adapter.

## Historical oracle configuration (independent of pool-fee accounting)

**Deployment:** Construct `CurveYieldOmniRouter(owner, feeRecipient)` with **two** arguments. There is no mandatory external fee reader, no `feeReader` immutable, and no extra contract required for pool-fee lookup.

The embedded V3 TWAP remains available by leaving a V3 hop's `oracle.oracleAddress` as zero. An empty V3 `poolData` now uses a 300-second TWAP; configured nonempty V3 TWAP windows must be at least 300 seconds. This change shortens the historical averaging interval and increases sensitivity to recent prices compared with the previous 900-second floor. All non-V3 hops **still require** a configured, independently validated external historical-rate oracle; removing the discontinued reader does not remove the router's historical-price guard. The owner must provide a compatible oracle and configure `oracleAddress`, `readFunctionID`, `requiredInputs`, `invert`, and `rateDecimals` for each route hop.

Each external historical oracle must return a nonzero integer rate for one whole input token in whole output tokens with the declared precision (0–18 decimals). A spot swap quote is not an equivalent historical reference. The router retains the existing external oracle selector/argument interface; integrations using another historical source require no new router code.

The former `CurveYieldHistoricalPriceReader.sol` remains in the repository only as an optional legacy source. It is **not** included in the v10 deployment package or compiled by the v10 router-only size workflow, and its pool-fee lookup has been removed. V3's on-router TWAP price mathematics are unchanged; the default and minimum observation windows are now 300 seconds.

## Pool-fee adjustment for route-wide slippage

All recorded fees are used solely to establish the minimum *gross* route output. The CurveYield router's final 0.10% default fee is still charged separately and once.

- **Uniswap V2:** the fee is configured as optional `abi.encode(uint16 feeBps)` in `poolData`. Empty bytes mean 30 bps (0.30%). The pool fee is assumed, not discovered.
- **Uniswap V3:** at `setRoute` or nonempty `setRouteConfig`, the router reads the pool's immutable `fee()` (parts per 1e6) once and records it in the stored hop's `poolId` field. `poolData` continues to contain the optional V3 TWAP window.
- **Uniswap V4 static fee:** `PoolKey.fee` is already inside stored `poolData` (parts per 1e6). There is no additional fee getter or storage. The value `0x800000` signals a dynamic-fee pool, **not** a percentage: dynamic V4 pools receive no fee discount under this implementation. Hook-added charges also do not receive a fee discount.
- **Curve legacy StableSwap and StableSwap-NG:** at route setup, the router reads `fee()` (parts per 1e10) once and stores the base fee in the hop's otherwise unused `poolId`. Before calculating the guarded swap minimum, the router directly calls `dynamic_fee(int128,int128)` on the configured pool. If unavailable for legacy StableSwap, it uses the cached base fee. StableSwap-NG without the expected getter fails closed.
- **Curve TwoCrypto-NG and TriCrypto-NG:** the router calls the pool's live `fee()` (parts per 1e10) when calculating the guarded minimum, not the route-setup value.
- **Balancer V2 and external adapters:** no automatically inferred fee credit is applied. Their normal swap fees still count against the slippage allowance.

`routeHop` returns the stored fee snapshot for V3/Curve stable pools through `poolId`; the router overrides caller-supplied `poolId` for these types. V4 and Balancer `poolId` retain their normal pool-identifier meanings.

**Dynamic-fee limitation:** pre-swap `dynamic_fee(i,j)` and CryptoSwap `fee()` describe current pool state, not an exact guaranteed fee for the eventual amount-specific swap. A trade can alter the fee during its own execution. This approximate allowance can exceed the fee actually charged and therefore weaken the nominal 1.5% default *additional* slippage guarantee. Deployment requires review of the specific Curve implementation and realistic swap sizes. Fee getters are source-bound requirements, not universal interfaces.

The router computes pool-fee allowances internally. No fee-reader deployment, immutable dependency, or external fee-reader call remains. The pool-fee adjustment cannot be disabled per route after deployment; unsupported or incorrectly formatted fee getters can still make a route unusable.

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

This is a router-focused source package, **not** an avKAT package. There are no unrelated vault or governance files. The self-contained router is deployed with `owner` and `feeRecipient`; each chain still requires compatible pools, PoolManager addresses, and independently validated historical-price oracles for non-V3 hops. Native ETH requires wrapping; the built-in swap paths accept ERC20 tokens only.

GitHub compilation does not certify financial safety. The programmatic route configuration may be unsafe if the owner sets wrong token indexes, mismatched pool contracts, reversed oracles, incorrectly scaled rates, inaccurate pool fees, or malicious external adapters. Hooked V4 pools, Curve variants, and both Balancer versions require targeted integration analysis before deployment. No tests are introduced or executed under the existing no-tests instruction.
