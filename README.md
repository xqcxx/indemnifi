# Indemnifi

**Impermanent-loss insurance for Uniswap v4 liquidity providers.**

LPs buy an explicit, priced policy: if their impermanent loss crosses a chosen
deductible, a yield-bearing vault pays out — and Reactive Network automates the
risk monitoring and claim settlement across chains.

🎬 **Demo video:** pending  ·  🌐 **Live app:** https://indemnifi-frontend.vercel.app

## Hookathon submission

- **Submission type:** Uniswap Hook Incubator (UHI)
- **Public repo:** https://github.com/xqcxx/indemnifi/tree/main
- **Live app:** https://indemnifi-frontend.vercel.app
- **Demo video:** pending

## Partner integrations

Indemnifi integrates the following partner technologies in working code:

| Partner / tech | Where |
|---|---|
| Uniswap v4 Hooks | [`contracts/src/hook/IndemnifiHook.sol`](contracts/src/hook/IndemnifiHook.sol), [`contracts/src/hook/BaseHook.sol`](contracts/src/hook/BaseHook.sol), lifecycle tests in [`contracts/test/integration/HookLifecycle.t.sol`](contracts/test/integration/HookLifecycle.t.sol) |
| Reactive Network | [`contracts/src/reactive/ReactiveRiskMonitor.sol`](contracts/src/reactive/ReactiveRiskMonitor.sol), callback wiring in [`contracts/script/SetCallbackProxy.s.sol`](contracts/script/SetCallbackProxy.s.sol), frontend status/demo flows in [`frontend/src/components/ReactiveStatus.tsx`](frontend/src/components/ReactiveStatus.tsx) and [`frontend/src/components/ScenarioRunner.tsx`](frontend/src/components/ScenarioRunner.tsx) |

The yield vault in this repo is a local ERC-4626-style demo vault used for transparent testnet accounting; it is not submitted as an external partner integration.

## Deployed contracts

**Unichain Sepolia** (chain 1301):

| Contract | Address |
|---|---|
| IndemnifiHook | [`0x08e98ecc2d72b3BC4Ae8398EB028b140A66e0140`](https://unichain-sepolia.blockscout.com/address/0x08e98ecc2d72b3BC4Ae8398EB028b140A66e0140) |
| InsuranceVault | [`0xE5f8ED24308511f9A8c4DB978b2639De75e1cF89`](https://unichain-sepolia.blockscout.com/address/0xE5f8ED24308511f9A8c4DB978b2639De75e1cF89) |
| MockYieldVault | [`0x062fE2C7b10506395734CdC5BdeF22B7F982AAf7`](https://unichain-sepolia.blockscout.com/address/0x062fE2C7b10506395734CdC5BdeF22B7F982AAf7) |
| DemoScenarioRunner | [`0xb3a90b7574769135b77eceA04C28811b5fa494Cf`](https://unichain-sepolia.blockscout.com/address/0xb3a90b7574769135b77eceA04C28811b5fa494Cf) |
| WETH (faucet) | [`0x7C2145c21f5482CEa54c543149586997ACfdB617`](https://unichain-sepolia.blockscout.com/address/0x7C2145c21f5482CEa54c543149586997ACfdB617) |
| USDC (faucet) | [`0x96D455D0383a06887E79cA2Ba0ced62121019651`](https://unichain-sepolia.blockscout.com/address/0x96D455D0383a06887E79cA2Ba0ced62121019651) |

**Reactive Lasna** (chain 5318007): `ReactiveRiskMonitor` —
[`0x96D455D0383a06887E79cA2Ba0ced62121019651`](https://lasna.reactscan.net/address/0x879a4d0f168d7b486021ec7f64e24fd830a876bc/contract/0x96d455d0383a06887e79ca2ba0ced62121019651?screen=transactions)

## How it works

1. **Buy coverage** — add liquidity and attach a policy; pay a premium priced by
   pool risk.
2. **Premiums earn yield** — they pool into the insurance vault; idle capital is
   routed to an ERC-4626 yield source.
3. **Reactive settles** — an RSC on Reactive Lasna watches swaps and exits,
   reprices premiums on volatility, and pays valid claims automatically.

## Repo

| Path | What |
|---|---|
| [`contracts/`](contracts/) | Foundry contracts, tests, deploy scripts |
| [`frontend/`](frontend/) | Next.js app (wagmi, live data) |
| [`docs/`](docs/) | Product, contract, and frontend design docs |

## Run it

```bash
# Contracts
cd contracts && forge test

# Frontend (after filling frontend/.env.local)
cd frontend && npm install && npm run dev
```

See [`docs/USAGE.md`](docs/USAGE.md) to use the app, and the
[`contracts/`](contracts/README.md) / [`frontend/`](frontend/README.md) READMEs
for details.

## Status

Fully live on testnet. Verified end-to-end on real chains: an LP exit on
Unichain Sepolia emits an event, the Reactive contract on Lasna reacts, and it
fires a `settleClaim` callback that is delivered back to the hook on Unichain.
Policies, premiums, the yield-bearing vault, the faucet, and the on-chain demo
all work.

Testnet only — not audited, not for production funds.
