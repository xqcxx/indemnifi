# Indemnifi — Frontend

Next.js app for Indemnifi. All data is live from the deployed contracts via
wagmi; events stream in real time.

Stack: Next.js 16 (App Router), Tailwind v4, wagmi v2, RainbowKit, viem,
react-query, recharts, sonner.

## Quick start

```bash
npm install
cp .env.local.example .env.local   # fill in deployed addresses
npm run dev                         # http://localhost:3000
```

`make deploy-testnet` (in contracts) prints the values for `.env.local`.

## Environment

```
NEXT_PUBLIC_CHAIN_ID=1301
NEXT_PUBLIC_HOOK_ADDRESS=
NEXT_PUBLIC_VAULT_ADDRESS=
NEXT_PUBLIC_YIELD_VAULT_ADDRESS=
NEXT_PUBLIC_SCENARIO_RUNNER_ADDRESS=
NEXT_PUBLIC_WETH_ADDRESS=
NEXT_PUBLIC_USDC_ADDRESS=
NEXT_PUBLIC_POOL_FEE=3000
NEXT_PUBLIC_POOL_TICK_SPACING=60
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=
```

Pool params must match what the deploy used.

## Scripts

```bash
npm run dev      # dev server
npm run build    # production build
npm run lint     # eslint
```

## Structure

```
src/
  app/            routes: / (dashboard), /app (protect), /demo, /vault
  components/     UI primitives (ui/) + feature components
  hooks/          wagmi read/write/event hooks
  lib/            contracts config, formatting, chains
  abis/           contract ABIs (from `make sync-abis`)
  providers.tsx   wagmi + RainbowKit + react-query
```

## Pages

- **Dashboard** — live vault stats and health.
- **Protect** — faucet, risk meter, create policy, your policies.
- **Demo** — runs the on-chain Alice-vs-Bob scenario with a settlement timeline.
- **Vault** — vault health, live event feed, Reactive status.

## Theme

Unichain-inspired: DM Sans (bold), magenta `#fb27ce` on near-black. Tokens in
`src/app/globals.css`. See `docs/frontend-design.md`.
