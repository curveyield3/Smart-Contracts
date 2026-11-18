# CurveYield Marketplace Web UI — Production v174 / Visual Reference v9

**Start here for any CurveYield Markets website/curator page design work.**

## Production v174 — current functional status

Cloudflare Worker `markets` v171 added source-bound Fraxtal vault inventory, wallet-filtered market activity and live vault Timelocks/Sentinel reads. All changes are read-only; existing transaction and deployment handlers remain authoritative. Reinspect the active Worker before editing because other agents update it concurrently.

- **Vault directory:** `/vaults` uses `/api/vault-directory`. This reads the immutable historical factory event snapshot in [site/fraxtal-vault-factory-index.json](site/fraxtal-vault-factory-index.json), validated against the actual Fraxtal Vault V2 factory `0x711bCE12269a3a496eFaABB8B9AD5A4485E08A24`, plus newer on-chain factory `CreateVaultV2` logs. The snapshot covers blocks 30,000,000 through 44,101,401. One factory-created vault was found (`0xa9d7ec2b070564c787dcf702f9d1e962819d6084`) and independently checked using `isVaultV2`, `owner`, `asset`. The live API subsequently returned complete coverage through block 44,101,597. Preserve explicit scan coverage, tail gaps and errors; never claim an incomplete index is complete.
- **Do not rely on Morpho REST vaults-v2 with chain 252:** Morpho API `/v0/vaults-v2?chain_ids=252` returned HTTP 400 (`Unsupported chain_id`). The verified factory event source is required.
- **Portfolio Activity:** `/portfolio/activity` requests `/api/portfolio-activity?wallet=<address>`. It filters events by indexed position owner for the three primary Fraxtal Morpho markets across the last 24,000 blocks. Exact transaction hashes and blocks are returned; it is **not** complete wallet history.
- **Vault Timelocks/Sentinel:** `/vaults/<address>` uses `/api/vault-readiness?address=<address>` in the existing dashboard tabs for factory verification and direct `timelock(bytes4)`, `abdicated(bytes4)`, `isSentinel(address)`, owner/curator and adapter count reads. A supplied address can be checked as a sentinel. Pending-action enumeration and a complete sentinel roster are **not** implemented; no new transaction controls.
- **Current frontend JS:** [marketplace-live-v12.js](site/marketplace-live-v12.js) and [vault-ui-v12.js](site/vault-ui-v12.js); CSS stays [vault-ui-v11.css](site/vault-ui-v11.css). GitHub source files are pinned by exact commits in the live Worker, not automatically published by branch updates. Older marketplace v10/v11 and vault v11 JavaScript were replaced.
- **Live verification:** Production `/api/vault-directory` and `/vaults` displayed the same one-vault verified historical record; `/api/vault-readiness` returned on-chain roles and timelocks for it; `/api/portfolio-activity` returned a bounded empty record for a zero-address input. No wallet signing or blockchain transactions were executed. Full latest-build mobile and end-to-end wallet QA remains outstanding.

## Production v172–v174 frontend correctness updates

- **v172 — verified market data mapping:** The live market directory's `Supplied` column now reads `m.supply`, not `m.borrow`. Factory-created market position pages request `/api/positions?wallet=...&market=<marketId>` and require Fraxtal `chainId:252` before displaying positions.
- **v173 — vault directory index integrity:** The live directory now reads `coverage.complete` and `warning` from `/api/vault-directory`; lack of a next-page cursor is **not** treated as proof of full coverage. RPC scan failures and missing coverage remain visible.
- **v174 — Portfolio empty-state integrity:** When the per-market position API reports errors, the wallet view explicitly says coverage is incomplete rather than treating failed reads as zero balances. Portfolio totals warn when any market reads failed.
- All updates were made to the **existing** [site/marketplace-live-v12.js](site/marketplace-live-v12.js) source rather than creating duplicate frontend files. Worker `markets` pins the updated GitHub commit `15225f18a7069609837d5824b303069cc077d50e`. Previous pins included `afc4f31a8cf44846aadddf0b260849980fa380a9` (v173) and `c1a5eb296d7f8fed02d2767e22d8a0a01131e922` (v172).
- Cloudflare Worker version **174** was verified active after deployment; producer APIs, actual signing and creation handlers, and other agents' opportunity collectors were preserved. Automated live wallet transaction QA is **not** claimed.

## Where it runs

- Production host: https://markets.curveyield.org/
- **Curator visual preview:** https://markets.curveyield.org/curator-preview/#/vaults/create
- Market creation mockup: https://markets.curveyield.org/curator-preview/#/markets/create
- Portfolio: https://markets.curveyield.org/curator-preview/#/portfolio/positions
- Configured vault dashboard: https://markets.curveyield.org/curator-preview/#/vault/manage/overview
- New-vault setup dashboard: https://markets.curveyield.org/curator-preview/#/vault/new/overview
- Source of live delivery: Cloudflare Worker named **`markets`**, script routing `/curator-preview`, `/curator-preview/app.css`, `/curator-preview/app.js`.

## Historical production integration — Markets Worker v164 (superseded by v171)

The approved Morpho-inspired browsing design is now served on production routes, not merely /curator-preview. **Read this before editing the frontend.**

- `/` — Marketplace Home, live navigation.
- `/markets` and `/markets/<slug>` — Fraxtal market index and details backed by the existing `/api/markets` and `/api/activity/<slug>` on-chain API routes.
- `/portfolio`, `/portfolio/positions`, `/portfolio/vaults`, `/portfolio/activity` — portfolio design with explicit wallet connection, using `/api/positions?wallet=...` where available. Wallet positions cover only supported Fraxtal markets. Account activity indexing remains incomplete.
- `/vaults` — **at v164 only**, browser-saved recent vaults; **v171 uses the on-chain factory event snapshot plus live updates** as described above.
- `/create` — existing functional market creation, now in the same Morpho-style collapsible sidebar and responsive white/gold form shell as the other pages. Its original market-creation wallet and transaction generator remain unchanged.
- `/vaults/create` — original protected-controller deployment logic now appears inside the approved **two-step Fraxtal creation UI** (vault identity → adapter/review). The original v10 controller deployment, wallet signing, fee payment, receipt verification, and resume safeguards are still the authoritative handlers.
- `/vaults/0x...` — the approved permanent vault-management dashboard is live with Overview, Allocation, Caps, Timelocks, and Sentinel tabs. Existing on-chain fee/operator, dead-deposit, lending market discovery, adapter and cap actions remain in place; Timelocks/Sentinel were layout-only at v164; v171 includes factory-verified read-only ABI calls, but still no new permissioned actions.
- `/opportunities`, `/wfrax`, `/frxusd`, `/sfrxusd`, `/market/0x...` — preserved production discovery and trading flows.

**Historical v164 vault UI assets:** vault-ui-v11.js (replaced by v12) and [site/vault-ui-v11.css](site/vault-ui-v11.css), committed and loaded via the pinned GitHub revision through Worker routes `/assets/vault-ui-v11.js` and `.css`. These enhance layout only; the original `VAULT_CLIENT` still owns all wallet and contract interaction logic. The enhanced Fraxtal vault shell falls back to the original vault HTML when the template cannot be retrieved. The Ethereum legacy query variant is intentionally unchanged.

**Historical v164 live source:** marketplace-live-v10.js (replaced by v12) is the exact client-side live-data integration script. The Worker injects it after the approved v9 visual app, and serves it from a **commit-pinned GitHub raw URL**. The Worker version must be changed when new script commits are activated. Do not assume an updated GitHub main branch immediately changes production.


**Important asset pin:** Worker v164 serves vault and market-creation sidebar enhancements from exact GitHub revision `57d15cffe6c471d48e4ffbde856719d441b39eb9` through `CY_VAULT_UI_V11`. A previous deployment initially served an earlier asset which exposed preview Favorites; the pin and section hiding were corrected and independently verified on the live `/create` page. Always check the deployed asset response, not just the GitHub branch, after a visual update.

The live integration never substitutes sample APYs, rates, TVL, history, or personal holdings for chain-derived data. Unsupported features show honest empty or unavailable states. Keep existing wallet-signing and transaction code as the authority; production market details link to the preexisting verified trade routes.

**Production verification performed:** Worker v164 deployment and on-chain API route presence checked; live Opera rendering verified market index and detail, Portfolio, saved-vault index, market creation (including sidebar correction), and two-stage protected vault creation / management chrome. The dashboard was rendered using an explicitly non-deployed placeholder address to inspect layout only. No wallet signatures or transactions were executed, and no on-chain Timelocks/Sentinel actions were verified. Fresh mobile checks on the deployed build remain outstanding.

## Source files kept here

The **v9 visual preview assets** are stored as gzip-compressed Git blobs. These are the canonical page assets for the browsing preview (not a source of live financial data):

- `site/index.html.gz`
- `site/app.css.gz`
- `site/app.js.gz`

The new v9 `app.css.gz` already includes the approved v4-v8 layout styling and all new marketplace design styles. These legacy overlay stylesheets remain available as references, but should not be appended again when serving v9:

1. `site/dashboard-density-v4.css` — ~20% denser dashboard layout; do not tighten creation pages.
2. `site/dashboard-gutters-v5.css` — centered dashboard content with balanced side gutters.
3. `site/page-title-center-v6.css` — center only page-level title and adjacent subtitle; leave all module titles, labels, and operational content aligned normally.

To reconstruct an **editable, faithful standalone copy**, run from the `site` directory (Node or Python is not required for extraction):

```sh
gzip -dc index.html.gz > index.html
gzip -dc app.css.gz > app.css
gzip -dc app.js.gz > app.js
## v9 already includes the complete visual styles; do not append these twice.
```

Now open locally with a static HTTP server, e.g. `python3 -m http.server 8000`, and navigate to `http://localhost:8000/#/markets/create`. Browser mockups use example data; development should preserve their semantics when integrating APIs and wallet transactions.

**This folder is a captured UI source snapshot, not an automatic deployment pipeline.** Before making live changes, use the Cloudflare Ops connection to read the *current* `markets` Worker source, settings/bindings, version and deployment. Merge changes into the newest Worker version with the version concurrency guard. Never overwrite concurrent discovery collector changes or assume the snapshot is newer than the live deployment.

## Visual authority and required behavior

- Follow `visual-authority/README.md` and `visual-authority/filename-map-v1.csv`. The 18 originally supplied Morpho curator screenshots are the placement/layout authority. CurveYield should use white and gold, not Morpho's blue.
- The v9 design includes the existing two-page vault creation, market creation, persistent curator dashboard, plus **market directory, vault directory, individual market details, consumer-style vault details, Portfolio, Home**, collapsible sidebar and mobile menu.
- The dashboard navigation pages are Overview, Allocation, Caps, Timelocks, Sentinel.
- Responsive layouts must keep all buttons, controls, tables, and forms **within their parent bounds**, including the sidebar Create action. Tables may scroll *inside their own containers*, not overflow the page.
- Headers: center **only the page-level title and directly adjacent subtitle**; not table headings, module headings or field labels.
- Maintain compact dashboard density and side gutters, while leaving creation forms roomier.
- At narrower laptops, the Create text becomes an accessible icon when needed; never let it collide with the wordmark or project into the content panel.
- Browser viewport validation has previously covered 300–1920px (including 390, 768, 1024, 1280, 1440, 1920). Recheck at these sizes after editing both collapsed and expanded navigation.

## Functionality and honesty constraints

This `/curator-preview` experience is a **visual preview**, with example vaults/positions. It is *not* proof that market-creation transactions, vault management, portfolio indexing, transaction builders or wallet integration are complete. Do not display example amounts as real on-chain balances. The main production `/vaults`, `/api/opportunities` and market-discovery Worker routes are separate and must be preserved.

Fraxtal is the first target chain. New live transaction integration must use verified factory/controller contracts and actual ABI and receipt evidence; never assume a mock button submits on-chain.


## v9 browsing pages — routes and state

- `#/overview` — Home; `#/markets` — variable-rate market discovery; `#/vaults` — vault discovery.
- `#/markets/wfrax-frxusd` — example market detail (Overview / Positions / Risk / Activity).
- `#/vaults/wfrax-prime` — example vault detail (Overview / Allocation / Performance / Risk / Activity).
- `#/portfolio/positions`, `#/portfolio/vaults`, `#/portfolio/activity` — account portfolio visual surfaces.
- Filters and sorting on discovery tables work client-side with **illustrative preview rows**. There are no real on-chain metrics or wallet transactions in these demo routes. The links labeled live opportunities lead to the production market-discovery experience.
- Morpho's visual information architecture is the reference: compact page titles, directory summary and filters, dense tables, entity headers, tabs, detail panels and transaction-side rail. Brand colors are CurveYield white/gold.
- Browser render observations: six routes checked at 320, 390, 768, 1024, 1280, and 1920px (36 route/viewport pairs), with no page-wide overflow or script errors. New visual changes require fresh browser inspection; do not treat this as permanent test coverage.
- To avoid exceeding the large Markets Worker's ~500 KB source limit, the preview-only paths can proxy the versioned compressed assets from this GitHub folder, using Cloudflare cache. Keep regular opportunities, vault deployment, APIs and market-discovery routes unaffected. Before promoting or refactoring, confirm the currently deployed version and asset hashes.

## Editing handoff

1. Read this README, the visual manifest, and the current live Worker source; inspect relevant screenshot images before changing layout.
2. Decompress the three asset files above. Treat their resulting files as the **v9 visual source**; app.css includes the prior styling, so do not append the old CSS overlays.
3. Make the smallest necessary UI edits. Do not introduce redundant workflows, duplicate versions, or new contract source in Contract-Automation.
4. Browser-check reference fidelity, viewport overflow (especially Create button), collapsed/expanded sidebar, and the pages changed. No new automated test suites unless authorized.
5. Deploy via Cloudflare Ops only after merging with the latest Worker code and preserving bindings, APIs, wallet/transaction functions and other agents' collector changes.
6. Update the canonical source snapshot and this README when approved changes are live. Provide deployed Worker version and evidence, distinguishing preview-only from actual on-chain support.

Historical ZIP versions 1–9 and local preview screenshots were generated in the ChatGPT conversation. The **original visual authority screenshot archive is now committed in this repository** at [`visual-authority/Complete CurveYield MarketPlace Visual Authority Images.zip`](visual-authority/Complete%20CurveYield%20MarketPlace%20Visual%20Authority%20Images.zip), alongside the filename/checksum mapping. The archive was moved intact from the repository root (Git blob SHA `f1c0e802502c0eb60820562a0bbf1b2e3d1ef638`, 5,597,806 bytes). Extract the images to compare visual placement; do not confuse the demonstration screenshots with Morpho source authority.
