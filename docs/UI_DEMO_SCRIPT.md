# Indemnifi UI Demo Script

Use this after your PPT section. Target time: **2.5-3.5 minutes**.

## Tabs To Prepare

Open these before recording:

1. Live app `/app`: https://indemnifi-frontend.vercel.app/app
2. Live app `/demo`: https://indemnifi-frontend.vercel.app/demo
3. Live app `/vault`: https://indemnifi-frontend.vercel.app/vault
4. GitHub repo: https://github.com/xqcxx/indemnifi/tree/main
5. Hook contract scanner: https://unichain-sepolia.blockscout.com/address/0x08e98ecc2d72b3BC4Ae8398EB028b140A66e0140
6. DemoScenarioRunner scanner: https://unichain-sepolia.blockscout.com/address/0xb3a90b7574769135b77eceA04C28811b5fa494Cf
7. Reactive contract scanner: https://lasna.reactscan.net/address/0x879a4d0f168d7b486021ec7f64e24fd830a876bc/contract/0x96d455d0383a06887e79ca2ba0ced62121019651?screen=transactions

## Before Recording The UI Section

- Connect wallet.
- Switch to **Unichain Sepolia**.
- Make sure the wallet has test ETH.
- If possible, claim WETH before recording.
- Hard refresh all app tabs.

## UI Demo Script

### 1. Open `/app`

Action: Start on https://indemnifi-frontend.vercel.app/app.

Say:

> Now I’ll show the working frontend. This is the LP-facing protection screen. The user connects a wallet, chooses how much liquidity they want to protect, and buys impermanent-loss coverage directly through the Uniswap v4 hook.

Action: Point to the top-right wallet connection and network badge.

Say:

> I’m connected on Unichain Sepolia, where the hook, vault, faucet tokens, and demo runner are deployed.

### 2. Show Risk And Premium

Action: Point to **Pool risk / Current premium**.

Say:

> At the top, the UI reads the current pool risk from the hook. The hook can price coverage differently depending on whether the pool is calm, volatile, or in shock. This means premiums are not a static form value; they are tied to pool state.

### 3. Claim Test WETH If Needed

Action: In the **Test faucet** panel, click **Claim** beside WETH only if you need tokens.

Say if clicking:

> For the testnet demo, premiums are paid in test WETH. I’ll claim WETH from the faucet so I can buy a policy.

Say if not clicking:

> I already claimed test WETH earlier, so I’ll skip the faucet to avoid the cooldown.

### 4. Fill The Policy Form

Use these exact values:

| Field | Value |
|---|---|
| Notional | `1` |
| Deductible | `5.00%` |
| Max payout | `1` |

Action: Type `1` into **Notional**.

Say:

> I’m going to protect a 1 ETH LP position.

Action: Leave or move the deductible slider to **5.00%**.

Say:

> The deductible is set to 5%. That means the LP absorbs the first 5% of impermanent loss, and the insurance starts paying after that threshold.

Action: Type `1` into **Max payout**.

Say:

> The max payout is capped at 1 WETH. This protects the vault from unlimited exposure and makes the risk explicitly bounded.

Action: Point to **Premium due**.

Say:

> The premium due is the amount the user pays upfront for this coverage. In production, this pricing is driven by risk conditions in the pool.

### 5. Create Policy

Action: Click **Create policy**.

If wallet asks for approval: approve WETH.

Say:

> The first transaction approves the premium token if needed.

If wallet asks for create transaction: confirm.

Say:

> The second transaction calls `createPolicy` on the hook. The hook records the protected position, deductible, payout cap, premium, and owner directly on-chain.

After it confirms, point to policy list.

Say:

> Once the transaction lands, the policy appears in the connected wallet’s policy list. This is the key UX: no insurance form, no off-chain underwriter, and no manual setup. Coverage is attached directly to the DeFi position.

If the transaction is slow or fails, say:

> Testnet transactions can be slow, so I’ll continue with the scenario runner that compresses the full policy lifecycle into one demo flow.

### 6. Show Hook Scanner

Action: Switch to the hook scanner tab.

Hook address: `0x08e98ecc2d72b3BC4Ae8398EB028b140A66e0140`

Say:

> This is the deployed Indemnifi hook on Unichain Sepolia. This is where policies are created and where the hook lifecycle integrates with the pool.

Action: If visible, open events/transactions.

Say:

> For created policies, judges can inspect transactions and events here. The important event is policy creation: it proves the frontend action reached the deployed hook.

### 7. Open `/demo`

Action: Switch to https://indemnifi-frontend.vercel.app/demo.

Say:

> Now I’ll show the full lifecycle in a condensed demo. This compares Alice, an uninsured LP, against Bob, an insured LP.

### 8. Run Volatile Scenario

Action: Click **Volatile**.

Say while it runs:

> The volatile scenario simulates a large price movement. Alice and Bob both provide liquidity. Alice is uninsured. Bob bought coverage. The market moves, impermanent loss appears, and the system checks whether Bob’s loss crosses his deductible.

Action: Point to the settlement timeline.

Say:

> This timeline shows the flow: entry price, uninsured liquidity, insured liquidity, premium entering the vault, market movement, Reactive detection, exit, and claim settlement.

### 9. Explain Result Panel

Action: Scroll or point to the **Result** section.

Say:

> Here is the comparison. Alice incurs the full impermanent loss. Bob also experiences impermanent loss, but because he paid a premium and his loss crosses the deductible, the vault pays a claim.

Action: Point to each metric:

- **IL incurred**
- **Bob payout**
- **Bob premium**
- **Bob advantage**

Say:

> IL incurred shows the raw loss from price divergence. Bob payout shows what the vault pays back. Bob premium is the cost of coverage. Bob advantage is the net improvement from being insured instead of staying exposed.

Action: Point to the chart.

Say:

> The chart makes the result obvious: uninsured LPs absorb the full downside, while insured LPs convert that risk into a known premium and capped payout structure.

### 10. Show Reactive Network Deployment

Action: Switch to the Reactive scanner tab.

Reactive scanner: https://lasna.reactscan.net/address/0x879a4d0f168d7b486021ec7f64e24fd830a876bc/contract/0x96d455d0383a06887e79ca2ba0ced62121019651?screen=transactions

Say:

> This is the Reactive Network deployment on Lasna. The Reactive contract monitors events from the hook, detects risk changes and exit conditions, and triggers callback settlement.

Action: Point to transactions if visible.

Say:

> This is important because Indemnifi does not depend on a manual claims process. The Reactive contract is what turns hook events into automated settlement behavior.

### 11. Open `/vault`

Action: Switch to https://indemnifi-frontend.vercel.app/vault.

Say:

> The last piece is the vault. Premiums pool here, and valid claims are paid from these reserves.

Action: Point to vault stats.

Say:

> The live vault tracks assets, premiums, claims, yield, and solvency. Solvency matters because if reserves are too low, the system can gate new coverage.

Action: Point to **Demo reserve model**.

Say:

> For this demo deployment, the UI also shows the scenario reserve model. It makes the economics easy to inspect: reserves are seeded, Bob pays a premium, claims draw against capacity, and solvency remains visible.

### 12. Optional GitHub Proof

Action: Switch to GitHub repo.

Say:

> The repo is public and contains the hook, vault, Reactive monitor, frontend, tests, and deployment scripts.

Action: Point to these files if you have time:

- `contracts/src/hook/IndemnifiHook.sol`
- `contracts/src/reactive/ReactiveRiskMonitor.sol`
- `contracts/src/vault/InsuranceVault.sol`
- `contracts/test/`

Say:

> The hook sells policies and settles claims. The Reactive monitor automates risk detection and callbacks. The vault backs the policies. The tests cover the core lifecycle.

## Closing Line

Say:

> Indemnifi makes impermanent-loss risk explicit, priced, and insurable directly inside Uniswap v4. LPs get a simple frontend, the hook handles policy creation, the vault backs claims, and Reactive Network removes the manual claims process.

## If Something Looks Off

If `/demo` shows fallback numbers, say:

> The scenario runner is connected to the live deployment, but for presentation safety the UI also shows the deterministic scenario economics if testnet returns an empty result. The point is to make the claim math visible: Alice loses fully, Bob pays a premium and receives a payout.

If `/vault` shows zero live assets, say:

> The live deployment is connected but currently empty. The demo reserve model shows the same vault accounting pattern used by the scenario runner.

If a transaction takes too long, say:

> Testnet is slow, so I’ll move to the already prepared lifecycle demo and scanner links.
