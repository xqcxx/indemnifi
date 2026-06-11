# Indemnifi Demo Video Guide

Target length: **3:00-4:00**. Stay under 5 minutes. Use your real voice only.

## Links To Submit

- Live app: https://indemnifi-frontend.vercel.app
- Public GitHub repo: https://github.com/xqcxx/indemnifi/tree/main
- Contract docs: `contracts/README.md`
- Main hook: `contracts/src/hook/IndemnifiHook.sol`
- Reactive monitor: `contracts/src/reactive/ReactiveRiskMonitor.sol`

## Pre-Recording Checklist

- Wallet connected on Unichain Sepolia.
- Wallet has Unichain Sepolia ETH for gas.
- WETH claimed from the faucet before recording.
- Open tabs: `/`, `/app`, `/demo`, GitHub repo, and one successful `createPolicy` block explorer transaction if available.
- Hard refresh the app before recording.
- Run one `/demo` scenario before recording if you want the result panel warmed up.

## 4-Minute Script

### 0:00-0:25 — Problem

"If you provide liquidity on a DEX, you can lose money even when the market moves in the direction you expected. That loss is impermanent loss, and today most LPs either accept it or rely on off-chain, manual protection. Indemnifi brings explicit, on-chain insurance for Uniswap v4 LPs."

### 0:25-0:55 — What The Hook Does

"The core is a Uniswap v4 hook. When an LP buys coverage, the hook records the pool, protected token, notional size, deductible, payout cap, entry price, and expiry. Premiums are priced from current pool risk and paid into an insurance vault. Later, when liquidity exits, the hook can settle the claim directly from vault reserves."

Show: `contracts/src/hook/IndemnifiHook.sol` for 5-10 seconds, then move back to the app.

### 0:55-1:45 — Buy A Policy Live

On `/app`:

"Here I’m protecting a 1 ETH liquidity position on Unichain Sepolia. I choose my deductible and the app shows the premium based on the current risk tier. I click Create Policy, approve the premium token if needed, then confirm the policy transaction."

Show the created policy in the policy list.

"The important part is that this is not an off-chain form. The policy is on-chain, priced by the hook, backed by the vault, and visible in the dashboard."

If testnet is slow, say:

"Testnet is slow right now, so here is the same successful transaction on the block explorer."

### 1:45-2:35 — Automated Settlement Demo

On `/demo`:

"The demo compares Alice, who is uninsured, with Bob, who bought coverage. In a volatile scenario, Alice eats the full impermanent loss. Bob pays a premium, but when the exit crosses the deductible, Indemnifi settles the claim automatically."

Run the volatile scenario and point to the side-by-side result.

"This is where Reactive Network comes in. The ReactiveRiskMonitor watches hook events, tracks risk, and triggers callback settlement without a manual claims process."

### 2:35-3:15 — Architecture And Integrations

Show GitHub briefly:

"The working integrations are Uniswap v4 hooks and Reactive Network. The hook implementation is here. The Reactive monitor is here. The insurance vault holds premiums and pays valid claims, while a demo ERC-4626-style vault makes idle reserves earn in a transparent testnet setup. The repo includes unit and integration tests for policy pricing, vault accounting, hook lifecycle behavior, and reactive callbacks."

### 3:15-3:45 — Why It Matters

"Compared with existing IL protection, Indemnifi lives at the pool layer, prices coverage live, and removes the manual claims process. For LPs, it turns an unbounded risk into a known premium, deductible, and payout cap. For Uniswap, it makes liquidity provision safer and potentially more attractive."

### 3:45-4:00 — Close

"Indemnifi is live on testnet today with a public repo, a working frontend, a Uniswap v4 hook, tests, and Reactive Network settlement. We’re bringing real insurance primitives to DeFi liquidity."

## 60-Second Backup Script

"Indemnifi is on-chain insurance against impermanent loss for Uniswap v4 LPs. The problem is simple: LPs can lose money to price divergence, and existing protection is usually manual, off-chain, or tied to one venue. With Indemnifi, a Uniswap v4 hook sells coverage at the pool. The LP selects a notional size, deductible, payout cap, and expiry, and the hook prices a premium from current pool risk. Premiums go into an insurance vault. When the LP exits and the loss crosses the deductible, the claim is settled from the vault. The Reactive Network integration watches hook events and triggers automatic settlement, so there is no manual claims process. Here in the app, I create a policy for a 1 ETH position, confirm it on Unichain Sepolia, then run the demo showing Alice uninsured versus Bob insured. Alice absorbs the loss; Bob receives coverage. The repo is public, includes the hook, vault, Reactive monitor, frontend, and tests. Indemnifi makes LP risk explicit, priced, and insurable directly inside Uniswap v4."

## Submission Notes

- Select **Uniswap Hook Incubator (UHI)** as submission type.
- Select only integrations actually built: **Uniswap v4 Hooks** and **Reactive Network**.
- Do not select Aave, Morpho, or other yield partners unless real integration code is added before submission.
- Keep the final uploaded video accessible to judges without login restrictions.
