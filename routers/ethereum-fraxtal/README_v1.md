# CurveYield Ethereum/Fraxtal Mixed-Pool Router — Implementation v1

**Branch:** `ethereum-fraxtal-omni-router-v1`  
**Chains:** Ethereum (1), Fraxtal (252). This is a **new deployment**; it is not an upgrade to the Katana router.  
**Compiler:** Solidity 0.8.28, optimizer 200 runs, via IR; GitHub Actions compile-only.  
**Status:** Source integrated and compiled. Not deployed, economically validated, audited, or tested.

## Contracts

| Contract | Purpose |
| --- | --- |
| `CurveYieldOmniRouter.sol` | Multi-hop routing, owner configuration, guarded swaps, read functions, fee logic |
| `CurveYieldHistoricalOracleAdapters.sol` | V2 cumulative historical TWAP, V3 native tick-history TWAP |
| `CurveYieldV4ExactInputExecutor.sol` | An ERC20-only v4 PoolManager unlock/swap/settle executor |

The router invokes approved `poolAddress` *execution targets* via their exact ABI function selectors.
For ordinary Curve pools this can be the pool itself; for Uniswap V2/V3 this is commonly the
appropriate router contract; for V4, `poolAddress` is the **V4 executor contract**
(the pool itself is identified by a PoolKey in PoolManager, not a standalone address).

## Owner functions / caps

- `setFeeBps(uint16)`: default universal swap fee, initial 10 bps (0.10%), hard cap 50 bps (0.50%).
- `setDefaultSlippageGuardBps(uint16)`: initial 100 bps (1%), hard cap 300 bps (3%).
- `setFeeRecipient(address)`, `transferOwnership(address)`: owner-only.
- `setRoute(tokenIn,tokenOut,pathway)`: replaces any existing route for that endpoint pair, preserving explicitly configured fee/slippage overrides.
- `setRouteConfig(tokenIn,tokenOut,pathway,feeBps,slippageGuardBps)`: nonempty pathway installs or replaces route; empty pathway reconfigures an existing route. Fee cap 50 bps; route slippage cap 500 bps (5%).
- There is **no removeRoute** function.
- Any route not explicitly set by `setRouteConfig` follows live default fee and default slippage changes.

## Swap and read functions

- `easyswap(tokenIn,tokenOut,amountIn)` executes to `msg.sender` using all configured automatic guards and fee.
- `swapExactInput(tokenIn,tokenOut,amountIn,minNetAmountOut,recipient,deadline)` adds caller minOut and expiration.
- `price_oracle(tokenIn,tokenOut)` is a **1e18-scaled historical exchange rate** for one whole input token, compounded over all hops, before fee and slippage.
- `estimate_exact_output(tokenIn,tokenOut,amountIn)` gives a deterministic **historical-oracle-based estimate net of router fee**. The name does not imply an executable exact-output guarantee: spot price impact and pool fees can change actual execution.
- `guardedMinOut(tokenIn,tokenOut,amountIn)` gives the conservative projected net output after each hop's worst-case slippage guard and final router fee.
- At swap time, each hop applies its oracle-derived minimum to that hop's **actual input amount**, and then enforces the measured output-token balance delta. The router fee is taken **once** on final output.

## Typed mixed-pool pathway and arbitrary ABI templates

Each `Hop` contains:
- `tokenIn`, `tokenOut` (ERC20 only)
- `poolAddress` (actual execution target)
- `writeFunctionID` (bytes4 function selector)
- `requiredAbiInputs` (**already ABI-encoded arguments, without selector**, including any dynamic tails)
- `writeFields` (positions in ABI argument bytes to fill/override dynamically)
- `transferBeforeCall` (true only for direct pools such as V2 pair.swap that need input transferred first)
- `oracleAddress`, `oracleReadFunctionName` (full canonical signature, e.g. `price_oracle(uint256)`; zero-argument names such as `price_oracle` are also accepted)
- `oracleReadFunctionInputs` (already ABI-encoded oracle arguments, without selector)
- `oracleFields` (position patches for oracle argument words)
- `oracleRateDecimals` (precision of the rate returned by the oracle)
- `invertOracle` (invert the quoted direction)

Each `AbiField` has `byteOffset`, `kind`, and `literal` (uint256). Offsets are zero-based
**byte offsets** into the pre-encoded ABI argument buffer, aligned on 32-byte words.
Patches can target nested dynamic ABI data as well as ordinary static arguments.

| `InputKind` | Code | Meaning |
|---|---:|---|
| Literal | 0 | Use the specified literal integer/address word |
| SwapAmount | 1 | The actual quantity being swapped through this hop |
| SlippageGuard | 2 | Minimum acceptable token-out quantity **for this hop** |
| CurrentBlockPlus | 3 | `block.number + literal` — e.g. currentblock+1000 |
| CurrentTimestampPlus | 4 | `block.timestamp + literal` — for time-based deadlines |
| TokenIn | 5 | Input token address |
| TokenOut | 6 | Output token address |
| Router | 7 | The CurveYieldOmniRouter contract address |

The contract only supports **32-byte ABI word substitutions**. Full dynamic ABI
arguments (e.g. `bytes`, `address[]`, `bytes[]`, or tuples) must be encoded into
`requiredAbiInputs` first, with patches applied to fields in that encoding.
The write target must pull its input from the router via ERC20 `transferFrom` (with
a one-transaction exact approval), except when `transferBeforeCall=true`.
The entire input amount must be consumed at each hop. Repeated tokens and cycles are rejected.

### Example ABI templates (illustrative, not production-vetted routes)

**Curve `exchange(int128,int128,uint256,uint256)`:**
`requiredAbiInputs = abi.encode(indexIn,indexOut,uint256(0),uint256(0))`.
Patches `{offset:64, kind:SwapAmount}` and `{offset:96, kind:SlippageGuard}`.
The Curve oracle is, where available, `price_oracle()` or `price_oracle(uint256)`;
its EMA direction and underlying token precision must be checked for that specific pool.

**Uniswap V2 router `swapExactTokensForTokens(uint256,uint256,address[],address,uint256)`:**
The template contains a complete encoded path array. Patch word offsets 0 (SwapAmount),
32 (SlippageGuard), 96 (Router), 128 (CurrentTimestampPlus, desired seconds).
Set `oracleReadFunctionName="quoteRate(address,address,address)"`, oracleAddress to
the V2 history adapter; encode pair, input token and output token in its oracle arguments.

**Uniswap V3 / Sushi V3:** Target an appropriate V3 router whose exact selector and
ABI have been independently confirmed. Use the V3 adapter's
`quoteRate(address,address,address,uint32)` with an initialized pool observation window.

**Uniswap V4:** Use `CurveYieldV4ExactInputExecutor.executeSwap` with an encoded
`PoolKey`, `hookData`, amount and minimum-output patches. Deploy executor only
after the router, using the correct chain-specific PoolManager address. V4 does
**not** expose the V3 native observe/TWAP oracle; configure a separately
validated historical oracle or oracle hook. There is no public official v4
PoolManager verified for Fraxtal in this package.

## Oracle rules and limitations

A hop oracle **must return a reliable time-weighted or exponentially weighted
historical exchange rate of one whole tokenIn denominated in whole tokenOut**,
scaled by `10 ** oracleRateDecimals`. The contract cannot prove the truthfulness,
history, liquidity backing, or semantic correctness of an arbitrary ABI oracle
function. An inappropriate `get_dy` / spot quote / incorrect Curve direction may
cause loss despite technically successful oracle calls.

- The built-in V2 adapter provides historical 15-minute to 24-hour cumulative-price
  rates. `checkpoint(pair)` is permissionless, but must run to create usable
  history; swapping without valid history fails closed.
- The built-in V3 adapter uses `observe([window,0])`, requires at least a 900-second window, and requires the pool to retain
  enough observations. Its normalized rate is scaled by 1e18.
- Curve pool EMA sources must be mapped to the correct coin indices and directional
  conventions. Some Curve markets require additional asset-wrapper/rate normalization.
- V4 requires an external historical oracle; the v4 quoter and pool spot-price state
  **are not substitutes** for historical observations.

## Deployment dependencies

1. Deploy `CurveYieldOmniRouter(owner,feeRecipient)` on Ethereum/Fraxtal.
2. Deploy V2/V3 adapters on networks where needed. Initialize V2 historical observations.
3. For Ethereum V4, validate PoolManager address `0x000000000004444c5dc75cB358380D2e3dE08A90`, then deploy `CurveYieldV4ExactInputExecutor(router,manager)`.
4. On Fraxtal, deploy a V4 executor **only if** a compatible v4 PoolManager and reliable external historical oracle are verified.
5. Configure approved routes and route-specific fees/slippage. Verify every ABI selector, encoded template, oracle orientation/precision, hop token, spender and expected outputs on a fork **before live funds**.

**Security status:** Compilation is not a substitute for validation of generic external calls.
There were **no tests**, live swaps, transactions, or deployments in this implementation.
Do not treat this source as production-audited. Dynamic ABI execution and external
oracle trust introduce meaningful owner-configuration and integration risks.
