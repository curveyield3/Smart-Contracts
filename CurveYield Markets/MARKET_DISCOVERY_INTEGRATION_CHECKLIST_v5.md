# MARKET DISCOVERY INTEGRATION CHECKLIST — v5

> **Scope:** Ethereum mainnet · single-token ERC-20 deposits only  
> **Document status:** Live source-specific verification checkpoint, plus historical implementation inventory; not a claim of exhaustive wallet-interaction testing.  
> **Current verified Worker deployment:** v143 (November 18, 2026); the shared OmniAdapter is separately maintained on its dedicated GitHub branch. Historical v141, v134 and v118 discovery notes are retained below.

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
- [ ] **P4 — Coverage gaps:** Identify and verify **unrestricted synchronous-withdrawal Stake DAO RewardVault strategies** and legitimate legacy markets. Stake DAO's permanent governance Liquid Lockers are disqualified.
- [ ] **P5 — Completeness:** Reconciled **695 currently eligible published** entries in nine isolated feeds plus seven shared collectors (v143), with cold-cache gaps surfaced. The prior 698 included three disqualified Liquid Lockers. Full upstream enumerated market completeness remains unverified.
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
