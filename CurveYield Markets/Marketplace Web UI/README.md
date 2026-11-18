# CurveYield Marketplace Web UI — Production v164 / Visual Reference v9

**Start here for any CurveYield Markets website/curator page design work.**

## Where it runs

- Production host: https://markets.curveyield.org/
- **Curator visual preview:** https://markets.curveyield.org/curator-preview/#/vaults/create
- Market creation mockup: https://markets.curveyield.org/curator-preview/#/markets/create
- Portfolio: https://markets.curveyield.org/curator-preview/#/portfolio/positions
- Configured vault dashboard: https://markets.curveyield.org/curator-preview/#/vault/manage/overview
- New-vault setup dashboard: https://markets.curveyield.org/curator-preview/#/vault/new/overview
- Source of live delivery: Cloudflare Worker named **`markets`**, script routing `/curator-preview`, `/curator-preview/app.css`, `/curator-preview/app.js`.

## Current production integration — Markets Worker v164

The approved Morpho-inspired browsing design is now served on production routes, not merely /curator-preview. **Read this before editing the frontend.**

- `/` — Marketplace Home, live navigation.
- `/markets` and `/markets/<slug>` — Fraxtal market index and details backed by the existing `/api/markets` and `/api/activity/<slug>` on-chain API routes.
- `/portfolio`, `/portfolio/positions`, `/portfolio/vaults`, `/portfolio/activity` — portfolio design with explicit wallet connection, using `/api/positions?wallet=...` where available. Wallet positions cover only supported Fraxtal markets. Account activity indexing remains incomplete.
- `/vaults` — browser-saved recent vaults, clearly **not** a complete factory-vault registry; existing verified import/management links remain.
- `/create` — existing functional market creation, now in the same Morpho-style collapsible sidebar and responsive white/gold form shell as the other pages. Its original market-creation wallet and transaction generator remain unchanged.
- `/vaults/create` — original protected-controller deployment logic now appears inside the approved **two-step Fraxtal creation UI** (vault identity → adapter/review). The original v10 controller deployment, wallet signing, fee payment, receipt verification, and resume safeguards are still the authoritative handlers.
- `/vaults/0x...` — the approved permanent vault-management dashboard is live with Overview, Allocation, Caps, Timelocks, and Sentinel tabs. Existing on-chain fee/operator, dead-deposit, lending market discovery, adapter and cap actions remain in place; Timelocks/Sentinel display the approved information layout but **cannot yet read or submit permissioned actions** until source-bound ABI integration.
- `/opportunities`, `/wfrax`, `/frxusd`, `/sfrxusd`, `/market/0x...` — preserved production discovery and trading flows.

**Vault UI assets:** [site/vault-ui-v11.js](site/vault-ui-v11.js) and [site/vault-ui-v11.css](site/vault-ui-v11.css), committed and loaded via the pinned GitHub revision through Worker routes `/assets/vault-ui-v11.js` and `.css`. These enhance layout only; the original `VAULT_CLIENT` still owns all wallet and contract interaction logic. The enhanced Fraxtal vault shell falls back to the original vault HTML when the template cannot be retrieved. The Ethereum legacy query variant is intentionally unchanged.

**Live source:** [site/marketplace-live-v10.js](site/marketplace-live-v10.js) is the exact client-side live-data integration script. The Worker injects it after the approved v9 visual app, and serves it from a **commit-pinned GitHub raw URL**. The Worker version must be changed when new script commits are activated. Do not assume an updated GitHub main branch immediately changes production.


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
