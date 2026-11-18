# CurveYield Marketplace Web UI — Agent Handoff (v8 visual snapshot)

**Start here for any CurveYield Markets website/curator page design work.**

## Where it runs

- Production host: https://markets.curveyield.org/
- **Curator visual preview:** https://markets.curveyield.org/curator-preview/#/vaults/create
- Market creation mockup: https://markets.curveyield.org/curator-preview/#/markets/create
- Portfolio: https://markets.curveyield.org/curator-preview/#/portfolio/positions
- Configured vault dashboard: https://markets.curveyield.org/curator-preview/#/vault/manage/overview
- New-vault setup dashboard: https://markets.curveyield.org/curator-preview/#/vault/new/overview
- Source of live delivery: Cloudflare Worker named **`markets`**, script routing `/curator-preview`, `/curator-preview/app.css`, `/curator-preview/app.js`.

## Source files kept here

The **exact served UI assets** were captured directly from the live Worker's `CY_CURATOR_PREVIEW_GZIP` object and preserved byte-for-byte as compressed Git blobs:

- `site/index.html.gz`
- `site/app.css.gz`
- `site/app.js.gz`

The Worker adds these three CSS overlays **in this order** when serving `/curator-preview/app.css`:

1. `site/dashboard-density-v4.css` — ~20% denser dashboard layout; do not tighten creation pages.
2. `site/dashboard-gutters-v5.css` — centered dashboard content with balanced side gutters.
3. `site/page-title-center-v6.css` — center only page-level title and adjacent subtitle; leave all module titles, labels, and operational content aligned normally.

To reconstruct an **editable, faithful standalone copy**, run from the `site` directory (Node or Python is not required for extraction):

```sh
gzip -dc index.html.gz > index.html
gzip -dc app.css.gz > app.css
gzip -dc app.js.gz > app.js
cat dashboard-density-v4.css dashboard-gutters-v5.css page-title-center-v6.css >> app.css
```

Now open locally with a static HTTP server, e.g. `python3 -m http.server 8000`, and navigate to `http://localhost:8000/#/markets/create`. Browser mockups use example data; development should preserve their semantics when integrating APIs and wallet transactions.

**This folder is a captured UI source snapshot, not an automatic deployment pipeline.** Before making live changes, use the Cloudflare Ops connection to read the *current* `markets` Worker source, settings/bindings, version and deployment. Merge changes into the newest Worker version with the version concurrency guard. Never overwrite concurrent discovery collector changes or assume the snapshot is newer than the live deployment.

## Visual authority and required behavior

- Follow `visual-authority/README.md` and `visual-authority/filename-map-v1.csv`. The 18 originally supplied Morpho curator screenshots are the placement/layout authority. CurveYield should use white and gold, not Morpho's blue.
- The v8 design includes two-page vault creation, market creation, the same persistent configured-vault dashboard as the post-deployment guided setup dashboard, Portfolio (positions/vaults/activity), a collapse/expand sidebar and a mobile overlay menu.
- The dashboard navigation pages are Overview, Allocation, Caps, Timelocks, Sentinel.
- Responsive layouts must keep all buttons, controls, tables, and forms **within their parent bounds**, including the sidebar Create action. Tables may scroll *inside their own containers*, not overflow the page.
- Headers: center **only the page-level title and directly adjacent subtitle**; not table headings, module headings or field labels.
- Maintain compact dashboard density and side gutters, while leaving creation forms roomier.
- At narrower laptops, the Create text becomes an accessible icon when needed; never let it collide with the wordmark or project into the content panel.
- Browser viewport validation has previously covered 300–1920px (including 390, 768, 1024, 1280, 1440, 1920). Recheck at these sizes after editing both collapsed and expanded navigation.

## Functionality and honesty constraints

This `/curator-preview` experience is a **visual preview**, with example vaults/positions. It is *not* proof that market-creation transactions, vault management, portfolio indexing, transaction builders or wallet integration are complete. Do not display example amounts as real on-chain balances. The main production `/vaults`, `/api/opportunities` and market-discovery Worker routes are separate and must be preserved.

Fraxtal is the first target chain. New live transaction integration must use verified factory/controller contracts and actual ABI and receipt evidence; never assume a mock button submits on-chain.

## Editing handoff

1. Read this README, the visual manifest, and the current live Worker source; inspect relevant screenshot images before changing layout.
2. Decompress the three asset files above. Treat their resulting files as the **current served preview snapshot** and add the three CSS overlays to reconstruct its appearance.
3. Make the smallest necessary UI edits. Do not introduce redundant workflows, duplicate versions, or new contract source in Contract-Automation.
4. Browser-check reference fidelity, viewport overflow (especially Create button), collapsed/expanded sidebar, and the pages changed. No new automated test suites unless authorized.
5. Deploy via Cloudflare Ops only after merging with the latest Worker code and preserving bindings, APIs, wallet/transaction functions and other agents' collector changes.
6. Update the canonical source snapshot and this README when approved changes are live. Provide deployed Worker version and evidence, distinguishing preview-only from actual on-chain support.

Historical ZIP versions 1–8 and local preview screenshots were generated in the ChatGPT conversation. The **original visual authority screenshot archive is now committed in this repository** at [`visual-authority/Complete CurveYield MarketPlace Visual Authority Images.zip`](visual-authority/Complete%20CurveYield%20MarketPlace%20Visual%20Authority%20Images.zip), alongside the filename/checksum mapping. The archive was moved intact from the repository root (Git blob SHA `f1c0e802502c0eb60820562a0bbf1b2e3d1ef638`, 5,597,806 bytes). Extract the images to compare visual placement; do not confuse the demonstration screenshots with Morpho source authority.
