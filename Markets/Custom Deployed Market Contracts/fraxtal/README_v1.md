# CurveYield Fraxtal Custom Deployed Market Contracts — v1

**Fraxtal mainnet (chain 252)** — deployer [`0x064256591313eeb86a84a5cbcc4c6460791b96dd`](https://fraxscan.com/address/0x064256591313eeb86a84a5cbcc4c6460791b96dd). Indexed successful deployments from November 16–17, 2026; recovered November 18, 2026.

## Verified on-chain contract addresses

| Role | Verified contract | Explorer address | Deployed UTC | Nonce |
|---|---|---|---|---|
| Vault factory controller | `CurveYieldProtectedVaultController` | [`0x33d0fc6db3f50a4f0133817a59cedea639d0c942`](https://fraxscan.com/address/0x33d0fc6db3f50a4f0133817a59cedea639d0c942#code) | 2026-11-17T02:33:43.000Z | 90 |
| Market fee splitter | `CurveYieldMorphoFeeSplitterV3` | [`0x5f19be0378fb06ebacdf6eb2fdc2af15db38d198`](https://fraxscan.com/address/0x5f19be0378fb06ebacdf6eb2fdc2af15db38d198#code) | 2026-11-17T00:27:53.000Z | 82 |
| Market governance controller | `CurveYieldMorphoOwnerV3` | [`0xc715fc8944d565e27cc5598d8aeabb42e4ce71a0`](https://fraxscan.com/address/0xc715fc8944d565e27cc5598d8aeabb42e4ce71a0#code) | 2026-11-17T00:26:45.000Z | 81 |
| Lending adapter factory | `CurveYieldLendingMarketAdapterFactoryV1` | [`0x3d36d5a098881e34d391b01032126c1ee802b31c`](https://fraxscan.com/address/0x3d36d5a098881e34d391b01032126c1ee802b31c#code) | 2026-11-16T23:19:47.000Z | 59 |
| Omni IRM factory | `CurveYieldOmniIRMFactoryV2` | [`0x1ccd1b85b720f59efe1a485a0f1249c122bd1e77`](https://fraxscan.com/address/0x1ccd1b85b720f59efe1a485a0f1249c122bd1e77#code) | 2026-11-17T01:16:31.000Z | 89 |

## Files

- `sources/` — seven distinct, full Solidity source files from the verified builds, with original source paths, shared files included once.
- `build-inputs/` — three untruncated verified Standard JSON source inputs (controller, adapter, shared owner/splitter) and one separately named Omni factory **reconstruction**.
- `abi/` — five explorer-reported contract ABIs.
- `deployment-manifest_v1.json` — transaction hashes, source paths, compiler/version, bytecode hashes, constructor hex and verification evidence.

## Important provenance

The `CurveYieldOmniIRMFactoryV2` explorer verification declares 130,918 source bytes but the inspection API returns only 100,000 characters. Its three first Solidity source files were completely recovered. The fourth, `CurveYieldMorphoIRMFactoriesV6.sol`, exactly matches the first **9,461 JSON-escaped characters** of the same source fully available in the independently verified Owner V3/Splitter V3 build. That fully verified file completes the source set. The reconstructed Omni input contains all recovered source files and publicly reported optimizer/EVM settings, but its original complete Standard JSON settings were not available; it is **not guaranteed an exact original compilation input**.

The lending adapter entry is the deployed **adapter factory**, not a separately proven live OmniAdapter instance. The Omni IRM entry is an **interest-rate-model factory**, **not** an Omni LTV factory. Production Markets Worker wiring has not been verified. These archive snapshots do not authorize replacing production versions.

No compilation, tests, deployments, or other blockchain writes were performed.
