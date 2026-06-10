# Using Indemnifi

A walkthrough for trying the live app on Unichain Sepolia.

## 1. Set up your wallet

- Add **Unichain Sepolia** (chain ID `1301`, RPC `https://sepolia.unichain.org`).
- Get a little Sepolia ETH for gas from a Unichain Sepolia faucet.
- Open the app and click **Connect Wallet**. If you're on the wrong network the
  nav shows a one-click switch.

## 2. Claim test tokens

On the **Protect** page, use the **Test faucet** card to claim **WETH** and
**USDC**. Premiums are paid in WETH. The faucet has an 8-hour cooldown per token.

## 3. Buy a policy

On **Protect**:

1. Check the **Risk meter** — it shows the pool's current tier (CALM / VOLATILE /
   SHOCK) and the premium rate.
2. In **Protect a position**, set:
   - **Notional** — the position value you want covered (WETH).
   - **Deductible** — IL below this is uninsured; lower = more coverage.
   - **Max payout** — the cap on a claim.
3. The **Premium due** updates live (quoted on-chain).
4. Click **Create policy**. Approve the WETH spend if prompted, then confirm the
   policy transaction.

Your new policy appears under **Your policies** with its status.

## 4. Watch the vault

The **Vault** page shows live totals — assets, premiums in, claims paid, yield —
plus a solvency bar and a **Live activity** feed that streams on-chain events
(policies created, claims paid, risk-tier changes).

## 5. Run the demo

The **Demo** page runs the on-chain Alice-vs-Bob comparison. Pick **Calm**,
**Volatile**, or **Shock**; it runs `DemoScenarioRunner` on-chain, animates the
settlement timeline, and shows the result: IL incurred, Bob's payout, premium,
and his advantage over uninsured Alice.

## How claims settle

When an insured LP removes liquidity (passing their policy ID), the hook emits
`PolicyExitRequested`. The Reactive monitor settles the claim by computing IL
against the entry price and paying out from the vault, capped by the deductible,
max payout, and available reserves.

## Notes

- Everything is **testnet** — tokens have no value.
- Values display in WETH (the premium token).
- If a transaction reverts, the toast shows why (e.g. coverage paused, faucet
  cooldown).
