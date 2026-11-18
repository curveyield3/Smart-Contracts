# MARKET DISCOVERY INTEGRATION CHECKLIST — v2

> **Scope:** Ethereum mainnet · single-token ERC-20 deposits only  
> **Document status:** Deployed-code capability inventory, **not** independently verified live discovery counts.  
> **Worker:** v116 discovery review; latest deployed v118 carries forward that discovery subsystem alongside curator-UI changes.

## Priority action checklist

- [ ] **P1 — Fraxlend:** Repair the out-of-scope `count` variable and verify a complete live collection.
- [ ] **P2 — Live validation:** Verify each active provider's runtime schema, discovered/normalized/eligible/published counts, failures, and actual protocol-specific dapp destinations.
- [ ] **P3 — Deposit eligibility:** Complete single-token deposit checks for IPOR, Fluid, Yearn, and CurveLend.
- [ ] **P4 — Coverage gaps:** Integrate eligible single-token Stake DAO lockers and legitimate legacy markets.
- [ ] **P5 — Completeness:** Add provider pagination/completeness checks and reconcile enumerated counts.
- [ ] **P6 — Persistence:** Add durable per-asset snapshots and historical performance within the intended storage architecture.

**Verification milestone:** report, for **each** source, **markets discovered → markets successfully normalized → eligible single-token markets → published markets with working dapp destinations**. Keep unknown numbers explicitly unknown.

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
