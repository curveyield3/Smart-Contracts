# MARKET DISCOVERY INTEGRATION CHECKLIST — v8

> **Scope:** Ethereum mainnet, verified single-ERC-20 deposit assets and source-specific opportunity discovery
> **Status:** Worker v176 deployed November 18, 2026. Smart-contract changes remain paused.
> **Market data:** All counts below were observed at a fully warmed native-source snapshot. Edge caches can become cold and report `partial:true` until refreshed.

## Quality-first and expanded asset selection — Worker v175–v176

**Live production verification:** [CurveYield opportunities](https://markets.curveyield.org/opportunities) and [native API status](https://markets.curveyield.org/api/opportunities/status). Before the v176 change, all 708 qualifying listings remained accessible, with no observed source failures or coverage warnings after warming the providers. The backend now supports exact `minYield` (reported annual percentage) and `minTvl` (USD) filters; the UI defaults to 5%+ reported yield and $1M+ supplied TVL.

| Discovery tier | Live matching snapshot | Purpose |
| --- | ---: | --- |
| Default: ≥5% reported annual yield, ≥$1M TVL | **125** | Depth-first higher-yield shortlist |
| Higher yield: ≥8% reported annual yield, ≥$1M TVL | **46** | Higher-return shortlist, no claim of lower risk |
| Exploratory: ≥5% reported annual yield, ≥$100K TVL | **198** | More speculative smaller markets |
| All qualifying source-validated listings | **708** | Complete market catalog (historical lower bound >1% and >$100 TVL) |

**The 25-token deposit-asset selector** uses immutable Ethereum contract addresses and filters exclusively by the asset users actually deposit, not its collateral or the vault’s underlying strategy. Its entries cover USDC, USDT, WETH, WBTC, wstETH, DAI, USDS, PYUSD, RLUSD, AUSD, crvUSD, frxUSD, GHO, USDe, EURC, USDG, apxUSD, BOLD, cbBTC, tBTC, weETH, rETH, cbETH, fxUSD, sUSDe. Selecting a token with no qualifying rate correctly returns an empty shortlist. These **25 selectable tokens are not 25 independently verified markets or protocols**.

**Rate quality disclosure:** The catalog does not equate TVL to available withdrawal liquidity and does not assign a safety score based on TVL. APR and APY retain source-specific labels; rates are not directly interchangeable. Reported annual yields above **30%** now show an extreme-rate warning to encourage source, incentive, duration and withdrawal checks. Even the ≥$1M threshold is not liquidity proof. Snapshot yields may be stale, rapidly variable or dominated by promotional rewards. The original all-market view remains available.

### Actual opportunity gaps, not a mandate to inflate the listing count

| Deposit token | Qualified earlier-snapshot listings | ≥5% yield AND ≥$100K TVL | Discovery interpretation |
| --- | ---: | ---: | --- |
| USDC | ~277 | ~121 | Already saturated; deprioritize more small identical pools |
| WETH | ~52 | 2 | Core yield coverage is thin after filtering |
| WBTC | 10 | 1 | Severe shortage of meaningfully sized higher-yield lending |
| wstETH | 1 | 0 | Severe shortage; lending income is low despite inherent staking exposure |
| DAI | 18 | 4 | Can benefit from selective higher-quality savings |
| USDS | 12 | 4 | Native Sky covered; seek sources beyond identical strategies |
| frxUSD | 9 | 2 | Fraxlend and frxUSD-specific yield sources should be verified carefully |
| GHO | 4 | 1 | Limited qualifying lender depth |
| EURC | 13 | 0 | No demonstrated strong-yield source at current threshold |
| RLUSD | 16 | 2 | Yield outliers need concentration and reward scrutiny |
| PYUSD | ~27 | ~7 | Broader coverage but return is clustered in select sources |
| AUSD | 19 | 7 | Broader, mostly Morpho; distinguish borrow-collateral from deposit asset |

*Counts in this asset matrix come from paginated reads of a changing catalog across multiple cache snapshots and are indicative, not a single transactionally consistent full snapshot. The exact quality-tier totals above were verified from a fully refreshed 708-entry aggregate.*

### New upstream sources screened, not published without proven eligibility

- **Euler Earn:** Official Ethereum Earn API `https://v3.euler.finance/v3/earn/vaults?chainId=1&limit=100` exposed 12 records. One visible, explorable USDC vault (`InfiniFi Markets`, `0xB4a2fC3adAF3BfA8FCBA2A6FDAA200De106B8825`) advertised roughly **9.23%** current and 7-day APY at ~$142K TVL. Direct Ethereum reads verified underlying USDC, ERC-4626 `totalAssets` and positive `maxDeposit`, but the vault held **zero idle USDC**. No immediate same-asset exit was demonstrated; it was **not added**. Zero idle does not by itself prove all withdrawals impossible, but third-party strategy withdrawals require proof.
- **Fraxlend:** Official registry and Ethereum pool inventory already exist in the Worker but remain quarantined pending exact official pair-specific interaction links, pair-level deposit permission/whitelist, direct same-asset withdrawal liquidity and correct APR. Fraxlend's active frxUSD/sfrxETH lender appears approximately 3.5% and $4.6M in external trackers, not sufficiently high to bypass these checks. Frax Facts analytics links are not automatically working deposit pages.
- **Aave USDe headline rewards:** November 2026 Aave discussion explains advertised approximately 5.25% USDe returns depend mainly on separate Merkl campaign rewards while native lending supply interest is around 0.1%. Never replace native supply APY with advertising-inclusive temporary campaign rates without source-bound claim/reward handling. Reference: https://governance.aave.com/t/risk-stewards-november-2026-stablecoin-interest-rate-adjustments/26414
- **cbBTC/tBTC/weETH/rETH:** Some are widely supplied as **collateral** but pay near-zero native supply interest on Ethereum. A collateral pool with large TVL is not a qualifying lending opportunity to deposit that collateral token itself. Lending vaults and routes must identify the exact deposit token.
- **Frax sFRXUSD:** The Ethereum staking/unstaking route uses crosschain lockbox components according to official Frax docs, so its headline return is not an automatically compatible single-call ERC-4626 deposit/withdraw route. No adapter changes are authorized.
- **Ethena sUSDe:** Staking yield must not be misrepresented as immediately withdrawable when the underlying redemption path has a cooldown.

**Next source work:** prioritize executable source-native, fee-free, independently verifiable immediate-withdrawal markets for WBTC, WETH, wstETH, frxUSD, GHO, RLUSD and new BTC/ETH derivatives. Require source-bound APR/APY, recent onchain position identity and balances, exact asset-specific dapp links, deposit enablement, and verified withdrawal liquidity. Record zero qualifying findings explicitly, rather than lowering the bar or importing collateral-token yield.

---

## Previous verified integration checkpoint (v7; retained for provenance)


> **Scope:** Ethereum mainnet · single-token ERC-20 deposits only
> **Document status:** Verified protocol-discovery checkpoint; no smart-contract modifications or execution testing in this round.
> **Historical Worker deployment:** v170 (November 18, 2026), superseded by the v176 checkpoint above; v168–v169 source integrations were preserved by concurrent UI/Fraxtal updates.
> **Live aggregate verification:** [Markets status](https://markets.curveyield.org/api/opportunities/status) and [opportunities](https://markets.curveyield.org/opportunities).

## Current integration checkpoint — November 18, 2026 (Worker v170)

**Verified combined production state after refreshing all 14 isolated source caches:** **708 qualifying opportunities** in **20 protocol/version categories**; **708 source-bound market-specific links**, **0 missing links**, **0 source failures**, **0 coverage warnings**, `partial:false`. Link counts are route-validator results; they are not individual wallet-executed deposit/withdrawal verification. Baseline before these four incremental additions: 704 qualified.

| Collector | Inventory / gate | Qualifying markets | Deposit tokens | Verification and limitations |
| --- | --- | ---: | --- | --- |
| Spark Savings V2 (extended in v166) | Official registry plus existing savings REST; on-chain ERC-4626 asset, totalAssets, maxDeposit, per-second VSR for spETH/spPYUSD; actual idle underlying balance | **4 total, +2 added** | USDC, USDT, WETH, PYUSD | spETH 1.85% APY, ~$48.93m TVL, ~$4.45m idle WETH; spPYUSD 3.80% APY, ~$36.5k TVL, ~$36.5k idle PYUSD. Exact product-specific Spark savings routes. Larger withdrawals may need liquidity intents. |
| Harvest Finance (integrated v169) | 117 Ethereum records from official Harvest API; 13 active mainstream assets with >1% estimated APY and >$100 TVL; Ethereum Multicall3 checks ERC-4626 asset, totalAssets, maxDeposit and idle underlying; 11 failed liquidity/TVL matching | **2 added** | USDT, WETH | Steakhouse Prime V2 USDT 2.58% APY, ~$183.9k TVL / ~$5.35k idle; KPK Yield V2 WETH 2.48% APY, ~$165.1k TVL / ~$4.88k idle. Both exact Harvest supply/revert dapp pages personally checked. |
| Silo V3 (v151) | 276 Ethereum market records plus 4 managed vaults; only source-validated managed vaults | **1** | USDC | Optima managed vault, exact Silo product URL; isolated markets excluded without proven frontend + immediate withdrawal |
| Gearbox passive pools (v145) | 16 official Ethereum passive pools; onchain rates, fee, capacity and idle liquidity | **1** | WBTC | Instant APR and 7d trailing app APY differ; only verified-qualified market published |
| Sky Savings (v155) | sUSDS SSR and sDAI DSR, Ethereum onchain rates, ERC-4626 asset/capacity | **2** | USDS, DAI | Both product-specific Spark-hosted Sky pages |

**Harvest disqualification:** the attractive `ipor_BTCD_WBTC` Harvest vault (reported 5.5% APY, ~$6.5k TVL) was identified and its exact UI checked, **but not published** because it failed the minimum immediately idle underlying liquidity / onchain TVL reconciliation gates. Do not interpret 5.5% as usable WBTC vault capacity.

**Economic and execution caveats:** >1% yield is an eligibility snapshot, not a guaranteed realized rate; count of qualifying markets does not prove market exhaustiveness. An ERC-4626 ABI plus idle underlying balance is not a successful execution of a full withdrawal; exact-asset synchronous withdrawal remains subject to runtime conditions. The shared OmniAdapter has **not** been modified, compiled, deployed, or fork-tested in this discovery-only round. Do not mark these markets compatible with live Morpho Vault V2 allocations without separate authorization and verification.

**Source-specific diagnostics:** `?source=spark`, `harvest`, `silo`, `sky`, `gearbox` on `/api/opportunities/status`; standard cache TTL 900 seconds. Cold caches report explicit coverage gaps until individually refreshed; zero-gap status is a warm-source snapshot. Harvest qualifies only exact asset-address verified Ethereum single-ERC20 vaults with >=$1,000 idle liquidity and >=0.5% of onchain TVL idle. Price quotes and source TVL are rechecked, with fail-closed outcomes.

**Next integrations (no contract changes):** pursue additional native, liquid, exact-same-token ERC-4626 sources with emphasis on WBTC and wstETH. Exclude multi-token LPs, token conversions, queued/locked redemption, missing exact dapp pages, and 0/near-0 yield. Revalidate existing collector completeness rather than increasing names without verified listings.

---

## Historical checkpoints and original integration inventory


> **Scope:** Ethereum mainnet · single-token ERC-20 deposits only  
> **Document status:** Live source-specific verification checkpoint, plus historical implementation inventory; not a claim of exhaustive wallet-interaction testing.  
> **Historical verified Worker deployment:** v145 (November 18, 2026); now superseded by the current v170 checkpoint above. The shared OmniAdapter is separately maintained on its dedicated branch.

## Widely used vault assets — priority checkpoint (Worker v145, 2026-11-18)

**Priority principle:** Expand useful, single-ERC20, immediately withdrawable deposits for **USDC, USDT, WETH, WBTC, DAI, USDS and wstETH**, prioritizing assets with the fewest real options (WBTC and wstETH) and protocols with live yields above 1%, sufficient accessible liquidity, verified asset identity, and exact interactive market pages. The existing Morpho Vault V2 OmniAdapter's shared execution modes should be reused wherever compatible, without new per-protocol adapters.

**Verified live asset counts (full combined API, after source refresh):**

| Asset | Qualified Ethereum options at v145 | Operational priority |
| --- | ---: | --- |
| USDC | 275 | Add only genuinely distinct liquid options; baseline broad |
| USDT | 76 | Expand selective high-quality lenders |
| WETH | 51 | More fee-free, immediately liquid alternatives |
| DAI | 17 | Add common-asset savings and lending |
| USDS | 11 | Add fee-free savings and lending where confirmed |
| WBTC | **10** | **High priority:** limited options; v145 added one Gearbox pool |
| wstETH | **2** | **High priority:** very limited options; separate IPOR feed gained a new candidate during refresh |

**New protocol: Gearbox passive Ethereum ERC-4626 pools — Worker v145.** The dedicated `?source=gearbox` endpoint enumerated **16** Ethereum mainnet pool records from [Gearbox's official pool registry](https://github.com/Gearbox-protocol/static/blob/main/src/pools/index.ts), decoded **16**, obtained price/decimal data for **16**, rejected **15** under the current APR/liquidity/zero-fee criteria, and published **1** qualifying pool. All underlying, TVL, current supply APR (RAY, incentives excluded), `maxDeposit`, `availableLiquidity` and `withdrawFee` are read from live Ethereum contracts. The pipeline requires APR above 1%, more than $100 in TVL, **at least $1,000 of unborrowed immediately available USD liquidity**, at least **0.5% of TVL liquid**, and a **zero withdrawal fee**. These are conservative discovery filters, not guarantees of withdrawability for arbitrarily large positions.

- **New WBTC option:** Gearbox Gami Labs WBTC pool `0x683FAf5BAFd88d4c383cCaf3d61C26AF2E164409`, ~**1.458% current instantaneous onchain supply APR**, ~$208,187 TVL and ~$50,811 unborrowed liquidity on the sampled block.
- **Verified exact dapp page:** [Gearbox Gami Labs WBTC Deposit / Withdraw](https://app.gearbox.finance/earn/lp/1/0x683FAf5BAFd88d4c383cCaf3d61C26AF2E164409). Its app displayed **0.54% trailing 7-day net APY** during inspection; this **is not the same metric or measurement window** as the instant onchain 1.458% APR. Preserve both labels, never represent the instantaneous rate as a 7-day average.
- **Adapter:** Standard Gearbox passive pools implement ERC-4626 and document immediate withdrawals **subject to available unborrowed liquidity**. They are candidates for the shared OmniAdapter's ERC-4626 mode; no vault-specific allocation or wallet transaction was executed.

**Unified API verification:** After restoring warm source caches, `GET /api/opportunities/status` returned **698** qualifying entries in **16** protocol/version categories, `partial:false`, **0** source failures, **0** coverage gaps, and **698** source-bound links with **0** missing. The increase from v143's 695 is **+1 Gearbox WBTC listing** plus **+2 IPOR Fusion entries** that became qualifying during the fresh provider snapshot; do not attribute the extra IPOR listings to Gearbox.

**Stake DAO clarification (user-established):** Do **not** mistake the operator-side CRV/FXN/YB-to-sdToken liquid-locker conversion for the user-facing **sdCRV, sdFXN and sdYB staking/gauge contracts**. A staking deposit already denominated in an sdToken may be independently withdrawable in that **same sdToken** without exiting its underlying governance lock. Classify those as separate markets only after verifying staking-token identity, same-token immediate unstaking, APR, capacity and exact gauge UI. **vlSDT remains excluded** because of its eight-week withdrawal delay. Stake DAO's sdToken staking is **low priority** relative to broadly used vault assets; the governance locker conversion remains excluded.

**Next research and integration target:** Additional Gearbox-compatible pools when their rates and liquidity rise, then Silo V3 Ethereum ERC-4626 lending/vault opportunities for mainstream assets using the [official Silo V3 API](https://docs.silo.finance/docs/developers/apis/api-overview/) and exact Silo vault pages. Examine legacy Aave V2 and Compound II only where live APR exceeds 1%, deposits remain enabled, and genuine immediately-withdrawable liquidity exists; avoid old/sunset markets with near-zero rates. Do not import anonymous DeFiLlama rows without independent native identity and correct contract-specific dapp routing.

---

## Current qualification correction — Worker v143 (2026-11-18)

**User-mandated rule:** Required underlying-token locks, cooldowns, queue-based redemptions or inability to synchronously withdraw the same deposit asset disqualify a market from CurveYield's qualifying opportunities list. A freely tradable receipt token is **not** equivalent to direct underlying redemption. Do not exclude an entire protocol merely because one of its product types has restrictions.

**Stake DAO products are not equivalent:**

- **CRV, FXN and YB Liquid Lockers:** The original governance tokens are locked permanently and converted to liquid sdTokens. The UI's `Unstake` action returns sdTokens from the rewards gauge; it does not redeem the original CRV/FXN/YB. These three markets are **disqualified**, even though the sdTokens can be traded through secondary markets.
- **vlSDT:** Explicit eight-week withdrawal queue; disqualified under the no-withdrawal-delay rule.
- **Stake DAO V2 RewardVault strategies:** Standard ERC-4626 `deposit`/`withdraw` interfaces, which can fit the existing OmniAdapter's ERC-4626 mode where exact same-asset synchronous exit is confirmed. The official strategy inventory predominantly accepts **LP tokens**; these still require the single-asset/non-LP filter, asset match, current capacity, on-chain withdrawal behavior, APR/TVL and exact dapp links before publication. **Do not blacklist redeemable RewardVaults just because Liquid Lockers are disqualified.**

**Deployed Worker adjustment:** v143 adds a narrow `Stake DAO Lockers` rejection inside the existing `opEligibleDiscovery` predicate. It does not disable or remove Stake DAO strategy discovery infrastructure, alter OmniAdapter contracts, or create a new per-protocol adapter.

**Live verification after refreshing source caches:** `/api/opportunities/status?source=stakedao` returned **0** eligible lockers, no source failures; combined `/api/opportunities/status` returned **695** eligible listings across **15** protocol/version categories, **695** source-bound market-specific links, `partial:false`, **0** failures, **0** coverage gaps and **0** missing links. The 698-row figure from v141 is **historical and superseded**, reflecting three now-disqualified governance lockers. Individual dapp links and vault withdrawal transactions are not all wallet-executed.

**Official evidence:** [Stake DAO Liquid Lockers](https://docs.stakedao.org/liquidlockers), [Stake DAO CRV locker — conversion irreversible](https://app.stakedao.org/lockers/crv), [Stake DAO vlSDT withdrawal queue](https://docs.stakedao.org/guides/stake-vlsdt), [Stake DAO V2 RewardVault integration](https://docs.stakedao.org/developers/strategies).

---

## Shared Morpho Vault V2 OmniAdapter — deployment architecture

**Established CurveYield architecture:** The protocol integration list does **not** require separate vault adapters per protocol. One existing **CurveYieldOmniAdapterV8**, created for the official Morpho Vault V2, supports multiple configured market positions through `allocate(bytes,uint256,bytes4,address)`, `deallocate(bytes,uint256,bytes4,address)`, and `realAssets()`. The official Vault V2 already supplies native caps (via `idData` / `keccak256(idData)`), permissions, timelocks, accounting and allocator controls. Do not rebuild any of those systems or introduce redundant per-protocol adapter infrastructure.

**Authoritative source:** [`OmniAdapter/contracts/CurveYieldOmniAdapterV8.sol` on `ethereum-omniadapter-v8-compatibility-v1`](https://github.com/curveyield3/Smart-Contracts/blob/ethereum-omniadapter-v8-compatibility-v1/OmniAdapter/contracts/CurveYieldOmniAdapterV8.sol). Its source header identifies a v10 revision while the contract name remains V8. The source is on a dedicated branch, not present on the repository's `main` branch at this checkpoint. Presence in GitHub does **not** independently confirm its deployment, installation on a specific Morpho Vault V2, configured native caps or permissions.

**Explicit modes currently in source:** (1) ERC-4626 synchronous vaults including Yearn V3, IPOR instant-withdrawable paths, Fluid fTokens, CurveLend and compatible Euler products; (2) Beefy V7 / BoostHub; (3) Aave V3 / Spark; (4) Compound III; (5) Morpho Blue/core fork; (6) Aave V4 spoke; (7) Dolomite normal market; (8) Yearn V2 native vault; (9) Liquity V2 BOLD stability pool, excluding collateral reward valuation; (10) Dolomite isolated market. The adapter serves **multiple markets**, not one new contract per market.

**Contract-proven limitations:** The V8 source expressly **excludes Maple and Cap**; scheduled IPOR Fusion redemption queues cannot satisfy synchronous Vault V2 deallocation; Liquity collateral-token rewards are unvalued and not approved for allocation under that mode. Fraxlend, Stake DAO lockers and some target-specific mechanisms are **not explicitly named as native adapter modes**. They must not be marked vault-allocation compatible merely because discovery indexed them or because a generic `ERC4626` mode exists. Any missing compatibility must be demonstrated against the actual existing interface before a change is proposed.

**Operational division of responsibility:** Markets Worker does identity, market enumeration, APR/TVL, single-token and deposit/withdraw availability, official dapp links and discovery publication. Vault-creation / configuration UI selects the existing **OmniAdapter mode and market configuration**, installs/configures the shared adapter through native Vault V2 procedures, and applies native caps. Do **not** conflate discovery eligibility with permissioned deposit capability, available synchronous liquidity, or proven native Vault V2 allocation.

**Next integration check:** reconcile the **actual target list** against this existing adapter's supported mode, calldata, share/redemption behavior and withdrawal mechanism. Where compatible, configure and use the existing adapter; where not demonstrated (notably Maple and queued IPOR), retain an explicit eligibility block. No new per-protocol adapter contract or redundant factory should be introduced without a separately demonstrated operational need.

---

## Priority action checklist

- [ ] **P1 — Fraxlend:** Repair the out-of-scope `count` variable and verify a complete live collection.
- [ ] **P2 — Live validation:** Verify each active provider's runtime schema, discovered/normalized/eligible/published counts, failures, and actual protocol-specific dapp destinations.
- [x] **P3 (discovery eligibility) — Deposit screening:** Source-isolated asset/capacity checks exist for IPOR, Fluid, Yearn V2/V3 and CurveLend V1/V2. **Separate, not complete:** demonstrate actual OmniAdapter mode compatibility, native Vault V2 cap configuration, permission constraints and synchronous withdrawal on each allocatable market; no new per-protocol adapters.
- [ ] **P4 — Mainstream asset discovery first:** Expand WBTC/wstETH/USDS/DAI and other common ERC-20 markets through native protocol sources, beginning with Gearbox and Silo. Stake DAO sdToken gauge staking is a separate, lower-priority category; its operator locker conversion and vlSDT are excluded.
- [ ] **P5 — Completeness:** Reconciled **698 currently eligible** entries in ten isolated native feeds (including Gearbox) plus seven shared collectors (v145), with cold-cache gaps surfaced. The v143 baseline was 695. Full upstream enumeration and individual transaction verification remain unverified.
- [ ] **P6 — Persistence:** Add durable per-asset snapshots and historical performance within the intended storage architecture.

**Verification milestone:** report, for **each** source, **markets discovered → markets successfully normalized → eligible single-token markets → published markets with working dapp destinations**. Keep unknown numbers explicitly unknown.

---

## Verified deployment checkpoint — 2026-11-18 (Worker v141)

**Live authoritative status:** At approximately **11:37 UTC**, after independently refreshing the expired CurveLend feed, `GET https://markets.curveyield.org/api/opportunities/status` returned **698 qualifying single-token-market listings**, **16 protocol/version categories**, **698 source-bound market-specific dapp URLs**, **0 missing primary links**, **0 source failures**, **0 coverage warnings**, and `partial:false`. Distinguish **source-bound URL correctness** from independently browser-verified or wallet-executed interaction: not all 698 URLs have been individually exercised. The page `/opportunities` displayed 698/698 and rendered the first **100** rows, with further rows paginated.

### Architecture and Cloudflare recovery

- **Worker v140:** reduced the main discovery refresh to seven independent collectors: Curve LP composition (supporting filter), Aave V3, Aave V4, Euler EVK, Beefy vaults, SparkLend and Compound III. The live main-only status returned **76** opportunities with no failures. **Do not equate 76 with the full combined catalog.**
- **Nine source-bounded feeds:** Stake DAO, IPOR, Fluid, Yearn V2/V3, CurveLend V1/V2, Maple Syrup, Morpho Blue, Morpho Vault V1 and Morpho Vault V2. Every feed was verified individually from a live endpoint. Their public URLs are `/api/opportunities/status?source=stakedao`, `ipor`, `fluid`, `yearn`, `curvelend`, `maple`, `morphoblue`, `morphov1`, and `morphov2` (same hostname).
- **Worker v141:** the ordinary `/api/opportunities`, `/api/opportunities/status`, and asset-scoped `/api/ethereum-lending-markets` combine independently verified **warm** edge-cache snapshots with the main seven-collector set. No additional provider RPCs are issued by this aggregation. If a snapshot is cold, expired or invalid, the API explicitly reports a coverage gap and `partial:true`, rather than silently declaring a complete result.
- **Caching:** Cloudflare memory + edge cache, 900-second TTL. No R2 or durable storage writes were added. This does not yet satisfy per-asset historical storage or provider completeness invariants.
- **UI:** cached source datasets override the corresponding base rows and cannot be silently replaced by stale unverified values; page visibly paginates 100 rows. Fraxlend remains quarantined. Curator dashboard v4 and market-creation interfaces were preserved.

### Source-specific qualification outcome

| Source | Live source candidates checked | Passed gate | Published qualifying markets | Qualifications |
| --- | ---: | ---: | ---: | --- |
| **Yearn V2 and V3** | **371** | **237** | **110** (V2 **64**, V3 **46**) | V2 verifies native `token()`, `availableDepositLimit()`, `emergencyShutdown()==false`; V3 verifies ERC-4626 `asset()` and `maxDeposit(receiver)>0`. **134** rejected by these checks. Source-specific pages; individual wallet actions remain untested. |
| **CurveLend V1 and V2** | **32** | **32** | **19** (V1 **13**, V2 **6**) | ERC-4626 underlying and positive maxDeposit verified; official controller-derived vault URLs. Actual wallet transactions not executed. |
| **Morpho Blue** | Not independently quantified before filtering | Not separately quantified | **241** | Native GraphQL market ID and lending asset identity, TVL, APY and market-specific Morpho route; independent source returned no failures. |
| **Morpho Vault V1** | Not independently quantified before filtering | Not separately quantified | **74** | Native GraphQL vault-address identity, underlying, rate and exact vault-specific link; isolated source returned no failures. |
| **Morpho Vault V2** | Not independently quantified before filtering | Not separately quantified | **136** | Same dedicated V2 source and contract-specific routes; isolated source returned no failures. |
| **Maple Syrup (restricted)** | **3** | **0** for unpermissioned sentinel receiver | **0** unrestricted deposit opportunities | Maple's documented lender authorization/allowlisting is mandatory; router `authorizeAndDeposit` requires eligible signature and withdrawals may enter a queue. **Do not** present these as universally accessible vault deposits. |
| **Stake DAO native lockers** | Three approved Ethereum native locker candidates from 14 cross-chain records | **3** source-qualified | **3** | CRV/YB/FXN; irreversible principal lock in exchange for sdTokens, **not** an ordinary redeemable vault. |
| **IPOR Fusion** | **62** | **60** | **34** in independently verified snapshot | Asset and maxDeposit checked; live dapp URLs. |
| **Fluid Lending** | **5** | **5** | **5** | Correct ERC-4626 underlying and maxDeposit, all five published. |
| **Fraxlend — quarantined** | **59** registered, ABI-decoded and priced | Capacity-qualified subset, but front-end route invalid | **0** verified interactive markets | Official new/old app routes did not reliably select intended pair; analytics at `https://facts.frax.finance/fraxlend/pairs/<pair-address>` can confirm the pair, but analytics alone is **not** an interactive deposit route. |

**Total reconciled categories:** Aave V3 15; SparkLend 6; Compound III 4; Aave V4 19; Euler EVK 13; Beefy Vaults 19; Morpho Blue 241; Morpho Vault V1 74; Morpho Vault V2 136; Yearn V2 64; Yearn V3 46; CurveLend V1 13; CurveLend V2 6; IPOR Fusion 34; Fluid Lending 5; Stake DAO Lockers 3. Sum **698**.

**Still open:** Obtain genuinely interactive pair-exact Fraxlend dapp routes, verify Maple's authorization flow in the relevant wallet/adapter context (without weakening global screening), check ERC-4626 withdrawal liquidity and share accounting across vault types, perform per-market browser interaction verification, establish complete provider-enumeration counts, and implement per-asset durable historical snapshots within user-specified R2 limits.

**Authoritative references:**
- [Curve lending-vault ERC-4626 functions](https://docs.curve.finance/developer/lending/contracts/vault/)
- [Yearn V2 Vault source](https://github.com/yearn/yearn-vaults-v2/blob/master/contracts/Vault.vy)
- [Maple frontend integration and authorization](https://github.com/maple-labs/maple-docs/blob/master/integrate/ethereum-mainnet/frontend-integration.md)

---

## Integration checkpoint — 2026-11-18 (Worker v134)

**Production state:** v134 deployed. This is a verified source-level milestone for three protocol paths, **not** proof that all protocol markets have been exhaustively enumerated or that every destination has undergone end-to-end wallet-interaction testing. The older v118 inventory below is retained as a historical baseline, not a current description of every collector.

| Protocol | Source enumeration / eligibility evidence | Public discovery behavior | Remaining qualification |
| --- | --- | --- | --- |
| **Stake DAO native lockers** | The official locker feed includes 14 multi-chain/legacy records; three directly identified Ethereum input-token lockers (CRV, YB, FXN) passed eligibility. Official mint/depositor contract and locker pages were checked. Dedicated `?source=stakedao` returned **3**, zero source failures, 3 exact locker pages. | These three are merged into the Markets opportunities UI. Governance assets are permanently locked when minted into sdTokens; **not suitable for unrestricted vault deposits/withdrawals** and not approved as automatic vault allocations. | Verify on-chain per-locker mint permissions and current gauge reward availability; legacy/LP lockers remain excluded. |
| **IPOR Fusion** | Dedicated `?source=ipor` checked ERC-4626 `asset()` and `maxDeposit(0x…dead)` for **62** source candidates: **60** positive/matching, **2** excluded; **34** published after TVL/APR/link filters in the checked snapshot, with zero source failures. A later base-catalog snapshot had 35 before the next source refresh. | Source-verified vault set is merged into the UI; unverified base rows are excluded when live source verification succeeds. | Provider pagination/completeness and every wallet-level deposit, withdrawal, and individual dapp UI still require further validation. |
| **Fluid Lending fTokens** | Dedicated `?source=fluid` checked ERC-4626 underlying and `maxDeposit(0x…dead)` for **5** fTokens; **5 accepted**, **0 rejected**; **5** eligible published, 5 contract-specific Fluid URLs, zero source failures. | Source-verified fToken rows are merged into the UI, suppressing base-only rows that do not pass on-chain checks. | Full lending-cap/withdrawability reconciliation and individual wallet-interaction checks remain. |
| **Fraxlend — still blocked** | Fixed original out-of-scope `count` reference; source-only live registry enumerated **59** pairs, decoded and priced all 59, with six apparent yield/TVL candidates before strict link review. | **Quarantined from verified listings in v132+**: a sampled app.frax.finance pair link displayed a different asset/collateral market than requested. Pair-level discovery diagnostics remain available, but no candidate is counted as an actually verified direct dapp destination. | Find and independently confirm a working contract-specific **interactive** pair URL for every publishable pair, plus any lender whitelist and deposit-state restrictions. |

**Cross-source runtime issue:** A primary status read returned **681** markets across **16** protocols at 10:04 UTC with zero failures; a separate page refresh exposed failures in Morpho and Maple from the Cloudflare 50-external-subrequest limit. Treat a normal-catalog count as potentially partial; never infer source exhaustiveness from a successful collector block. The normal API and additional isolated source feeds are separate, while the public UI merges their results.

**Source diagnostics:** `/api/opportunities/status?source=stakedao`, `?source=ipor`, `?source=fluid`, `?source=fraxlend` on `https://markets.curveyield.org`.

**Current work still required:** Fraxlend correct dapp routing; stable bounded-subrequest source discovery/reconciliation; complete deposit/withdraw eligibility for Yearn, CurveLend, Maple, etc.; durable per-asset catalog/history; end-to-end destination and live transaction-interaction verification where authorized.

---

## Baseline assessment retained from v118

## CurveYield Markets — protocol integration inventory

Worker v116 deployed

Ethereum mainnet

Single-token deposits only

I inspected the deployed Worker's collector registry, filtering logic, market parsers and dapp-link validators.

The current eligibility rules require a directly identified ERC-20 deposit asset, more than $100 in reported TVL, annualized yield above 1%, and a contract-specific protocol dapp URL. LP baskets, dual-token deposits and conversion routes are excluded.

**Important distinction:** A collector being implemented or enabled does not prove exhaustive live coverage. The public API could not be read through the available external connection, so the assessment below describes **verified deployed-code capabilities**, not independently confirmed live market counts.

### 1. Active integration targets

The latest deployed version is now **v118**, which carries forward the v116 discovery subsystem alongside separate curator-UI changes.

In the table, *deep* means substantial source-side enumeration and normalization is implemented, **not** that every market has been observed successfully in production.

| Protocol target | Automated discovery implemented | Current integration level |
| --- | --- | --- |
| **Morpho Blue** | GraphQL market enumeration, up to 24,000 markets; loan token, TVL, supply APY, exact market ID and dapp route | **Deep, capped** — no verified live completeness count |
| **Morpho Vault V1** | GraphQL vault inventory (up to 4,000) plus REST identity reconciliation; asset, TVL, net APY and vault page | **Deep, capped** — live coverage unverified |
| **Morpho Vault V2** | Dedicated V2 GraphQL inventory plus REST reconciliation, with the same asset and yield normalization | **Deep, capped** — live coverage unverified |
| **Aave V3** | Official GraphQL market/reserve discovery, supply APY, USD TVL, frozen/paused screening, market-specific dapp URL | **Broad** — no separate pagination or live completeness proof |
| **Aave V4** | Official spoke/reserve GraphQL, supply eligibility, supply APY, TVL and encoded reserve page | **Broad** — schema and every dapp route still need runtime confirmation |
| **Euler EVK** | Paginated official EVK inventory (up to 10,000), visible/lendable status, fresh snapshot, supply APY and vault URL | **Deep, capped** |
| **SparkLend** | On-chain reserve enumeration, supply rate, price, TVL, active/frozen/paused checks, supply-cap screening | **Deep on-chain implementation** — live result not verified |
| **Compound III** | Official Comet deployment manifests, on-chain market values, supply rate, oracle and paused-state checks | **Deep on-chain implementation** — runtime outcome unverified |
| **CurveLend V1** | Official Curve Ethereum lending-vault API, borrowed/deposit token, supply TVL, lend APY, controller-based dapp route | **Broad** — limited to records and fields returned by the API |
| **CurveLend V2** | Same official source, with V2 classification based on registry/version metadata | **Broad but conditional** — V2 identification requires validation |
| **Fluid Lending (fTokens)** | Official fToken API, underlying token, supply APR, staking yield, eligible rewards, TVL and deposit page | **Broad** — complete deposit availability checks not established |
| **Yearn V2** | Kong Ethereum vault inventory, underlying asset, TVL, net APY and exact vault page | **Broad** — older legacy reconciliation source disabled |
| **Yearn V3** | Kong inventory with V3 API-version identification, underlying asset, TVL, net APY and vault page | **Broad** — dependent on Kong's inventory completeness |
| **Beefy Vaults** | Official vault, APY, TVL and fee APIs; active standard vaults; one-input-asset and zero-fee restrictions | **Good filtered coverage** — not the entire Beefy inventory |
| **IPOR Fusion** | Official Fusion v2 vault API; asset, USD TVL, net/gross APY and vault-specific page | **Partial** — no demonstrated exhaustive pagination or live deposit-state verification |
| **Maple Syrup** | Three specifically identified USDC, USDT and USDG vaults; router and withdrawal-manager identity; on-chain `totalAssets()` TVL; APY and app page | **Targeted integration** — not exhaustive Maple-wide discovery |
| **Fraxlend** | Four deployer addresses, pair enumeration, native accounting, utilization, APR, prices, deposit capacity and pair dapp matching | **Blocked by confirmed code defect** — collector references an out-of-scope `count` variable |
| **Curve LP composition registry** | Identifies underlying LP composition for exclusion and asset classification | **Active supporting data**, not a published single-token yield protocol |

### What those levels mean

The strongest **enumeration implementations** are Morpho, Euler, Spark and Compound III. They scan indexed inventories or contract registries rather than merely importing a small collection of selected products.

Aave, CurveLend, Yearn, Fluid and Beefy have genuine source-specific integrations, but their completeness is constrained by provider responses, unverified runtime schemas, or eligibility checks that are not yet comprehensive.

**Maple and Fraxlend are not complete integrations today.** Maple is restricted to three identified vaults. Fraxlend has extensive code but a definite execution blocker, so it must not be reported as operational.

### 2. Existing integrations that are disabled

These collectors are present in the Worker but excluded from the active source allowlist.

| Integration target | Current state | Reason / remaining work |
| --- | --- | --- |
| Stake DAO Hub vaults V1/V2 | Disabled | Mostly LP-oriented; exact vault dapp identity remains unresolved |
| Stake DAO native strategies | Disabled | Strategy registry exists, but individual deposit routes and input-token eligibility are unresolved |
| Stake DAO Hub lockers | Disabled | **Potential single-token opportunity gap**; locker deposits need independent verification |
| Stake DAO native lockers | Disabled | Requires locker-by-locker token, deposit conditions, yield and app integration |
| Convex Booster registry | Disabled | On-chain pool enumeration implemented, but predominantly LP deposits |
| Convex reward pools / receipt TVL | Disabled | Native Booster/reward information exists, but LP-based positions are outside scope |
| Fluid Smart Lending | Disabled | Dual-token supply positions excluded |
| Fluid collateral/borrowing vaults | Disabled | Borrowing positions are not automatically single-token lending opportunities |
| Yearn yDaemon legacy inventory | Disabled | Older-vault reconciliation unavailable; Kong remains active |
| Beefy LP component discovery | Disabled | Multi-asset LP analysis outside scope |
| Balancer BPT pools | Disabled | BPT deposits represent multi-asset pools |
| DeFiLlama generic yield importer | Disabled | Previously produced unsupported or ambiguously identified listings |

Of these, **Stake DAO lockers and potentially some legacy Yearn vaults deserve additional work**, because excluding LP opportunities does not automatically justify excluding single-token locker or vault deposits.

### 3. Protocols recognized but lacking dedicated native discovery

| Protocol | Current integration level |
| --- | --- |
| Aave V2 | Recognized by protocol classification, but no enabled native V2 collector |
| Compound II | Recognized by classification, but no enabled cToken market collector |
| Morpho Optimizer | Recognized by classification, but no enabled dedicated discovery |
| Maple institutional pools | Native Maple collector inspects pools, but publication deliberately restricts to three identified Syrup products |
| Yearn V1 / older legacy products | No comprehensive enabled legacy discovery source |

These are genuine coverage limitations, not completed integrations.

## 4. Overall integration assessment

| Metric | Count |
| --- | ---: |
| Collector blocks in source | **28** |
| Disabled collector blocks | **12** |
| Enabled static collectors | **14** |
| Additional Morpho collector jobs | **4** |

The four Morpho jobs come from two parameterized collector blocks. Counts measure code coverage, not successful live API responses.

The discovery architecture currently has these additional limitations:

- **Refresh is request-driven:** catalogs are cached for 900 seconds (15 minutes); there is no demonstrated continuous factory-event monitoring.
- **No persistent discovery history:** this catalog path reports zero R2 and Durable Object writes. Historical performance and permanent per-asset inventories are not maintained here.
- **No proven end-to-end exhaustiveness:** provider pagination limits, source errors, unavailable deposit routes and invalid markets can all reduce coverage.
- **No confirmed live integration totals:** source failures are exposed by the API, but I could not read its live output through the available connection.

The Worker exposes its own diagnostics at [Markets discovery status API](https://markets.curveyield.org/api/opportunities/status?utm_source=chatgpt.com) and its catalog at [Markets opportunities API](https://markets.curveyield.org/api/opportunities?utm_source=chatgpt.com). These routes are confirmed in the deployed source, though live responses were not independently retrieved.

### 5. Remaining work, ordered by importance

| Priority | Work | Why |
| --- | --- | --- |
| 1 | Repair Fraxlend's `count` scope error and verify a complete live collection | Currently blocks the entire native Fraxlend collector |
| 2 | Verify each active provider's live schema, returned market counts, failures and dapp destinations | Necessary before any exhaustive-coverage claim |
| 3 | Complete single-token deposit-eligibility checks, especially IPOR, Fluid, Yearn and CurveLend | Avoid showing unavailable or nondepositable markets |
| 4 | Integrate eligible single-token Stake DAO lockers and legacy markets | Close genuine missing-protocol coverage |
| 5 | Add completeness checks to unpaginated provider inventories and reconcile discovered counts | Detect silent omissions |
| 6 | Establish durable per-asset discovery snapshots and historical performance using the intended storage architecture | Preserve complete inventories beyond the 15-minute cache |

**Bottom line:** CurveYield Markets now has a substantial native discovery foundation covering the major Ethereum lending and vault protocols, but it is **not yet exhaustively integrated**. The strongest code coverage is in Morpho, Euler, Spark and Compound III. Fraxlend has a confirmed blocker; Maple is intentionally limited to three products; and several legitimate single-token opportunities may still be missing from legacy vaults and lockers.

The next milestone should be a verified, source-by-source count of **markets discovered → markets successfully normalized → eligible single-token markets → published markets with working dapp destinations**, rather than another increase in the number of collector names.
