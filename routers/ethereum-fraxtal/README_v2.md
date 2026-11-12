# CurveYield Omni Router v2 — Ethereum and Fraxtal

**Implementation branch:** \`ethereum-fraxtal-omni-router-v2\`  
**Status:** Source-only revision. **Compilation, tests, deployments and swap simulations intentionally NOT performed** following user instruction.  
**Scope:** One deployable router contract source, with V2/V3/V4/Curve/Balancer V2 logic built into that router, and a bounded extension interface for additional pool types. No Katana sources or standalone deployed adapters are required by this revision.

## Minimal \`setRoute\`

\`setRoute(address tokenIn, address tokenOut, SimpleHop[] pathway)\`

Each hop is:
\`\`\`solidity
struct SimpleOracle {
    address oracleAddress;       // 0: built-in historical price reader when supported
    bytes4 readFunctionID;       // exact 4-byte historical oracle selector
    bytes requiredInputs;        // abi.encode(...) arguments (optional)
    bool invert;                 // inverse the rate when required
    uint8 rateDecimals;          // oracle rate's decimal precision (0..18)
}
struct SimpleHop {
    uint16 poolType;
    address tokenOut;            // hop destination; next hop input is implied
    address swapContract;        // pool / PoolManager / Balancer Vault
    bytes32 poolId;              // v4 keccak(PoolKey) or Balancer V2 pool ID
    bytes poolData;              // minimal protocol-specific settings, see below
    SimpleOracle oracle;
}
\`\`\`

No per-hop swap write selector, calldata offsets, requiredSwapInputs or manual ABI field patching are required for the built-in pool types. Routing remains multi-hop and atomically guarded. Replacing a route with the same endpoints replaces its prior pathway.

### Built-in pool types

| poolType | Implementation inside router | \`swapContract\` | \`poolData\` (ABI encoded) | Historical oracle |
|---|---|---|---|---|
| 1 | Uniswap V2 and compatible pairs | V2 pair | \`abi.encode(uint16 pairFeeBps)\`; empty defaults to 30 | Built-in 15-minute cumulative TWAP or supplied historical oracle |
| 2 | Uniswap V3 and compatible pools | V3 pool | \`abi.encode(uint32 twapWindow)\`; empty defaults 900 sec | Built-in V3 \`observe()\` TWAP or supplied historical oracle |
| 3 | Uniswap V4 | PoolManager | \`abi.encode(PoolKey, bytes hookData)\` | Required **external historical oracle** |
| 4 | Curve CryptoSwap, volatile 2-token | Curve pool | \`abi.encode(uint8 i,uint8 j)\` | Built-in Curve EMA or supplied historical oracle |
| 5 | Curve TriCrypto | Curve pool | \`abi.encode(uint8 i,uint8 j)\` | Built-in Curve EMA or supplied historical oracle |
| 6 | Curve legacy StableSwap | Curve pool | \`abi.encode(uint8 i,uint8 j)\` | Required **external historical oracle** unless verified pool-specific historical oracle is supplied |
| 7 | Curve StableSwap-NG | Curve pool | \`abi.encode(uint8 i,uint8 j)\` | Built-in Curve EMA or supplied historical oracle |
| 8 | Balancer **V2** Weighted | Balancer V2 Vault | userData bytes, usually empty; \`poolId\` mandatory | Required external historical oracle |
| 9 | Balancer **V2** Stable | Balancer V2 Vault | userData bytes, usually empty; \`poolId\` mandatory | Required external historical oracle |
| 1000+ | Future adapter types | Adapter-specific pool / controller | Adapter-specific bytes | Required external historical oracle |

Balancer V3 weighted/stable pools use a different Vault/Router and Permit2 flow; they are **not** silently treated as Balancer V2. They are a candidate for a later external pool-type adapter. Likewise, nonstandard Curve function signatures or special callback/underlying-asset variants use an advanced route or future extension.

**Uniswap V4:** A V4 pool has a 32-byte PoolId rather than its own contract address. The caller must supply a matching \`PoolKey\` (currencies, fee, tick spacing, hooks) in \`poolData\`. The router verifies \`keccak256(abi.encode(PoolKey)) == poolId\`, then performs PoolManager unlock/swap/sync/settle/take itself. V4 does **not** inherit V3's historical price observations.

**Curve:** Built-in exchange uses \`exchange(int128,int128,uint256,uint256)\` for legacy StableSwap and StableSwap-NG and \`exchange(uint256,uint256,uint256,uint256)\` for CryptoSwap and TriCrypto. Optional receiver, native ETH, metapool underlying swaps and other incompatible variants are **not** assumed supported by the basic path. Token indices are validated against pool \`coins()\`; different pool-specific methods can use \`setRouteAdvanced\` or a future external adapter.

**Balancer:** Built-in Weighted and Stable execution uses the Balancer **V2** Vault \`swap()\` with \`GIVEN_IN\` and a configured \`poolId\`. Only external historical price oracles are permitted for automatic guards. The router verifies pool ID and registered input/output tokens.

## Historical price rules

- \`SimpleOracle.oracleAddress = address(0)\` automatically selects the built-in native oracle for V2, V3, CryptoSwap, TriCrypto and StableSwap-NG when available.
- Built-in V2 pricing uses permissionless \`checkpointV2(pair)\` storage and requires a 900-second to 24-hour observation interval. A checkpoint/keeper path must be maintained.
- V3 uses historical \`observe([window,0])\`, minimum 900 seconds.
- The Curve EMA is normalized as the value of one whole hop-input token in hop-output units. The direct pair rate may be inverted, and multi-coin paths are composed relative to coin 0.
- \`oracleAddress != 0\` invokes \`readFunctionID\` with the ABI-encoded \`requiredInputs\`. The read MUST return a **historical normalized exchange rate for one whole input token**, not \`get_dy\`, a spot price, or an oracle of a different token direction. Provide \`rateDecimals\` and \`invert\` accordingly.
- Uniswap V4, Balancer V2 and legacy Curve StableSwap require externally supplied historical oracles; the router fails closed without one.

## Extensibility — no new router deployment needed for additional pool types

\`setExternalAdapter(uint16 poolType, address adapter)\` is owner-only and only accepts IDs **1000 and above**. Built-in IDs 1–9 cannot be overwritten. A future adapter must implement:

\`\`\`solidity
function executeHop(
    address pool,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minAmountOut,
    bytes32 poolId,
    bytes calldata poolData
) external returns (uint256);
\`\`\`

The router uses a single exact-amount token approval, calls the approved adapter, then revokes allowance. It **never uses delegatecall**. Actual input expenditure and output-token balance increase are verified by the router and must meet the independent per-hop oracle minimum. A new adapter can therefore support another pool ABI, hook design or settlement mechanism without redeploying the primary router. An extension is still a trusted external execution component and must be independently reviewed before a route uses it.

For special contracts not covered by built-in or external adapter types, \`setRouteAdvanced\` retains the existing arbitrary function selector / pre-encoded ABI / runtime argument-substitution pathway.

## Fee, route controls, swaps and reads

- \`setFeeBps\`: default 10 bps (0.10%), max 50 bps (0.50%).
- \`setDefaultSlippageGuardBps\`: default 100 bps (1%), max 300 bps (3%).
- \`setRouteConfig(tokenIn,tokenOut,pathway,routeFeeBps,slippageGuardBps)\`: creates/replaces the basic pathway if nonempty, or updates only its settings if empty; route slippage max 500 bps (5%); route fee max 50 bps.
- \`easyswap(tokenIn,tokenOut,amountIn)\` and \`swapExactInput(tokenIn,tokenOut,amountIn,minNetAmountOut,recipient,deadline)\`: use per-hop historical guard, actual token movement checks, and one final router fee.
- \`price_oracle(tokenIn,tokenOut)\`: 1e18-scaled historical end-to-end exchange rate before fee.
- \`estimate_exact_output(tokenIn,tokenOut,amountIn)\`: historical-oracle estimate net of router fee, **not** an executable spot-output guarantee.
- \`guardedMinOut(tokenIn,tokenOut,amountIn)\`: worst-case net output applying the per-hop slippage allowance and the final router fee.
- \`setRouteAdvanced\` remains for manually ABI-encoded custom pool calls. No \`removeRoute\` entrypoint.

## Source and build status

Source: \`CurveYieldOmniRouter.sol\`. npm dependency: \`@uniswap/v4-core@1.0.2\` for standardized TickMath. No other contracts from avKAT or the Smart-Contracts repository are part of this router's source package.

**Not compiled at the user's direction.** The embedded implementation may approach or exceed the 24,576-byte EIP-170 runtime limit; that cannot be verified until compilation is authorized. No new tests were created or executed.

**Important:** The source is not production-audited. Future compilation, bytecode-size checks and targeted protocol compatibility review should precede deploying or funding the router. Arbitrary external price oracle configurations can invalidate all slippage protection if owners supply a spot-price oracle or an incorrectly oriented/normalized rate.
