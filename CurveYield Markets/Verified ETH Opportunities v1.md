# Verified ETH Opportunities v1 — Ethereum mainnet

**Capture date:** November 17, 2026. ETH CurveYield source snapshot 15:59:15 UTC, WETH snapshot 15:59:39 UTC; live dedicated dapp page inspection approximately 16:02–16:08 UTC. Chain ID 1. This list inventories all **7 direct native ETH + 122 direct WETH = 129** catalog matches at the source capture, not all ETH derivative, underlying LP basket, or conversion routes.

**Method:** Each numbered opportunity uses two lines followed by a blank line. Line 1 preserves CurveYield's protocol, market, asset, identity, USD TVL, APR/APY and provider source. Line 2 records the exact dapp and *its own* USD TVL/total deposits, its own APY/rate, utilization for lending markets where present, relevant details, and discrepancy assessment. Never treat a general protocol-wide TVL as an individual vault's TVL; for Morpho vaults use official **Total Deposits (USD)**. A source-only number is **never substituted** for a missing dapp number.

**Reconciliation rules:** TVL difference >5% = **TVL DISCREPANCY**; nominal yield difference >0.30 percentage points = **YIELD DISCREPANCY**, except Yearn legacy 30-day versus current estimates are explicitly called **YIELD-PERIOD MISMATCH**. Morpho's source rolling-average supply APY and the dapp 6-hour lender rate have different averaging windows. Even two matching observations do not certify safety, direct compatibility, deposit availability, or yield sustainability. Some dapps require browser JavaScript and do not publish numeric values in accessible HTML. Repeated catalog records can reference the same underlying vault or one generic dapp URL; never add their TVLs together.

**Results:** 129 source records; 84 with both dapp TVL/deposits and rate; 4 with dapp TVL/deposits only; 41 without market-specific dapp numbers; 1 material TVL discrepancy; 2 differing Yearn yield windows; 0 other rate discrepancy; 24 records with dapp lending market utilization; 6 unresolved dapp URLs; 10 records with 404 dapp URLs; 19 index-only entries.

**Audit evidence:** [CurveYield discovery](https://markets.curveyield.org/opportunities) · [Source inventory GitHub run](https://github.com/curveyield3/Smart-Contracts/actions/runs/44120454222) · [All dapp pages inspection run](https://github.com/curveyield3/Smart-Contracts/actions/runs/44121138709) · [Morpho vault detailed inspection run](https://github.com/curveyield3/Smart-Contracts/actions/runs/44121992678).

---

## Numbered ETH/WETH opportunities

**001. Aave V3 — AaveV3Ethereum WETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2` · **CurveYield:** TVL **$3,779,121,511**, **1.45% APY** ([source](https://api.v3.aave.com/graphql))
Dapp: [Aave - Open Source Liquidity Protocol](https://app.aave.com/reserve-overview/?underlyingAsset=0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2&marketName=proto_mainnet_v3) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED**.

**002. Fluid Lending — ETH** · **Lending market** · ETH `native ETH (zero-address marker)` · catalog pool UUID `e72916f7-a2d1-47ad-a4b9-2b054337cfd6` · **CurveYield:** TVL **$143,675,197**, **3.95% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Exact opportunity dapp](https://fluid.io/lending/1/eth?mode=deposit) · **TVL not readable** · **APY not readable** · market utilization not readable · **LINK ERROR** · index-only: no verified direct deposit compatibility; same dapp URL as 6 other catalog record(s); distinct identity unconfirmed; linked dapp returned HTTP Error 404: Not Found.

**003. SparkLend — WETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `24195b31-d749-445f-bf9e-b65aa025ebdd` · **CurveYield:** TVL **$117,069,490**, **1.74% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Spark: Earn on your stablecoins](https://app.spark.finance/market-details/1/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED** · index-only: no verified direct deposit compatibility; same dapp URL as 1 other catalog record(s); distinct identity unconfirmed.

**004. Compound III — USDC-pool** · **Lending market — WETH collateral only** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `072f6554-daa7-4708-80ba-371b896a89db` · **CurveYield:** TVL **$111,166,452**, **0.00% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Compound Markets](https://app.compound.xyz/markets/usdc-mainnet) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED** · collateral-only, no interest on WETH in the USDC/USDT base-asset pool; index-only: no verified direct deposit compatibility.

**005. Aave V4 — Main WETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x94e7a5dcbe816e498b89ab752661904e2f56c485` · **CurveYield:** TVL **$86,632,102**, **1.65% APY** ([source](https://api.v4.aave.com/graphql))
Dapp: [ETH in Main on Core, Ethereum · Aave Pro](https://pro.aave.com/explore/reserve/MTo6MHg5NGU3QTVkQ2JFODE2ZTQ5OGI4OWFCNzUyNjYxOTA0RTJGNTZjNDg1Ojow) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED**.

**006. Compound III — USDT-pool** · **Lending market — WETH collateral only** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `94657e4e-5345-48f0-9132-f7a709e2021e` · **CurveYield:** TVL **$69,627,015**, **0.00% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Compound Markets](https://app.compound.xyz/markets/usdt-mainnet) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED** · collateral-only, no interest on WETH in the USDC/USDT base-asset pool; index-only: no verified direct deposit compatibility.

**007. Fluid Lending — ETH** · **Lending market** · ETH `native ETH (zero-address marker)` · catalog pool UUID `cbb9fc26-2b9e-436a-95d0-c75e2c0f5869` · **CurveYield:** TVL **$69,064,054**, **1.53% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Exact opportunity dapp](https://fluid.io/lending/1/eth?mode=deposit) · **TVL not readable** · **APY not readable** · market utilization not readable · **LINK ERROR** · index-only: no verified direct deposit compatibility; same dapp URL as 6 other catalog record(s); distinct identity unconfirmed; linked dapp returned HTTP Error 404: Not Found.

**008. Morpho Blue — WETH / wstETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0xb8fc70e82bc5bb53e773626fcc6a23f7eefa036918d7ef216ecfb1950a94a85e` · **CurveYield:** TVL **$55,774,503**, **1.83% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| wstETH 96.5%](https://app.morpho.org/ethereum/variable/0xb8fc70e82bc5bb53e773626fcc6a23f7eefa036918d7ef216ecfb1950a94a85e/weth-wsteth) · **total market size $55,940,000** · **6h lend rate 1.83%** · market utilization 88.50% · borrow rate (6h) 2.07% · LLTV 96.50% · liquidity $6,430,000 · outstanding loans $49,510,000 · **DAPP TVL + RATE READ**.

**009. SparkLend — ETH** · **Lending market** · ETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `bace601a-530a-432c-9b79-8c6451de25ea` · **CurveYield:** TVL **$50,036,273**, **1.80% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Spark: Earn on your stablecoins](https://app.spark.finance/market-details/1/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED** · index-only: no verified direct deposit compatibility; same dapp URL as 1 other catalog record(s); distinct identity unconfirmed.

**010. Compound II — WETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `1e5da7c6-59bb-49bd-9f97-4f4fceeffad4` · **CurveYield:** TVL **$39,087,745**, **0.00% APY** ([source](https://yields.llama.fi/pools))
Dapp: **Exact dapp page unresolved** · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED** · index-only: no verified direct deposit compatibility; exact dapp page unresolved.

**011. Yearn V3 — Katana Pre-Deposit WETH** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xcc6a16be713f6a714f68b0e1f4914fd3db15fbef` · **CurveYield:** TVL **$34,126,362**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Yearn Finance](https://yearn.fi/vaults/1/0xcc6a16be713f6a714f68b0e1f4914fd3db15fbef) · **TVL not readable** · **estimated APY not readable** · **DAPP METRICS NOT VERIFIED**.

**012. Yearn V3 — Katana WETH STB Depositor** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x30eaacad508ba57b30edafa1ad6bd337b211a9de` · **CurveYield:** TVL **$34,126,362**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Katana WETH STB Depositor (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x30eaacad508ba57b30edafa1ad6bd337b211a9de) · **TVL $34,100,000** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 10% · **DAPP TVL + RATE READ**.

**013. Aave V3 — AaveV3EthereumLido WETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x4e033931ad43597d96d6bcc25c280717730b58b1` · **CurveYield:** TVL **$33,685,380**, **1.53% APY** ([source](https://api.v3.aave.com/graphql))
Dapp: [Aave - Open Source Liquidity Protocol](https://app.aave.com/reserve-overview/?underlyingAsset=0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2&marketName=proto_lido_v3) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED**.

**014. Fluid Lending — ETH** · **Lending market** · ETH `native ETH (zero-address marker)` · catalog pool UUID `1262521f-3ba5-47d7-b035-ace072a0d0df` · **CurveYield:** TVL **$29,549,153**, **1.53% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Exact opportunity dapp](https://fluid.io/lending/1/eth?mode=deposit) · **TVL not readable** · **APY not readable** · market utilization not readable · **LINK ERROR** · index-only: no verified direct deposit compatibility; same dapp URL as 6 other catalog record(s); distinct identity unconfirmed; linked dapp returned HTTP Error 404: Not Found.

**015. Compound III — ETH** · **Lending market** · ETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `85c57261-b75b-4447-a115-d79b1a7de8ed` · **CurveYield:** TVL **$24,775,870**, **1.47% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Compound Markets](https://app.compound.xyz/markets/weth-mainnet) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED** · index-only: no verified direct deposit compatibility.

**016. Morpho Vault V2 — Steakhouse Prime ETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xbeef0046fcab1de47e41fb75bb3dc4dfc94108e3` · **CurveYield:** TVL **$21,122,274**, **1.74% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Steakhouse Prime ETH](https://app.morpho.org/ethereum/vault/0xbeef0046fcab1de47e41fb75bb3dc4dfc94108e3/steakhouse-prime-eth) · **total deposits $21,500,000** · **net / instant APY 1.73%** · 30-day APY 1.97% · performance fee 5% · **DAPP TVL + RATE READ**.

**017. Morpho Vault V2 — Gauntlet WETH Prime** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x43fcd85e8d9d003d515f886891b7c742ac9f92da` · **CurveYield:** TVL **$17,311,522**, **1.84% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Gauntlet WETH Prime](https://app.morpho.org/ethereum/vault/0x43fcd85e8d9d003d515f886891b7c742ac9f92da/gauntlet-weth-prime) · **total deposits $17,620,000** · **net / instant APY 1.82%** · 30-day APY 2.09% · performance fee 0% · **DAPP TVL + RATE READ**.

**018. Morpho Blue — WETH / wstETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0xd0e50cdac92fe2172043f5e0c36532c6369d24947e40968f34a5e8819ca9ec5d` · **CurveYield:** TVL **$14,771,236**, **1.83% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| wstETH 94.5%](https://app.morpho.org/ethereum/variable/0xd0e50cdac92fe2172043f5e0c36532c6369d24947e40968f34a5e8819ca9ec5d/weth-wsteth) · **total market size $14,810,000** · **6h lend rate 1.83%** · market utilization 88.23% · borrow rate (6h) 2.07% · LLTV 94.50% · liquidity $1,740,000 · outstanding loans $13,070,000 · **DAPP TVL + RATE READ**.

**019. Morpho Vault V1 — Vault Bridge WETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x31a5684983eee865d943a696aac155363ba024f9` · **CurveYield:** TVL **$11,013,418**, **1.57% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Vault Bridge WETH](https://app.morpho.org/ethereum/vault/0x31a5684983eee865d943a696aac155363ba024f9/vault-bridge-weth) · **total deposits $11,210,000** · **net / instant APY 1.56%** · 30-day APY 1.79% · performance fee 5.00% · **DAPP TVL + RATE READ**.

**020. IPOR Fusion — rETH Liquity LP Carry** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `b01b6734-1ceb-4427-8a03-36fe9bd726b1` · **CurveYield:** TVL **$10,810,089**, **5.25% APY** ([source](https://yields.llama.fi/pools))
Dapp: **Exact dapp page unresolved** · **TVL not readable** · **APY not readable** · **DAPP METRICS NOT VERIFIED** · index-only: no verified direct deposit compatibility; exact dapp page unresolved.

**021. IPOR Fusion — rETH Liquity LP Carry** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xb9e806e8f2d94c015ffefa90cd24ecce18f1663c` · **CurveYield:** TVL **$10,570,514**, **4.85% APY** ([source](https://api.ipor.io/v2/fusion/vaults))
Dapp: [Fusion by IPOR \| Onchain Vault Infrastructure](https://app.ipor.io/fusion/ethereum/0xb9e806e8f2d94c015ffefa90cd24ecce18f1663c/vault-info) · **TVL not readable** · **APY not readable** · **DAPP METRICS NOT VERIFIED**.

**022. Yearn Vaults — WETH** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xc56413869c6cdf96496f2b1ef801fedbdfa7ddb0` · **CurveYield:** TVL **$9,164,853**, **3.01% APY** ([source](https://yields.llama.fi/pools))
Dapp: [WETH (yvWETH) \| Yearn](https://yearn.fi/vaults/1/0xc56413869c6cdf96496f2b1ef801fedbdfa7ddb0) · **TVL $9,070,000** · **estimated APY 1.84%** · 30-day APY 3.01% · vault type Single Asset | Allocator · performance fee 10% · risk 1/5 · **YIELD-PERIOD MISMATCH** · source APY matches dapp 30d APY instead of current estimated APY; same dapp URL as 1 other catalog record(s); distinct identity unconfirmed.

**023. Yearn V3 — WETH-1 yVault** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xc56413869c6cdf96496f2b1ef801fedbdfa7ddb0` · **CurveYield:** TVL **$9,065,833**, **1.84% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [WETH (yvWETH) \| Yearn](https://yearn.fi/vaults/1/0xc56413869c6cdf96496f2b1ef801fedbdfa7ddb0) · **TVL $9,070,000** · **estimated APY 1.84%** · 30-day APY 3.01% · vault type Single Asset | Allocator · performance fee 10% · risk 1/5 · **DAPP TVL + RATE READ** · same dapp URL as 1 other catalog record(s); distinct identity unconfirmed.

**024. Yearn Vaults — WETH** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xac37729b76db6438ce62042ae1270ee574ca7571` · **CurveYield:** TVL **$7,723,758**, **2.41% APY** ([source](https://yields.llama.fi/pools))
Dapp: [WETH-2 (yvWETH-2) \| Yearn](https://yearn.fi/vaults/1/0xac37729b76db6438ce62042ae1270ee574ca7571) · **TVL $7,640,000** · **estimated APY 2.98%** · 30-day APY 2.41% · vault type Single Asset | Allocator · performance fee 10% · risk 2/5 · **YIELD-PERIOD MISMATCH** · source APY matches dapp 30d APY instead of current estimated APY; same dapp URL as 1 other catalog record(s); distinct identity unconfirmed.

**025. Yearn V3 — WETH-2 yVault** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xac37729b76db6438ce62042ae1270ee574ca7571` · **CurveYield:** TVL **$7,640,308**, **2.98% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [WETH-2 (yvWETH-2) \| Yearn](https://yearn.fi/vaults/1/0xac37729b76db6438ce62042ae1270ee574ca7571) · **TVL $7,640,000** · **estimated APY 2.98%** · 30-day APY 2.41% · vault type Single Asset | Allocator · performance fee 10% · risk 2/5 · **DAPP TVL + RATE READ** · same dapp URL as 1 other catalog record(s); distinct identity unconfirmed.

**026. Morpho Blue — WETH / weETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x37e7484d642d90f14451f1910ba4b7b8e4c3ccdd0ec28f8b2bdb35479e472ba7` · **CurveYield:** TVL **$7,215,179**, **1.87% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| weETH 94.5%](https://app.morpho.org/ethereum/variable/0x37e7484d642d90f14451f1910ba4b7b8e4c3ccdd0ec28f8b2bdb35479e472ba7/weth-weeth) · **total market size $7,230,000** · **6h lend rate 1.86%** · market utilization 86.73% · borrow rate (6h) 2.14% · LLTV 94.50% · liquidity $959,780 · outstanding loans $6,270,000 · **DAPP TVL + RATE READ**.

**027. Yearn V2 — WETH yVault** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xa258c4606ca8206d8aa700ce2143d7db854d168c` · **CurveYield:** TVL **$6,682,618**, **2.75% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [WETH yVault (yvWETH) \| Yearn](https://yearn.fi/vaults/1/0xa258c4606ca8206d8aa700ce2143d7db854d168c) · **TVL $6,680,000** · **estimated APY 2.75%** · 30-day APY 2.75% · vault type Legacy | Legacy · performance fee 0% · **DAPP TVL + RATE READ**.

**028. Morpho Vault V1 — Steakhouse ETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xbeef050ecd6a16c4e7bffbb52ebba7846c4b8cd4` · **CurveYield:** TVL **$6,125,291**, **1.74% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Steakhouse ETH](https://app.morpho.org/ethereum/vault/0xbeef050ecd6a16c4e7bffbb52ebba7846c4b8cd4/steakhouse-eth) · **total deposits $6,230,000** · **net / instant APY 1.73%** · 30-day APY 1.98% · performance fee 5.00% · **DAPP TVL + RATE READ**.

**029. Morpho Vault V1 — Gauntlet WETH Prime** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x2371e134e3455e0593363cbf89d3b6cf53740618` · **CurveYield:** TVL **$5,443,453**, **1.75% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Gauntlet WETH Prime](https://app.morpho.org/ethereum/vault/0x2371e134e3455e0593363cbf89d3b6cf53740618/gauntlet-weth-prime) · **total deposits $5,540,000** · **net / instant APY 1.73%** · 30-day APY 1.99% · performance fee 5.00% · **DAPP TVL + RATE READ**.

**030. Yearn V3 — stETH Accumulator** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x470e0e048f85cfd72eef325895e02c8d297e7435` · **CurveYield:** TVL **$5,034,722**, **2.29% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [stETH Accumulator (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x470e0e048f85cfd72eef325895e02c8d297e7435) · **TVL $5,030,000** · **estimated APY 2.29%** · 30-day APY 2.81% · vault type Single Asset | Strategy · performance fee 0% · **DAPP TVL + RATE READ**.

**031. Morpho Vault V2 — Galaxy WETH Quality** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x1878805799273d10ae96a58201a6f5254cf9824f` · **CurveYield:** TVL **$4,822,056**, **2.61% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Galaxy WETH Quality](https://app.morpho.org/ethereum/vault/0x1878805799273d10ae96a58201a6f5254cf9824f/galaxy-weth-quality) · **total deposits $4,900,000** · **net / instant APY 2.62%** · 30-day APY 2.21% · performance fee 0% · **DAPP TVL + RATE READ**.

**032. Yearn V3 — Spark wstETH to yvUSD Lender Borrower Accumulator** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x13f6cb609959a43c3be29407766a683b42e26d28` · **CurveYield:** TVL **$4,536,244**, **3.34% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Spark wstETH to yvUSD Lender Borrower Accumulator (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x13f6cb609959a43c3be29407766a683b42e26d28) · **TVL $4,530,000** · **estimated APY 3.34%** · 30-day APY 3.39% · vault type Single Asset | Strategy · performance fee 0% · **DAPP TVL + RATE READ**.

**033. Yearn V3 — Yearn yETH Recovery Vault** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xd7a540ba3626c0aa66e7db4088971d0cd64695b6` · **CurveYield:** TVL **$4,404,491**, **2.05% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Yearn Finance](https://yearn.fi/vaults/1/0xd7a540ba3626c0aa66e7db4088971d0cd64695b6) · **TVL not readable** · **estimated APY not readable** · **DAPP METRICS NOT VERIFIED**.

**034. Aave V4 — Bluechip WETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x973a023a77420ba610f06b3858ad991df6d85a08` · **CurveYield:** TVL **$4,220,525**, **0.00% APY** ([source](https://api.v4.aave.com/graphql))
Dapp: [ETH in Bluechip on Prime, Ethereum · Aave Pro](https://pro.aave.com/explore/reserve/MTo6MHg5NzNhMDIzQTc3NDIwYmE2MTBmMDZiMzg1OGFEOTkxRGY2ZDg1QTA4Ojow) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED**.

**035. Morpho Blue — WETH / amphrETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x11db9f2c7bda8c2af6a6a72db18aa5eb9290cb99cf75a3c0abacf1b84b8eaf77` · **CurveYield:** TVL **$3,962,708**, **not readable APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| amphrETH 86%](https://app.morpho.org/ethereum/variable/0x11db9f2c7bda8c2af6a6a72db18aa5eb9290cb99cf75a3c0abacf1b84b8eaf77/weth-amphreth) · **total market size $3,970,000** · **6h lend rate >1,000%** · market utilization 100.00% · LLTV 86.00% · outstanding loans $3,970,000 · **DAPP TVL + RATE READ** · extreme >1,000% current rate / minimal liquidity.

**036. Morpho Vault V2 — Trezor Steakhouse ETH Prime** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x704cfb08969048a8dff298b214f959791d8da509` · **CurveYield:** TVL **$3,507,160**, **2.50% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Exact opportunity dapp](https://app.morpho.org/ethereum/vault/0x704cfb08969048a8dff298b214f959791d8da509/trezor-steakhouse-eth-prime) · **total deposits not readable** · **net / instant APY not readable** · **LINK ERROR** · linked dapp returned HTTP Error 404: Not Found.

**037. Yearn V3 — Spark WETH Lender** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xfca3f21d60d5bc8b4c5c35f169bb5b6402510151` · **CurveYield:** TVL **$3,500,201**, **1.75% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Spark WETH Lender (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0xfca3f21d60d5bc8b4c5c35f169bb5b6402510151) · **TVL $3,500,000** · **estimated APY 1.75%** · 30-day APY 1.75% · vault type Single Asset | Strategy · performance fee 0% · **DAPP TVL + RATE READ**.

**038. Morpho Vault V1 — MEV Capital wETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x9a8bc3b04b7f3d87cfc09ba407dced575f2d61d8` · **CurveYield:** TVL **$3,265,526**, **1.65% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| MEV Capital wETH](https://app.morpho.org/ethereum/vault/0x9a8bc3b04b7f3d87cfc09ba407dced575f2d61d8/mev-capital-weth) · **total deposits $3,320,000** · **net / instant APY 1.64%** · 30-day APY 1.86% · performance fee 10.00% · **DAPP TVL + RATE READ**.

**039. Morpho Blue — WETH / savETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0xd98cd88ae5b336086b39fb1d62ba6171282e946105b010143f0e89f8fe7cff36` · **CurveYield:** TVL **$3,264,677**, **2.38% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| savETH 91.5%](https://app.morpho.org/ethereum/variable/0xd98cd88ae5b336086b39fb1d62ba6171282e946105b010143f0e89f8fe7cff36/weth-saveth) · **total market size $3,270,000** · **6h lend rate 2.37%** · market utilization 83.39% · borrow rate (6h) 3.08% · LLTV 91.50% · liquidity $543,640 · outstanding loans $2,730,000 · **DAPP TVL + RATE READ**.

**040. Morpho Vault V2 — KPK ETH Yield** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x5dbf760b4fd0cddde0366b33aeb338b2a6d77725` · **CurveYield:** TVL **$2,761,589**, **2.38% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| KPK ETH Yield](https://app.morpho.org/ethereum/vault/0x5dbf760b4fd0cddde0366b33aeb338b2a6d77725/kpk-eth-yield) · **total deposits $2,810,000** · **net / instant APY 2.49%** · 30-day APY 2.91% · performance fee 0% · **DAPP TVL + RATE READ**.

**041. Morpho Vault V2 — Uniswap ETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x98d2b241da14c5dd848812708eb8a1f3c5512f9d` · **CurveYield:** TVL **$2,207,138**, **1.84% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Uniswap ETH](https://app.morpho.org/ethereum/vault/0x98d2b241da14c5dd848812708eb8a1f3c5512f9d/uniswap-eth) · **total deposits $2,240,000** · **net / instant APY 1.82%** · 30-day APY 1.95% · performance fee 0% · **DAPP TVL + RATE READ**.

**042. Yearn V3 — wstETH/WETH Spark Looper** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x68a14629cb07c74259f481382fe8b6cfd8970121` · **CurveYield:** TVL **$1,888,077**, **3.58% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [wstETH/WETH Spark Looper (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x68a14629cb07c74259f481382fe8b6cfd8970121) · **TVL $1,890,000** · **estimated APY 3.58%** · 30-day APY 8.27% · vault type Single Asset | Strategy · performance fee 0% · **DAPP TVL + RATE READ**.

**043. Yearn V3 — Katana Pre-Deposit WETH** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x77570cfecf83bc6bb08e2cd9e8537aea9f97ea2f` · **CurveYield:** TVL **$1,752,199**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Yearn Finance](https://yearn.fi/vaults/1/0x77570cfecf83bc6bb08e2cd9e8537aea9f97ea2f) · **TVL not readable** · **estimated APY not readable** · **DAPP METRICS NOT VERIFIED**.

**044. Yearn V3 — Katana WETH STB Depositor** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x20e76ea28e13867c008d319ba4ede86f6c1fed73` · **CurveYield:** TVL **$1,752,199**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Katana WETH STB Depositor (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x20e76ea28e13867c008d319ba4ede86f6c1fed73) · **TVL $1,750,000** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 10% · **DAPP TVL + RATE READ**.

**045. Fluid Lending — ETH** · **Lending market** · ETH `native ETH (zero-address marker)` · catalog pool UUID `8966809c-9377-44bf-b72e-a95fe490fece` · **CurveYield:** TVL **$1,638,236**, **1.53% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Exact opportunity dapp](https://fluid.io/lending/1/eth?mode=deposit) · **TVL not readable** · **APY not readable** · market utilization not readable · **LINK ERROR** · index-only: no verified direct deposit compatibility; same dapp URL as 6 other catalog record(s); distinct identity unconfirmed; linked dapp returned HTTP Error 404: Not Found.

**046. Morpho Vault V1 — Gauntlet LRT Core** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x4881ef0bf6d2365d3dd6499ccd7532bcdbce0658` · **CurveYield:** TVL **$1,520,388**, **1.65% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Gauntlet LRT Core](https://app.morpho.org/ethereum/vault/0x4881ef0bf6d2365d3dd6499ccd7532bcdbce0658/gauntlet-lrt-core) · **total deposits $1,540,000** · **net / instant APY 1.64%** · 30-day APY 1.88% · performance fee 10.00% · **DAPP TVL + RATE READ**.

**047. Fluid Lending — WETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `82da3bb0-00b6-4d88-b720-8435a3affd48` · **CurveYield:** TVL **$1,434,838**, **1.53% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Exact opportunity dapp](https://fluid.io/lending/1/weth?mode=deposit) · **TVL not readable** · **APY not readable** · market utilization not readable · **LINK ERROR** · index-only: no verified direct deposit compatibility; linked dapp returned HTTP Error 404: Not Found.

**048. Euler EVK — EVK Vault eWETH-2** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xd8b27cf359b7d15710a5be299af6e7bf904984c2` · **CurveYield:** TVL **$1,339,541**, **147.51% APY** ([source](https://v3.euler.finance/v3/evk/vaults?chainId=1))
Dapp: [Euler Finance](https://app.euler.finance/vault/0xd8b27cf359b7d15710a5be299af6e7bf904984c2?network=ethereum) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED**.

**049. Yearn V3 — Spark WETH/USDS (yvUSD) Lender Borrower** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x5e8a9acd00adced69b30d36929cbf7d4d4f9ae1f` · **CurveYield:** TVL **$1,219,376**, **2.83% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Spark WETH/USDS (yvUSD) Lender Borrower (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x5e8a9acd00adced69b30d36929cbf7d4d4f9ae1f) · **TVL $1,220,000** · **estimated APY 2.83%** · vault type Single Asset | Strategy · performance fee 0% · **DAPP TVL + RATE READ**.

**050. Morpho Blue — WETH / uncollateralized** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x58e212060645d18eab6d9b2af3d56fbc906a92ff5667385f616f662c70372284` · **CurveYield:** TVL **$1,176,764**, **0.00% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH](https://app.morpho.org/ethereum/variable/0x58e212060645d18eab6d9b2af3d56fbc906a92ff5667385f616f662c70372284/weth-uncollateralized) · **total market size $1,180,000** · **6h lend rate 0.00%** · market utilization 0.00% · borrow rate (6h) 0.00% · LLTV 0.00% · liquidity $1,180,000 · outstanding loans $0.00 · **DAPP TVL + RATE READ**.

**051. Morpho Vault V1 — Index Coop hyETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x701907283a57ff77e255c3f1aad790466b8ce4ef` · **CurveYield:** TVL **$1,144,262**, **1.65% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Index Coop hyETH](https://app.morpho.org/ethereum/vault/0x701907283a57ff77e255c3f1aad790466b8ce4ef/index-coop-hyeth) · **total deposits $1,160,000** · **net / instant APY 1.64%** · 30-day APY 1.86% · performance fee 10.00% · **DAPP TVL + RATE READ**.

**052. Fluid Lending — ETH** · **Lending market** · ETH `native ETH (zero-address marker)` · catalog pool UUID `49373934-7cf1-48c2-a708-94e52f552ff3` · **CurveYield:** TVL **$989,308**, **1.53% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Exact opportunity dapp](https://fluid.io/lending/1/eth?mode=deposit) · **TVL not readable** · **APY not readable** · market utilization not readable · **LINK ERROR** · index-only: no verified direct deposit compatibility; same dapp URL as 6 other catalog record(s); distinct identity unconfirmed; linked dapp returned HTTP Error 404: Not Found.

**053. Morpho Vault V2 — Gauntlet WETH Balanced** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x5f342382d5f77f0f99e8f26161e689df6c7cded3` · **CurveYield:** TVL **$836,645**, **1.84% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Gauntlet WETH Balanced](https://app.morpho.org/ethereum/vault/0x5f342382d5f77f0f99e8f26161e689df6c7cded3/gauntlet-weth-balanced) · **total deposits $851,750** · **net / instant APY 1.82%** · 30-day APY 2.08% · performance fee 0% · **DAPP TVL + RATE READ**.

**054. Morpho Vault V2 — KPK ETH Prime** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xbb50a5341368751024ddf33385ba8cf61fe65ff9` · **CurveYield:** TVL **$619,876**, **1.84% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| KPK ETH Prime](https://app.morpho.org/ethereum/vault/0xbb50a5341368751024ddf33385ba8cf61fe65ff9/kpk-eth-prime) · **total deposits $631,060** · **net / instant APY 1.82%** · 30-day APY 2.22% · performance fee 0% · **DAPP TVL + RATE READ**.

**055. Yearn Vaults — WETH** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `446f4bcd-5b02-5456-95e2-015aa435a194` · **CurveYield:** TVL **$567,821**, **1.27% APY** ([source](https://yields.llama.fi/pools))
Dapp: **Exact dapp page unresolved** · **TVL not readable** · **estimated APY not readable** · **DAPP METRICS NOT VERIFIED** · index-only: no verified direct deposit compatibility; exact dapp page unresolved.

**056. Yearn V3 — Flex WETH yVault** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xfac55fafd0b55bfb8dd41f735efcc195ada9891f` · **CurveYield:** TVL **$561,686**, **1.74% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Flex WETH yVault (yvFlexWETH) \| Yearn](https://yearn.fi/vaults/1/0xfac55fafd0b55bfb8dd41f735efcc195ada9891f) · **TVL $561,000** · **estimated APY 1.74%** · 30-day APY 1.28% · vault type Single Asset | Allocator · performance fee 10% · risk 1/5 · **DAPP TVL + RATE READ**.

**057. Yearn V3 — Flex yvWETH-2/WETH Lender** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x7e4a6a89583e117c641ab3ce8897209800a3f2e3` · **CurveYield:** TVL **$561,686**, **1.94% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Flex yvWETH-2/WETH Lender (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x7e4a6a89583e117c641ab3ce8897209800a3f2e3) · **TVL $561,000** · **estimated APY 1.94%** · 30-day APY 1.59% · vault type Single Asset | Strategy · performance fee 0% · **DAPP TVL + RATE READ**.

**058. Morpho Vault V1 — Yearn OG WETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xe89371eaaac6d46d4c3ed23453241987916224fc` · **CurveYield:** TVL **$545,071**, **1.75% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Yearn OG WETH](https://app.morpho.org/ethereum/vault/0xe89371eaaac6d46d4c3ed23453241987916224fc/yearn-og-weth) · **total deposits $554,910** · **net / instant APY 1.73%** · 30-day APY 2.04% · performance fee 5.00% · **DAPP TVL + RATE READ**.

**059. Morpho Vault V2 — SingularV ETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xf39ac02dec8fae8292d5f42202e4cd885356256b` · **CurveYield:** TVL **$530,028**, **1.75% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| SingularV ETH](https://app.morpho.org/ethereum/vault/0xf39ac02dec8fae8292d5f42202e4cd885356256b/singularv-eth) · **total deposits $539,590** · **net / instant APY 1.74%** · 30-day APY 1.91% · performance fee 5% · **DAPP TVL + RATE READ**.

**060. Morpho Vault V1 — Re7 WETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x78fc2c2ed1a4cdb5402365934ae5648adad094d0` · **CurveYield:** TVL **$503,972**, **1.46% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Re7 WETH](https://app.morpho.org/ethereum/vault/0x78fc2c2ed1a4cdb5402365934ae5648adad094d0/re7-weth) · **total deposits $513,070** · **net / instant APY 1.46%** · 30-day APY 1.82% · performance fee 20.00% · **DAPP TVL + RATE READ**.

**061. Yearn V2 — WETH yVault** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xa9fe4601811213c340e850ea305481aff02f5b28` · **CurveYield:** TVL **$391,425**, **1.22% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [WETH yVault (yvWETH) \| Yearn](https://yearn.fi/vaults/1/0xa9fe4601811213c340e850ea305481aff02f5b28) · **TVL $391,000** · **estimated APY 1.22%** · 30-day APY 1.22% · vault type Legacy | Legacy · performance fee 0% · **DAPP TVL + RATE READ**.

**062. Fluid Lending — ETH** · **Lending market** · ETH `native ETH (zero-address marker)` · catalog pool UUID `7482f0b2-2ea1-4cef-82b9-d09192bbe2e9` · **CurveYield:** TVL **$237,011**, **1.53% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Exact opportunity dapp](https://fluid.io/lending/1/eth?mode=deposit) · **TVL not readable** · **APY not readable** · market utilization not readable · **LINK ERROR** · index-only: no verified direct deposit compatibility; same dapp URL as 6 other catalog record(s); distinct identity unconfirmed; linked dapp returned HTTP Error 404: Not Found.

**063. Beefy Vaults — WETH (Steakhouse, Steakhouse)** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x68ad3f6da23ad1cd24cb5089492ccf186bfbbe7b` · **CurveYield:** TVL **$198,944**, **1.58% APY** ([source](https://api.beefy.finance/vaults))
Dapp: [Beefy](https://app.beefy.com/vault/morpho-steakhouse-weth) · **TVL not readable** · **APY not readable** · **DAPP METRICS NOT VERIFIED**.

**064. Morpho Blue — WETH / LsETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0xd601632eb1345413cde7418f228513bae6ca7fdc52a00384ea9239c2a9f9a935` · **CurveYield:** TVL **$179,256**, **31.97% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| LsETH 86%](https://app.morpho.org/ethereum/variable/0xd601632eb1345413cde7418f228513bae6ca7fdc52a00384ea9239c2a9f9a935/weth-lseth) · **total market size $179,820** · **6h lend rate 31.95%** · market utilization 99.56% · borrow rate (6h) 32.12% · liquidity $787.04 · outstanding loans $179,030 · **DAPP TVL + RATE READ**.

**065. Yearn V3 — ETH Meta Vault** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x26fcb50eec367ddab060ccf5e7394cecd95f7db2` · **CurveYield:** TVL **$152,783**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Yearn Finance](https://yearn.fi/vaults/1/0x26fcb50eec367ddab060ccf5e7394cecd95f7db2) · **TVL not readable** · **estimated APY not readable** · **DAPP METRICS NOT VERIFIED**.

**066. Morpho Blue — WETH / WBTC** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x138eec0e4a1937eb92ebc70043ed539661dd7ed5a89fb92a720b341650288a40` · **CurveYield:** TVL **$134,015**, **0.01% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| WBTC 91.5%](https://app.morpho.org/ethereum/variable/0x138eec0e4a1937eb92ebc70043ed539661dd7ed5a89fb92a720b341650288a40/weth-wbtc) · **total market size $134,430** · **6h lend rate 0.01%** · market utilization 24.28% · borrow rate (6h) 0.04% · LLTV 91.50% · liquidity $101,790 · outstanding loans $32,640 · **DAPP TVL + RATE READ**.

**067. Morpho Blue — WETH / cbBTC** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x2cbfb38723a8d9a2ad1607015591a78cfe3a5949561b39bde42c242b22874ec0` · **CurveYield:** TVL **$127,014**, **0.03% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| cbBTC 91.5%](https://app.morpho.org/ethereum/variable/0x2cbfb38723a8d9a2ad1607015591a78cfe3a5949561b39bde42c242b22874ec0/weth-cbbtc) · **total market size $127,400** · **6h lend rate 0.02%** · market utilization 45.81% · borrow rate (6h) 0.06% · LLTV 91.50% · liquidity $69,040 · outstanding loans $58,360 · **DAPP TVL + RATE READ**.

**068. CurveLend V1 — crvUSD borrow** · **Lending market — borrow/collateral index** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `653b9b46-53af-4122-811f-3b69ba1adc5e` · **CurveYield:** TVL **$118,713**, **0.00% APY** ([source](https://yields.llama.fi/pools))
Dapp: **Exact dapp page unresolved** · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED** · crvUSD borrow entry, not an independently confirmed WETH lender deposit; index-only: no verified direct deposit compatibility; exact dapp page unresolved.

**069. Yearn V3 — Morpho Gauntlet WETH Prime Compounder** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xeeb6be70ff212238419cd638fab17910cf61cbe7` · **CurveYield:** TVL **$113,585**, **1.88% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Morpho Gauntlet WETH Prime Compounder (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0xeeb6be70ff212238419cd638fab17910cf61cbe7) · **TVL $113,000** · **estimated APY 1.88%** · 30-day APY 3.57% · vault type Single Asset | Strategy · performance fee 0% · risk 1/5 · **DAPP TVL + RATE READ**.

**070. Morpho Vault V1 — Villandrando** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x47fe8ab9ee47dd65c24df52324181790b9f47efc` · **CurveYield:** TVL **$104,333**, **1.19% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Villandrando](https://app.morpho.org/ethereum/vault/0x47fe8ab9ee47dd65c24df52324181790b9f47efc/villandrando) · **total deposits $106,210** · **net / instant APY 1.35%** · 30-day APY 1.58% · performance fee 50.00% · **DAPP TVL + RATE READ**.

**071. Morpho Vault V1 — Flagship ETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x38989bba00bdf8181f4082995b3deae96163ac5d` · **CurveYield:** TVL **$73,898**, **0.00% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Flagship ETH](https://app.morpho.org/ethereum/vault/0x38989bba00bdf8181f4082995b3deae96163ac5d/flagship-eth) · **total deposits $75,230** · **net / instant APY 0.00%** · 30-day APY 0.00% · performance fee 0.00% · **DAPP TVL + RATE READ**.

**072. Morpho Vault V1 — Safe x Steakhouse ETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xbeefb45b6f9acb175e70acf16dc20d6120044c70` · **CurveYield:** TVL **$67,971**, **1.65% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Safe x Steakhouse ETH](https://app.morpho.org/ethereum/vault/0xbeefb45b6f9acb175e70acf16dc20d6120044c70/safe-x-steakhouse-eth) · **total deposits $69,190** · **net / instant APY 1.64%** · 30-day APY 1.89% · performance fee 10.00% · **DAPP TVL + RATE READ**.

**073. Morpho Blue — WETH / cbBTC** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x12dbf4937132ff2c6445212519295ce9afbee3c765ba626af5b197fe6c3941a0` · **CurveYield:** TVL **$45,163**, **2.09% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| cbBTC 91.5%](https://app.morpho.org/ethereum/variable/0x12dbf4937132ff2c6445212519295ce9afbee3c765ba626af5b197fe6c3941a0/weth-cbbtc) · **total market size $6,740,000** · **6h lend rate 2.09%** · market utilization 90.10% · borrow rate (6h) 2.32% · LLTV 91.50% · liquidity $6,700,000 · outstanding loans $40,820 · **TVL DISCREPANCY** · TVL DISCREPANCY >5%.

**074. Fluid Lending — ETH** · **Lending market** · ETH `native ETH (zero-address marker)` · catalog pool UUID `13f4ca38-13f8-4e56-80fc-e7687f5d6599` · **CurveYield:** TVL **$42,919**, **1.53% APY** ([source](https://yields.llama.fi/pools))
Dapp: [Exact opportunity dapp](https://fluid.io/lending/1/eth?mode=deposit) · **TVL not readable** · **APY not readable** · market utilization not readable · **LINK ERROR** · index-only: no verified direct deposit compatibility; same dapp URL as 6 other catalog record(s); distinct identity unconfirmed; linked dapp returned HTTP Error 404: Not Found.

**075. IPOR Fusion — Reservoir ETH Yield** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `8f27e6d6-1d14-4611-8ea6-51482d0921ef` · **CurveYield:** TVL **$41,260**, **0.30% APY** ([source](https://yields.llama.fi/pools))
Dapp: **Exact dapp page unresolved** · **TVL not readable** · **APY not readable** · **DAPP METRICS NOT VERIFIED** · index-only: no verified direct deposit compatibility; exact dapp page unresolved.

**076. IPOR Fusion — Reservoir ETH Yield** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xf6cd9e8415162c8fb3c52676c7ca68812a34f76e` · **CurveYield:** TVL **$40,384**, **-0.61% APY** ([source](https://api.ipor.io/v2/fusion/vaults))
Dapp: [Fusion by IPOR \| Onchain Vault Infrastructure](https://app.ipor.io/fusion/ethereum/0xf6cd9e8415162c8fb3c52676c7ca68812a34f76e/vault-info) · **TVL not readable** · **APY not readable** · **DAPP METRICS NOT VERIFIED**.

**077. Morpho Blue — WETH / pufETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x85ab69d50add7daa0934b5224889af0a882f2e3b4572d82c771dd0875f4eaa9b` · **CurveYield:** TVL **$36,559**, **5.52% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| pufETH 94.5%](https://app.morpho.org/ethereum/variable/0x85ab69d50add7daa0934b5224889af0a882f2e3b4572d82c771dd0875f4eaa9b/weth-pufeth) · **total market size $36,670** · **6h lend rate 5.52%** · market utilization 76.98% · borrow rate (6h) 7.34% · LLTV 94.50% · liquidity $8,441.01 · outstanding loans $28,230 · **DAPP TVL + RATE READ**.

**078. CurveLend V1 — crvUSD borrow** · **Lending market — borrow/collateral index** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · catalog pool UUID `846d6185-1234-462e-a0bc-3092107dbf18` · **CurveYield:** TVL **$33,455**, **0.00% APY** ([source](https://yields.llama.fi/pools))
Dapp: **Exact dapp page unresolved** · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED** · crvUSD borrow entry, not an independently confirmed WETH lender deposit; index-only: no verified direct deposit compatibility; exact dapp page unresolved.

**079. Morpho Blue — WETH / wstETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0xc54d7acf14de29e0e5527cabd7a576506870346a78a11a6762e2cca66322ec41` · **CurveYield:** TVL **$27,687**, **1.81% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| wstETH 94.5%](https://app.morpho.org/ethereum/variable/0xc54d7acf14de29e0e5527cabd7a576506870346a78a11a6762e2cca66322ec41/weth-wsteth) · **total market size $27,770** · **6h lend rate 1.81%** · market utilization 89.47% · borrow rate (6h) 2.04% · LLTV 94.50% · liquidity $2,923.65 · outstanding loans $24,840 · **DAPP TVL + RATE READ**.

**080. Yearn V3 — WETH-2 yVault Liquid Locker Compounder** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xa89e83e39c8a1cb173d7a0c0201cd3956b57db6d` · **CurveYield:** TVL **$27,483**, **3.32% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [WETH-2 yVault Liquid Locker Compounder (yv^2WETH-2) \| Yearn](https://yearn.fi/vaults/1/0xa89e83e39c8a1cb173d7a0c0201cd3956b57db6d) · **TVL $27,500** · **estimated APY 3.32%** · 30-day APY 2.54% · vault type Single Asset | Allocator · performance fee 0% · risk 2/5 · **DAPP TVL + RATE READ**.

**081. Euler EVK — EVK Vault eWETH-43** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x2ff5f1ca35f5100226ac58e1bfe5aac56919443b` · **CurveYield:** TVL **$23,977**, **0.00% APY** ([source](https://v3.euler.finance/v3/evk/vaults?chainId=1))
Dapp: [Euler Finance](https://app.euler.finance/vault/0x2ff5f1ca35f5100226ac58e1bfe5aac56919443b?network=ethereum) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED**.

**082. Morpho Blue — WETH / ccmETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x4f7a6aae31dce0ceb7d6e049bd9e161942365de33ed891a77ed7c98cc8e6cc2b` · **CurveYield:** TVL **$19,380**, **0.00% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| ccmETH 98%](https://app.morpho.org/ethereum/variable/0x4f7a6aae31dce0ceb7d6e049bd9e161942365de33ed891a77ed7c98cc8e6cc2b/weth-ccmeth) · **total market size $19,440** · **6h lend rate 0.00%** · market utilization 0.00% · borrow rate (6h) 0.00% · LLTV 98.00% · liquidity $19,440 · outstanding loans $0.00 · **DAPP TVL + RATE READ**.

**083. Morpho Vault V2 — CCM Atlas Prime** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x690f0bdc73b8d5e16f5b2d96e195e6bf22595f34` · **CurveYield:** TVL **$19,321**, **0.00% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| CCM Atlas Prime](https://app.morpho.org/ethereum/vault/0x690f0bdc73b8d5e16f5b2d96e195e6bf22595f34/ccm-atlas-prime) · **total deposits $19,660** · **net / instant APY 0.00%** · 30-day APY 0.00% · performance fee 0% · **DAPP TVL + RATE READ**.

**084. Yearn V3 — Parity Core ETH** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x76dd96710a73675d9cf9523a046f1587ca9031d4` · **CurveYield:** TVL **$18,890**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Parity Core ETH (tsvParityCoreETH) \| Yearn](https://yearn.fi/vaults/1/0x76dd96710a73675d9cf9523a046f1587ca9031d4) · **TVL $18,900** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 10% · **DAPP TVL + RATE READ**.

**085. Maple Finance — M11 Credit Maple Pool WETH1** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xfff9a1caf78b2e5b0a49355a8637ea78b43fb6c3` · **CurveYield:** TVL **$17,424**, **0.00% APY** ([source](https://api.maple.finance/v2/graphql))
Dapp: [Exact opportunity dapp](https://app.maple.finance/#/v2/lend/pool/0xfff9a1caf78b2e5b0a49355a8637ea78b43fb6c3) · **TVL not readable** · **APY not readable** · market utilization not readable · **LINK ERROR** · linked dapp returned HTTP Error 403: Forbidden.

**086. Yearn V2 — WETH ubiVault** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x2147935d9739da4e691b8ae2e1437492a394ebf5` · **CurveYield:** TVL **$14,767**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [WETH ubiVault (ubiWETH) \| Yearn](https://yearn.fi/vaults/1/0x2147935d9739da4e691b8ae2e1437492a394ebf5) · **TVL $14,800** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Legacy | Legacy · performance fee 0% · **DAPP TVL + RATE READ**.

**087. Morpho Vault V1 — SingularV ETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x739d8a60ed4b14e4cb6dcaeaf79d2ec0ca092237` · **CurveYield:** TVL **$13,388**, **0.00% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| SingularV ETH](https://app.morpho.org/ethereum/vault/0x739d8a60ed4b14e4cb6dcaeaf79d2ec0ca092237/singularv-eth) · **total deposits $13,620** · **net / instant APY 0.00%** · 30-day APY 0.89% · performance fee 10.00% · **DAPP TVL + RATE READ**.

**088. Yearn V3 — Shorewoods ETH** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x330732581d30076137a1159b3ae8780158d902be` · **CurveYield:** TVL **$13,198**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Shorewoods ETH (tsvShorewoodsETH) \| Yearn](https://yearn.fi/vaults/1/0x330732581d30076137a1159b3ae8780158d902be) · **TVL $13,200** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 10% · **DAPP TVL + RATE READ**.

**089. IPOR Fusion — ETH-weETH Liquidity Optimizer** · **Yield-bearing vault — liquidity optimizer** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x7fd6b3b8d71e9ac959f969843991560c98cab6dd` · **CurveYield:** TVL **$10,430**, **1.40% APY** ([source](https://api.ipor.io/v2/fusion/vaults))
Dapp: [Fusion by IPOR \| Onchain Vault Infrastructure](https://app.ipor.io/fusion/ethereum/0x7fd6b3b8d71e9ac959f969843991560c98cab6dd/vault-info) · **TVL not readable** · **APY not readable** · **DAPP METRICS NOT VERIFIED**.

**090. Morpho Blue — WETH / beraSTONE** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0xf78b7d3a62437f78097745a5e3117a50c56a02ec5f072cba8d988a129c6d4fb6` · **CurveYield:** TVL **$6,756.18**, **8.38% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| beraSTONE 91.5%](https://app.morpho.org/ethereum/variable/0xf78b7d3a62437f78097745a5e3117a50c56a02ec5f072cba8d988a129c6d4fb6/weth-berastone) · **total market size $6,777.30** · **6h lend rate 8.38%** · market utilization 88.49% · borrow rate (6h) 9.52% · LLTV 91.50% · liquidity $780.03 · outstanding loans $5,997.27 · **DAPP TVL + RATE READ**.

**091. Yearn V3 — Yearn-Ajna WETH Vault** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x503e0bab6acdae73ea7fb7cf6ae5792014dbe935` · **CurveYield:** TVL **$6,188.12**, **1.84% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Yearn-Ajna WETH Vault (yvAjnaWETH) \| Yearn](https://yearn.fi/vaults/1/0x503e0bab6acdae73ea7fb7cf6ae5792014dbe935) · **TVL $6,182.00** · **estimated APY 1.84%** · 30-day APY 0.00% · vault type Single Asset | Allocator · performance fee 10% · risk 3/5 · **DAPP TVL + RATE READ**.

**092. Morpho Vault V1 — kpk ETH Prime** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xd564f765f9ad3e7d2d6ca782100795a885e8e7c8` · **CurveYield:** TVL **$5,929.37**, **0.01% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| kpk ETH Prime](https://app.morpho.org/ethereum/vault/0xd564f765f9ad3e7d2d6ca782100795a885e8e7c8/kpk-eth-prime) · **total deposits $6,036.43** · **net / instant APY 0.01%** · 30-day APY 0.02% · performance fee 0.00% · **DAPP TVL + RATE READ**.

**093. Yearn V3 — Teller WETH** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x34facc1333bf6bffe44a838ae3cc82085749e18d` · **CurveYield:** TVL **$2,798.87**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Teller WETH (tWETH) \| Yearn](https://yearn.fi/vaults/1/0x34facc1333bf6bffe44a838ae3cc82085749e18d) · **TVL $2,796.00** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Allocator · performance fee 40% · risk 1/5 · **DAPP TVL + RATE READ**.

**094. Morpho Vault V1 — Smokehouse ETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xbeef36a5c1372f8d7d211527fce9f83fe02d8a73` · **CurveYield:** TVL **$2,617.94**, **0.00% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Smokehouse ETH](https://app.morpho.org/ethereum/vault/0xbeef36a5c1372f8d7d211527fce9f83fe02d8a73/smokehouse-eth) · **total deposits $2,665.21** · **net / instant APY 0.00%** · 30-day APY 0.00% · performance fee 10.00% · **DAPP TVL + RATE READ**.

**095. Morpho Vault V2 — RockawayX wETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x64c18dcc4ccb3b8d27877a4aebb4c3126cb39cb9` · **CurveYield:** TVL **$2,455.45**, **6.25% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| RockawayX wETH](https://app.morpho.org/ethereum/vault/0x64c18dcc4ccb3b8d27877a4aebb4c3126cb39cb9/rockawayx-weth) · **total deposits $2,499.78** · **net / instant APY 6.22%** · 30-day APY 10.83% · performance fee 5% · **DAPP TVL + RATE READ**.

**096. Morpho Blue — WETH / hETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x7ad683900a4017394d76a43cd695a2756cfe96387cb0aa3f8cf3ef73135f85b3` · **CurveYield:** TVL **$2,133.36**, **0.00% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| hETH 94.5%](https://app.morpho.org/ethereum/variable/0x7ad683900a4017394d76a43cd695a2756cfe96387cb0aa3f8cf3ef73135f85b3/weth-heth) · **total market size $2,140.00** · **6h lend rate 0.00%** · market utilization 0.00% · borrow rate (6h) 0.00% · LLTV 94.50% · liquidity $2,140.00 · outstanding loans $0.00 · **DAPP TVL + RATE READ**.

**097. Euler EVK — EVK Vault eWETH-30** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xc2c4abae84fbb5b7baab52301a924b1f986c66bd` · **CurveYield:** TVL **$1,951.56**, **0.00% APY** ([source](https://v3.euler.finance/v3/evk/vaults?chainId=1))
Dapp: [Euler Finance](https://app.euler.finance/vault/0xc2c4abae84fbb5b7baab52301a924b1f986c66bd?network=ethereum) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED**.

**098. Morpho Blue — WETH / weETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115` · **CurveYield:** TVL **$1,917.44**, **0.09% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| weETH 86%](https://app.morpho.org/ethereum/variable/0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115/weth-weeth) · **total market size $1,923.42** · **6h lend rate 0.08%** · market utilization 89.54% · borrow rate (6h) 0.09% · LLTV 86.00% · liquidity $201.18 · outstanding loans $1,722.24 · **DAPP TVL + RATE READ**.

**099. Yearn V3 — Sturdy ETH/rswETH Pendle PT silo** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xc8d4a8a7f593e73cd32cd6c5fb11fe20f23f9695` · **CurveYield:** TVL **$1,912.83**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Sturdy ETH/rswETH Pendle PT silo (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0xc8d4a8a7f593e73cd32cd6c5fb11fe20f23f9695) · **TVL $1,911.00** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 5% · **DAPP TVL + RATE READ**.

**100. Yearn V3 — Swell aggregator** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xbd564bfe6f2366336ecd707862eda79b97bce383` · **CurveYield:** TVL **$1,898.36**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Swell aggregator (SWELL-agg) \| Yearn](https://yearn.fi/vaults/1/0xbd564bfe6f2366336ecd707862eda79b97bce383) · **TVL $1,896.00** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Allocator · performance fee 0% · risk 1/5 · **DAPP TVL + RATE READ**.

**101. Morpho Blue — WETH / ETH+** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x5f8a138ba332398a9116910f4d5e5dcd9b207024c5290ce5bc87bc2dbd8e4a86` · **CurveYield:** TVL **$1,705.19**, **10.63% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| ETH+ 94.5%](https://app.morpho.org/ethereum/variable/0x5f8a138ba332398a9116910f4d5e5dcd9b207024c5290ce5bc87bc2dbd8e4a86/weth-eth) · **total market size $1,710.52** · **6h lend rate 10.63%** · market utilization 88.34% · borrow rate (6h) 12.11% · LLTV 94.50% · liquidity $199.40 · outstanding loans $1,511.12 · **DAPP TVL + RATE READ**.

**102. Yearn V3 — Morpho Gauntlet LRT Core Compounder** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x70e75d8053e3fb0dda35e80eb16f208c7e4d54f4` · **CurveYield:** TVL **$1,061.54**, **1.79% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Morpho Gauntlet LRT Core Compounder (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x70e75d8053e3fb0dda35e80eb16f208c7e4d54f4) · **TVL $1,060.00** · **estimated APY 1.79%** · 30-day APY 1.81% · vault type Single Asset | Strategy · performance fee 0% · risk 3/5 · **DAPP TVL + RATE READ**.

**103. Morpho Blue — WETH / ezETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0xa0534c78620867b7c8706e3b6df9e69a2bc67c783281b7a77e034ed75cee012e` · **CurveYield:** TVL **$1,060.19**, **0.44% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| ezETH 94.5%](https://app.morpho.org/ethereum/variable/0xa0534c78620867b7c8706e3b6df9e69a2bc67c783281b7a77e034ed75cee012e/weth-ezeth) · **total market size $1,063.49** · **6h lend rate 0.44%** · market utilization 68.61% · borrow rate (6h) 0.64% · LLTV 94.50% · liquidity $333.77 · outstanding loans $729.71 · **DAPP TVL + RATE READ**.

**104. Yearn V3 — August Digital ETH** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xfc36c2edb18829308fa9ee9500e8be6520a47caf` · **CurveYield:** TVL **$1,023.00**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [August Digital ETH (tsvAugustDigitalETH) \| Yearn](https://yearn.fi/vaults/1/0xfc36c2edb18829308fa9ee9500e8be6520a47caf) · **TVL $1,022.00** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 10% · **DAPP TVL + RATE READ**.

**105. Morpho Blue — WETH / rETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x251b7cbc2c33ba4eabe3b7163ad0fdd3cfb97de80d8377f0f48b8d31aee7606f` · **CurveYield:** TVL **$1,022.59**, **0.01% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| rETH 94.5%](https://app.morpho.org/ethereum/variable/0x251b7cbc2c33ba4eabe3b7163ad0fdd3cfb97de80d8377f0f48b8d31aee7606f/weth-reth) · **total market size $1,025.77** · **6h lend rate not readable** · market utilization 2.03% · borrow rate (6h) 0.30% · LLTV 94.50% · liquidity $1,004.86 · outstanding loans $20.91 · **DAPP TVL ONLY**.

**106. Euler EVK — EVK Vault eWETH-3** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x67e4e4e73947257ca62d118e0fbc56d06f11d96f` · **CurveYield:** TVL **$633.69**, **0.00% APY** ([source](https://v3.euler.finance/v3/evk/vaults?chainId=1))
Dapp: [Euler Finance](https://app.euler.finance/vault/0x67e4e4e73947257ca62d118e0fbc56d06f11d96f?network=ethereum) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED**.

**107. Morpho Vault V1 — WETH ARM Vault** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x3dfe70b05657949a5db340754ad664810ac63b21` · **CurveYield:** TVL **$613.03**, **1.77% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| WETH ARM Vault](https://app.morpho.org/ethereum/vault/0x3dfe70b05657949a5db340754ad664810ac63b21/weth-arm-vault) · **total deposits $624.09** · **net / instant APY 1.73%** · 30-day APY 2.06% · performance fee 5.00% · **DAPP TVL + RATE READ**.

**108. Yearn V3 — UltraYield ETH** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x59d675f75f973835b94d02b6d27b8539757dc65f` · **CurveYield:** TVL **$504.44**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [UltraYield ETH (tsvUltraYieldETH) \| Yearn](https://yearn.fi/vaults/1/0x59d675f75f973835b94d02b6d27b8539757dc65f) · **TVL $504.00** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 10% · **DAPP TVL + RATE READ**.

**109. Euler EVK — EVK Vault eWETH-20** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x716bf454066a84f39a2f78b5707e79a9d64f1225` · **CurveYield:** TVL **$503.43**, **0.00% APY** ([source](https://v3.euler.finance/v3/evk/vaults?chainId=1))
Dapp: [Euler Finance](https://app.euler.finance/vault/0x716bf454066a84f39a2f78b5707e79a9d64f1225?network=ethereum) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED**.

**110. Yearn V3 — Sturdy ETH/Sommelier Real Yield ETH silo** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x4e72fcb2517ed90a3976dd8f50a387811ac4d883` · **CurveYield:** TVL **$405.29**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Sturdy ETH/Sommelier Real Yield ETH silo (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x4e72fcb2517ed90a3976dd8f50a387811ac4d883) · **TVL $405.00** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 5% · **DAPP TVL + RATE READ**.

**111. Morpho Vault V2 — Morpho vault** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xef3ac91ec3a45f3c6913bfb0c41659919eb85062` · **CurveYield:** TVL **$353.26**, **0.00% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Exact opportunity dapp](https://app.morpho.org/ethereum/vault/0xef3ac91ec3a45f3c6913bfb0c41659919eb85062/morpho-vault) · **total deposits not readable** · **net / instant APY not readable** · **LINK ERROR** · linked dapp returned HTTP Error 404: Not Found.

**112. Yearn V3 — Aave V3 WETH Lender** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x90759801579208b28d2d36d13b1ed7443d1b717f` · **CurveYield:** TVL **$325.50**, **1.45% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Aave V3 WETH Lender (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x90759801579208b28d2d36d13b1ed7443d1b717f) · **TVL $325.00** · **estimated APY 1.45%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 0% · risk 1/5 · **DAPP TVL + RATE READ**.

**113. Euler EVK — EVK Vault eWETH-29** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x87c414825ab3d1e9bdc773e9b1fd968822c9cf51` · **CurveYield:** TVL **$289.49**, **0.00% APY** ([source](https://v3.euler.finance/v3/evk/vaults?chainId=1))
Dapp: [Euler Finance](https://app.euler.finance/vault/0x87c414825ab3d1e9bdc773e9b1fd968822c9cf51?network=ethereum) · **TVL not readable** · **APY not readable** · market utilization not readable · **DAPP METRICS NOT VERIFIED**.

**114. Yearn V3 — Spark WETH Lender** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x365cc9c28df1663fa37c565a3ac1addc3a219e15` · **CurveYield:** TVL **$282.44**, **1.75% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Spark WETH Lender (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x365cc9c28df1663fa37c565a3ac1addc3a219e15) · **TVL $282.00** · **estimated APY 1.75%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 0% · **DAPP TVL + RATE READ**.

**115. Yearn V3 — Aave V3 WETH Lender** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x5abcbbdbf617a21f7667e8cfd17fa16475d20db8` · **CurveYield:** TVL **$266.70**, **1.45% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Aave V3 WETH Lender (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x5abcbbdbf617a21f7667e8cfd17fa16475d20db8) · **TVL $266.00** · **estimated APY 1.45%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 0% · **DAPP TVL + RATE READ**.

**116. Morpho Blue — WETH / savETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x66c19b7c49ce674e964eb917d117d987b693f508f2c1e3f71ac914454ed42e13` · **CurveYield:** TVL **$228.67**, **not readable APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| savETH 94.5%](https://app.morpho.org/ethereum/variable/0x66c19b7c49ce674e964eb917d117d987b693f508f2c1e3f71ac914454ed42e13/weth-saveth) · **total market size $229.48** · **6h lend rate >1,000%** · market utilization 100.00% · LLTV 94.50% · liquidity $0.00 · outstanding loans $229.48 · **DAPP TVL + RATE READ** · extreme >1,000% current rate / minimal liquidity.

**117. Morpho Vault V1 — Turtle ETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x0bb2751a90fff62e844b1521637ded28f3f5046a` · **CurveYield:** TVL **$207.48**, **1.68% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Turtle ETH](https://app.morpho.org/ethereum/vault/0x0bb2751a90fff62e844b1521637ded28f3f5046a/turtle-eth) · **total deposits $211.23** · **net / instant APY 1.64%** · 30-day APY 1.96% · performance fee 10.00% · **DAPP TVL + RATE READ**.

**118. Yearn V3 — Euler Prime WETH Compounder** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xaf48f006e75af050c4136f5a32b69e3fe1c4140f` · **CurveYield:** TVL **$206.99**, **1.48% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Euler Prime WETH Compounder (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0xaf48f006e75af050c4136f5a32b69e3fe1c4140f) · **TVL $207.00** · **estimated APY 1.48%** · 30-day APY 1.55% · vault type Single Asset | Strategy · performance fee 0% · risk 2/5 · **DAPP TVL + RATE READ**.

**119. Beefy Vaults — WETH (Steakhouse, Prime V2)** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xc7ea3c3e2ad0553b960f10ae25da3ce34e15256a` · **CurveYield:** TVL **$206.75**, **1.57% APY** ([source](https://api.beefy.finance/vaults))
Dapp: [Beefy](https://app.beefy.com/vault/morpho-eth-steakhouse-prime-weth) · **TVL not readable** · **APY not readable** · **DAPP METRICS NOT VERIFIED**.

**120. Morpho Blue — WETH / ezETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x49bb2d114be9041a787432952927f6f144f05ad3e83196a7d062f374ee11d0ee` · **CurveYield:** TVL **$186.15**, **0.08% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| ezETH 86%](https://app.morpho.org/ethereum/variable/0x49bb2d114be9041a787432952927f6f144f05ad3e83196a7d062f374ee11d0ee/weth-ezeth) · **total market size $186.72** · **6h lend rate 0.08%** · market utilization 85.73% · borrow rate (6h) 0.09% · LLTV 86.00% · liquidity $26.63 · outstanding loans $160.09 · **DAPP TVL + RATE READ**.

**121. Morpho Vault V1 — Notional WETH** · **Lending-optimizing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xc5c44cb3ff1450b5325f212e02ffdfe5c92cf2cf` · **CurveYield:** TVL **$175.89**, **0.00% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Vaults \| Notional WETH](https://app.morpho.org/ethereum/vault/0xc5c44cb3ff1450b5325f212e02ffdfe5c92cf2cf/notional-weth) · **total deposits $179.06** · **net / instant APY not readable** · performance fee 0.00% · **DAPP TVL ONLY**.

**122. Yearn V2 — WETH yVault** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xac333895ce1a73875cf7b4ecdc5a743c12f3d82b` · **CurveYield:** TVL **$167.18**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [WETH yVault (yvWETH) \| Yearn](https://yearn.fi/vaults/1/0xac333895ce1a73875cf7b4ecdc5a743c12f3d82b) · **TVL $167.00** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Legacy | Legacy · performance fee 0% · **DAPP TVL + RATE READ**.

**123. Yearn V3 — Compound V3 WETH Lender** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x23ee3d14f09946a084350cc6a7153fc6eb918817` · **CurveYield:** TVL **$162.30**, **1.48% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Compound V3 WETH Lender (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0x23ee3d14f09946a084350cc6a7153fc6eb918817) · **TVL $162.00** · **estimated APY 1.48%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 0% · risk 2/5 · **DAPP TVL + RATE READ**.

**124. Yearn V3 — Across WETH Lender** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0xd1f7723881afdec574e7c76edcf5b0458082a8b2` · **CurveYield:** TVL **$160.31**, **2.63% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Across WETH Lender (ysWETH) \| Yearn](https://yearn.fi/vaults/1/0xd1f7723881afdec574e7c76edcf5b0458082a8b2) · **TVL $160.00** · **estimated APY 2.63%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 0% · **DAPP TVL + RATE READ**.

**125. Yearn V3 — MEV Capital ETH** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x32a338b07de8a9529ea640ba8a5806334d4b0931` · **CurveYield:** TVL **$152.35**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [MEV Capital ETH (tsvMEVCapitalETH) \| Yearn](https://yearn.fi/vaults/1/0x32a338b07de8a9529ea640ba8a5806334d4b0931) · **TVL $152.00** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Strategy · performance fee 10% · **DAPP TVL + RATE READ**.

**126. Yearn V3 — Yearn-Ajna Pool wstETH/WETH Vault** · **Yield-bearing vault** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · contract `0x91603c7fb539f2da2da93ba6bec696a47e46bba2` · **CurveYield:** TVL **$110.91**, **0.00% APY** ([source](https://kong.yearn.fi/api/rest/list/vaults/1))
Dapp: [Yearn-Ajna Pool wstETH/WETH Vault (yv-ajna-wsteth-weth) \| Yearn](https://yearn.fi/vaults/1/0x91603c7fb539f2da2da93ba6bec696a47e46bba2) · **TVL $111.00** · **estimated APY 0.00%** · 30-day APY 0.00% · vault type Single Asset | Allocator · performance fee 0% · risk 1/5 · **DAPP TVL + RATE READ**.

**127. Morpho Blue — WETH / pufETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x0eed5a89c7d397d02fd0b9b8e42811ca67e50ed5aeaa4f22e506516c716cfbbf` · **CurveYield:** TVL **$110.17**, **0.01% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| pufETH 86%](https://app.morpho.org/ethereum/variable/0x0eed5a89c7d397d02fd0b9b8e42811ca67e50ed5aeaa4f22e506516c716cfbbf/weth-pufeth) · **total market size $110.51** · **6h lend rate not readable** · market utilization 6.48% · borrow rate (6h) 0.11% · LLTV 86.00% · liquidity $103.35 · outstanding loans $7.16 · **DAPP TVL ONLY**.

**128. Morpho Blue — WETH / ETH0** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0x8aa8614fca17b7efd787e3677bab78fce4a4928866375e86275001515b1f8114` · **CurveYield:** TVL **$107.94**, **0.00% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| ETH0 94.5%](https://app.morpho.org/ethereum/variable/0x8aa8614fca17b7efd787e3677bab78fce4a4928866375e86275001515b1f8114/weth-eth0) · **total market size $108.27** · **6h lend rate not readable** · market utilization 0.04% · borrow rate (6h) 3.07% · LLTV 94.50% · liquidity $108.23 · outstanding loans $0.04 · **DAPP TVL ONLY**.

**129. Morpho Blue — WETH / rswETH** · **Lending market** · WETH `0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2` · market ID `0xcacd4c39af872ddecd48b650557ff5bcc7d3338194c0f5b2038e0d4dec5dc022` · **CurveYield:** TVL **$100.31**, **0.15% APY** ([source](https://api.morpho.org/graphql))
Dapp: [Morpho Markets \| WETH \| rswETH 94.5%](https://app.morpho.org/ethereum/variable/0xcacd4c39af872ddecd48b650557ff5bcc7d3338194c0f5b2038e0d4dec5dc022/weth-rsweth) · **total market size $100.62** · **6h lend rate 0.14%** · market utilization 73.34% · borrow rate (6h) 0.20% · LLTV 94.50% · liquidity $26.81 · outstanding loans $73.80 · **DAPP TVL + RATE READ**.
