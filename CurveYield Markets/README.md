# CurveYield Markets

Canonical folder for CurveYield's marketplace research, listings, and web application artifacts.

## Find what you need

- **[Marketplace Web UI](Marketplace%20Web%20UI/README.md)** — current curator preview source snapshot, setup instructions, responsive design decisions, visual authority manifest, and deployment handoff. Start here for web UI work.
- **[USDC](USDC/)** — verified USDC market discovery opportunities. The former root-level `Curveyield Markets` folder was consolidated here without changing the CSV blob.
- `Verified WBTC Opportunities list_v7.md` — latest existing WBTC research list at the time of this handoff (earlier numbered lists are historical and were not modified).
- `Verified ETH Opportunities v2.md` — ETH research.
- `MARKET_DISCOVERY_INTEGRATION_CHECKLIST_v6.md` — collector protocol integration tracking.

## Boundaries

The live site and backend are deployed through the **Cloudflare Worker `markets`** at https://markets.curveyield.org/. GitHub is a durable project source/handoff repository, **not** an automatic Worker deployment mechanism. Check the live Worker before changing or redeploying it; other agents may be updating the market discovery collectors simultaneously.

This folder is in `curveyield3/Smart-Contracts`. **Do not use Contract-Automation for website or smart-contract source storage.**
