# Indemnifi

## One-Line Pitch

Indemnifi is a Uniswap v4 hook system where LPs buy explicit impermanent-loss protection, premiums are pooled into a yield-earning insurance vault, and Reactive Network automates risk monitoring, vault health updates, and claim execution.

## Core Idea

Impermanent loss is usually treated as something LPs must accept, reduce indirectly through fees, or manage manually. This project turns IL protection into a visible insurance product.

When an LP adds liquidity, they can opt into a protection policy:

- choose a coverage threshold, for example "cover IL above 5%"
- pay a premium into a shared insurance vault
- receive a policy ID linked to their LP position
- withdraw normally later
- receive an automated payout if realized IL exceeds the selected threshold

The insurance vault is not passive. Premiums are routed into conservative yield sources such as Aave or Morpho, so the protection pool earns sustainable income while waiting for claims. Swap fees can also contribute a small percentage into the vault, turning pool activity into additional insurance capacity.

The product is not claiming to eliminate IL. It prices IL, pools it, earns yield on the float, and pays LPs when the risk actually materializes.

## Why This Can Win

This idea is strong because it is direct, theme-aligned, and easy to demonstrate.

Most IL protection hooks try to hide the problem inside dynamic fees, rebalancing, or hedging logic. Those can be powerful, but they are harder for judges to understand quickly. Insurance is immediately legible:

> LPs pay a premium. A vault earns yield. If IL crosses the policy threshold, the vault pays.

That gives the demo a clean before-and-after story:

- uninsured LP loses value when price diverges
- insured LP faces the same market move
- the hook calculates realized IL
- Reactive Network triggers the claim workflow
- the insured LP receives a visible payout

The idea also sits in a major UHI9 white space. Past projects have explored dynamic fees, idle liquidity, lending integrations, perps, and rebalancing. Very few, if any, have built a true pooled mutual insurance layer for Uniswap LPs where the protection mechanism is structurally separate from the pool mechanics.

## How It Fits The UHI9 Theme

UHI9 is about impermanent loss and sustainable onchain yield. Indemnifi addresses both sides of that theme.

### 1. It Protects LPs From Impermanent Loss

LPs can buy coverage against realized IL instead of hoping swap fees are enough to compensate them.

The policy can be simple:

- entry price is recorded when the LP opens the position
- notional liquidity value is recorded
- LP chooses a threshold, such as 3%, 5%, or 10%
- when the LP exits, the hook compares LP value against a hold strategy
- if IL exceeds the threshold, the vault pays the covered excess

Example:

- LP deposits $10,000 of ETH/USDC liquidity
- LP chooses coverage above 5% IL
- market moves sharply
- realized IL is 9%
- uncovered first-loss portion is 5%
- covered excess is 4%
- insurance vault pays up to $400, subject to vault solvency and policy limits

This gives LPs a way to participate in volatile pairs with bounded downside.

### 2. It Unlocks Sustainable Yield

The insurance vault can earn yield while premiums are idle.

Sources of vault income:

- upfront LP premiums
- small share of swap fees
- Aave or Morpho lending yield on unused reserves
- optional protocol-owned seed capital
- optional reinsurance tranche from junior risk backers

This is stronger than pure token incentives because the yield has a business model:

- LPs pay for protection
- traders pay fees
- vault capital earns external yield
- claims are paid only when defined risk conditions occur

The yield is connected to actual demand for risk protection, not inflationary emissions.

### 3. It Makes Liquidity Stickier

LPs are more likely to keep liquidity in volatile pools if they can quantify their worst-case exposure.

Instead of exiting when volatility rises, LPs can:

- increase coverage
- pay a higher premium
- keep their position active
- let the system manage claims automatically

That helps Uniswap compete for volatile-pair liquidity where LPs currently fear being the counterparty to informed flow.

### 4. It Is Honest About Where Risk Goes

The core message should be:

> IL does not disappear. It is transferred from individual LPs into a priced, yield-backed insurance pool.

That honesty matters. Judges will likely be skeptical of any project claiming to "eliminate IL." This project instead explains exactly who absorbs the risk:

- LP absorbs the deductible
- insurance vault absorbs covered IL
- premium payers fund the vault
- external yield improves vault solvency
- junior backers can optionally absorb tail risk for higher return

## How It Aligns With Reactive Network

Reactive Network is useful because IL insurance is event-driven. The system should not depend on a centralized bot watching every pool and every LP position.

Reactive Contracts can watch onchain events and trigger callback transactions when specific conditions are met. That maps naturally to the insurance lifecycle.

### Reactive Use Case 1: Risk Monitoring

The Reactive Contract watches relevant events:

- Uniswap v4 swap events
- pool price updates
- volatility changes
- liquidity add/remove events
- oracle updates
- insurance vault balance changes

When price divergence grows, the Reactive Contract updates risk state for the policy system.

Visible demo message:

> Reactive Network is the always-on risk monitor for LP insurance.

### Reactive Use Case 2: Premium Adjustment

Premiums should rise when risk rises and fall when markets are calm.

Reactive Network can trigger updates when:

- realized volatility crosses a threshold
- pool price diverges from oracle price
- vault utilization gets too high
- recent claims reduce solvency
- volume increases and improves fee inflow

Example premium states:

- Calm: 1% premium
- Volatile: 3% premium
- Shock: 7% premium or new coverage paused

Visible demo message:

> The hook sells coverage, but Reactive Network reprices risk as market conditions change.

### Reactive Use Case 3: Claim Automation

When an LP removes liquidity, a claim may need to be checked. Reactive Network can watch the position exit and trigger the claim settlement transaction.

Claim workflow:

1. LP removes liquidity.
2. Hook emits `PolicyExitRequested`.
3. Reactive Contract detects the event.
4. Reactive Contract calls `settleClaim(policyId, currentPrice, proofData)`.
5. Insurance hook calculates realized IL.
6. Vault pays if IL exceeds threshold.
7. UI updates claim status from pending to paid.

Visible demo message:

> No manual claim desk. No offchain keeper. The policy settles when the LP exits.

### Reactive Use Case 4: Vault Health Protection

The system should protect the vault from insolvency.

Reactive Network can trigger defensive actions:

- pause new policies when utilization is too high
- increase premiums after claims
- move idle capital between yield source and liquid reserve
- reduce maximum coverage during high-volatility windows
- emit public alerts when solvency ratio falls

Visible demo message:

> Reactive Network keeps the insurance vault solvent by responding before the vault is drained.

## Product Design

### Main Actors

**LP**

Provides liquidity and optionally buys IL protection.

**Insurance Vault**

Receives premiums, earns yield, and pays valid claims.

**Hook**

Creates policies, records entry conditions, collects premiums, and enforces claim rules.

**Reactive Contract**

Monitors events and triggers automated updates, repricing, and settlement.

**Yield Source**

Aave, Morpho, or a mocked ERC4626 vault for demo purposes.

### Policy Parameters

Each policy should be simple enough to explain in one screen:

- `owner`: LP address
- `poolId`: covered pool
- `positionId`: linked LP position
- `notional`: protected value
- `entryPrice`: price at deposit
- `thresholdBps`: deductible before coverage starts
- `maxPayout`: maximum vault payout
- `premiumPaid`: amount paid upfront
- `expiry`: optional coverage end time
- `status`: active, pending claim, paid, expired

### Minimal Smart Contract Components

For the hackathon, keep the architecture focused:

- `ReactiveILInsuranceHook.sol`
- `InsuranceVault.sol`
- `MockYieldVault.sol`
- `ReactiveRiskMonitor.sol`
- `ScenarioRunner.sol`

The hook should be the star. The yield vault can be mocked if live Aave/Morpho integration would distract from the demo.

### Events To Emit

Events are critical because the demo needs to show Reactive Network responding visibly.

Recommended events:

- `PolicyCreated(policyId, owner, notional, thresholdBps, premium)`
- `PremiumUpdated(poolId, oldPremiumBps, newPremiumBps, reason)`
- `RiskStateChanged(poolId, riskState, volatilityBps, solvencyBps)`
- `VaultYieldAccrued(amount, newVaultBalance)`
- `ClaimRequested(policyId, owner, realizedIlBps)`
- `ClaimPaid(policyId, payout, vaultBalanceAfter)`
- `CoveragePaused(poolId, reason)`
- `CoverageResumed(poolId)`

These events make the system understandable even if judges are not reading contract internals.

## Demo Strategy: Make It 100% Direct

The demo should answer every judge question visually:

- What is the problem?
- What does the LP do?
- What does the hook do?
- What does Reactive Network automate?
- Where does the money come from?
- Who gets paid?
- What happens when the vault is stressed?

Do not demo this as a pile of contracts. Demo it as an insurance product.

## How I Would Build It For Perfect Demoability

The build should be optimized around one goal: a judge should understand the full mechanism without reading code, asking for missing context, or trusting a hidden backend.

That means the implementation should be deterministic, visual, and event-driven from the start.

### 1. Build The Demo Around A Single Story

Do not start with a generic dashboard. Start with a controlled story:

> Alice and Bob provide the same liquidity. Alice is uninsured. Bob buys protection. The market moves. Alice absorbs IL. Bob receives an automated payout.

Everything in the product should support that story.

The demo should have one primary button:

> Run Protected LP Scenario

That button should step through the entire lifecycle:

1. create pool
2. Alice adds uninsured liquidity
3. Bob adds insured liquidity
4. Bob pays premium
5. premium enters vault
6. vault earns yield
7. market shock occurs
8. Reactive Network detects risk
9. Bob exits and claim is triggered
10. claim pays from vault
11. final Alice vs Bob comparison appears

The judge should never wonder what they are supposed to look at next.

### 2. Use Deterministic Presets, Not Freeform Inputs

Freeform demos break easily and distract from the pitch. Use three fixed scenarios:

**Calm Market**

- ETH price moves from $2,000 to $2,080
- IL remains below threshold
- no claim is paid
- vault earns yield
- message: insurance is not used when loss is small

**Volatile Market**

- ETH price moves from $2,000 to $2,800
- IL exceeds threshold
- claim is paid
- vault remains healthy
- message: protection works under normal adverse conditions

**Shock Market**

- ETH price moves from $2,000 to $4,000
- large IL occurs
- claim is paid up to policy cap
- vault solvency falls
- Reactive pauses or reprices new coverage
- message: the system is honest about solvency and risk limits

These presets should always produce the same numbers. That lets the team rehearse the exact explanation and avoid live-demo uncertainty.

### 3. Make Every Contract Action Emit A Human-Readable Event

The UI should not infer hidden behavior. It should listen to events and display them in a timeline.

Example timeline:

| Step | Event | Plain-English Display |
| --- | --- | --- |
| 1 | `PolicyCreated` | Bob bought IL protection above 5% |
| 2 | `PremiumDeposited` | $150 premium entered the vault |
| 3 | `VaultYieldAccrued` | Vault earned $12 of reserve yield |
| 4 | `RiskStateChanged` | Reactive detected volatility: Calm -> Shock |
| 5 | `PremiumUpdated` | New policy premium increased from 1.5% to 5% |
| 6 | `ClaimRequested` | Bob exited; policy is checking realized IL |
| 7 | `ClaimPaid` | Bob received $400 from the insurance vault |
| 8 | `VaultHealthUpdated` | Vault solvency is now 82% |

This is what makes the demo feel real. The audience sees the system breathe.

### 4. Keep The Onchain Core Small

The MVP should not try to build a complete production insurance protocol. It should build the smallest truthful version of the mechanism.

Contracts:

- `ReactiveILInsuranceHook`
- `InsuranceVault`
- `MockYieldVault`
- `ReactiveRiskMonitor`
- `DemoScenarioRunner`

The hook should handle:

- policy creation
- premium collection
- entry price recording
- claim request events
- claim settlement

The vault should handle:

- premium accounting
- mock yield accounting
- claim payouts
- solvency ratio
- coverage pause state

The Reactive contract should handle:

- detecting risk-state changes
- calling premium update
- calling claim settlement after exit
- pausing coverage when solvency is low

Anything else is optional.

### 5. Mock Yield, But Make The Accounting Real

Do not spend demo time debugging Aave or Morpho unless integration is already easy. A mocked ERC4626-style yield vault is enough for demo if the accounting is transparent.

The mock should expose:

- `depositPremium(amount)`
- `accrueYield(amount)`
- `withdrawForClaim(amount)`
- `totalAssets()`

In the UI, label it honestly:

> Demo yield vault. Production target: Aave, Morpho, or ERC4626 yield source.

This keeps the message clean:

> The important thing is not which yield venue we use. The important thing is that premiums become productive reserves.

### 6. Use A Real Reactive Callback For One Critical Moment

The demo does not need Reactive Network to automate every possible action. It needs one or two undeniable moments where Reactive is visibly responsible.

Minimum strong Reactive path:

1. pool shock emits `RiskObserved`
2. Reactive contract receives the event
3. Reactive contract calls `updateRiskState(poolId, SHOCK)`
4. hook emits `RiskStateChanged`
5. UI updates premium and risk meter

Best Reactive path:

1. LP exit emits `ClaimRequested`
2. Reactive contract sees it
3. Reactive contract calls `settleClaim(policyId)`
4. vault pays Bob
5. UI marks claim as `Paid by Reactive Callback`

That second path is the most powerful because it proves Reactive is not decorative. It is settling the insurance workflow.

### 7. Make The Math Visible And Simple

Judges should not have to ask how the payout was calculated.

Show the formula in the UI:

```text
Covered IL = max(0, Realized IL - Deductible)
Payout = min(Covered IL, Max Policy Payout, Available Vault Balance)
```

Example:

```text
Realized IL: $900
Deductible: $500
Covered IL: $400
Max Payout: $1,000
Vault Available: $8,500
Final Payout: $400
```

This removes ambiguity and builds trust.

### 8. Build A Split-Screen Outcome View

The most important screen is the final comparison.

Left side:

**Alice: Uninsured**

- Deposit: $10,000
- Premium: $0
- IL: $900
- Payout: $0
- Final loss: $900

Right side:

**Bob: Insured**

- Deposit: $10,000
- Premium: $150
- IL: $900
- Payout: $400
- Final loss after payout and premium: $650
- Improvement vs Alice: $250

The improvement number should be large, bold, and impossible to miss.

### 9. Add A Solvency Stress Moment

A good insurance demo should show what happens when the vault is stressed. This prevents the project from sounding naive.

In the shock scenario, after Bob's payout:

- vault balance decreases
- solvency ratio updates
- Reactive detects solvency below threshold
- new policies are paused or repriced

Display:

> Vault solvency fell below 80%. Reactive Network paused new coverage until reserves recover.

This directly answers the judge question:

> What if everyone claims at once?

Answer:

> Coverage is capped, priced, and automatically controlled by vault health.

### 10. Make The Demo Work Without Internet Dependencies

For reliability, the whole demo should run locally:

- local Foundry tests
- local Anvil chain
- local frontend
- deterministic scenario runner
- mock price movement
- mock yield vault
- mocked oracle input if needed

Then, if Reactive testnet integration is ready, add it as the premium proof path. But the core story should still work locally.

Recommended demo modes:

- `Local Simulation Mode`: always works, shows full story
- `Reactive Live Mode`: shows the real Reactive callback transaction

If live Reactive has issues during demo day, the team can still present the complete product story using local mode and then show the Reactive transaction hash or recorded callback flow.

### 11. Build The Pitch UI Before Adding Extra Features

The frontend should be treated as part of the protocol, not a wrapper added at the end.

Build order:

1. static mock UI with the full story
2. hardcoded scenario numbers
3. connect to local scenario output
4. connect to contract events
5. connect to Reactive callback events
6. add optional wallet interaction

This guarantees that the final product is explainable even if some advanced integrations are incomplete.

### 12. What The Final Demo Should Prove

By the end of the demo, the judges should be able to say:

- I understand the LP problem.
- I understand what insurance policy Bob bought.
- I saw where Bob's premium went.
- I saw the vault earn yield.
- I saw price divergence create IL.
- I saw Reactive Network detect the risk.
- I saw Bob's claim settle automatically.
- I saw the vault pay Bob.
- I saw how vault solvency is protected.

If the demo proves those nine things, it leaves almost no question on the table.

## Recommended Demo Flow

### Scene 1: Start With Two LPs

Show two side-by-side LP cards:

- Alice: uninsured LP
- Bob: insured LP

Both deposit the same amount into the same volatile ETH/USDC pool.

On Bob's card, show:

- coverage threshold: 5%
- premium paid: $150
- max payout: $1,000
- policy status: active

Message to say:

> Alice and Bob take the same LP position. Bob buys IL protection from the hook.

### Scene 2: Show The Insurance Vault

Show a vault panel:

- premium inflow
- swap-fee contribution
- yield earned
- available claims reserve
- solvency ratio

Animate Bob's premium moving into the vault.

Message to say:

> Premiums do not sit idle. They become a yield-earning reserve for future LP claims.

### Scene 3: Trigger A Market Move

Run a scenario where ETH price diverges sharply.

The UI should show:

- pool price before
- pool price after
- LP value vs hold value
- estimated IL
- risk state changing from calm to volatile or shock

Reactive Network should visibly appear here.

Show:

- `SwapEvent detected`
- `Volatility threshold crossed`
- `RiskStateChanged: Shock`
- `PremiumUpdated: 150 bps -> 500 bps`

Message to say:

> Reactive Network watches the pool and updates the insurance layer as risk changes.

### Scene 4: Alice Exits Uninsured

Alice removes liquidity.

Show:

- Alice LP value
- Alice hold value
- Alice realized IL
- Alice payout: $0

Message to say:

> Alice had normal LP exposure, so she absorbs the full impermanent loss.

### Scene 5: Bob Exits Insured

Bob removes liquidity.

Show a visible claim lifecycle:

- `PolicyExitRequested`
- `Reactive callback triggered`
- `ClaimRequested`
- `IL above threshold`
- `ClaimPaid`

Bob's result panel should show:

- LP value
- hold value
- realized IL
- deductible
- covered amount
- final payout
- net result after premium

Message to say:

> Bob faces the same market move, but his policy pays the covered excess IL automatically.

### Scene 6: Show Vault Accounting After Claim

After payout, show:

- vault balance before claim
- claim paid
- vault balance after claim
- solvency ratio
- new premium level

If solvency falls below a threshold, show:

- `CoveragePaused`
- or `PremiumUpdated`
- or `MaxCoverageReduced`

Message to say:

> The vault does not promise infinite protection. It adapts coverage based on available capital.

### Scene 7: End With The Summary

End on one screen with three columns:

**LP Protection**

- Bob got a claim payout
- IL was bounded above the deductible
- LP exposure became more predictable

**Sustainable Yield**

- premiums funded the vault
- swap fees contributed to reserves
- idle reserves earned yield

**Reactive Automation**

- market risk was detected
- premium changed automatically
- claim was settled from events
- vault health was protected

Final line:

> Indemnifi turns Uniswap LPing from unmanaged IL exposure into priced, automated, yield-backed protection.

## UI Requirements For A Strong Demo

Build the UI around the story, not around contract addresses.

Required screens:

- LP comparison screen: insured vs uninsured
- policy creation modal
- insurance vault dashboard
- risk monitor timeline
- claim settlement screen
- final outcome comparison

Required visual elements:

- money flow from LP premium to vault
- yield accrual inside vault
- price divergence chart
- IL calculation display
- Reactive event timeline
- claim payout animation
- vault solvency meter

Avoid hiding the key logic in logs. Logs can be present, but the primary demo should be visual.

## Demo Metrics To Show

Use simple, judge-friendly metrics:

- `Premium Paid`
- `Vault Yield Earned`
- `Realized IL`
- `Deductible`
- `Insurance Payout`
- `Net LP Result`
- `Vault Balance`
- `Solvency Ratio`
- `Premium Before Shock`
- `Premium After Shock`

Best final comparison table:

| Metric | Alice: Uninsured | Bob: Insured |
| --- | ---: | ---: |
| Deposit Value | $10,000 | $10,000 |
| Premium Paid | $0 | $150 |
| Realized IL | $900 | $900 |
| Deductible | N/A | $500 |
| Insurance Payout | $0 | $400 |
| Net IL After Protection | $900 | $500 |
| Final Advantage | Baseline | +$250 after premium |

This table makes the value proposition impossible to miss.

## Suggested MVP Scope

### Must Build

- create protected LP policy
- collect premium into insurance vault
- simulate or calculate IL at exit
- settle claim from vault
- emit events for Reactive Network
- Reactive Contract triggers at least one real callback
- visual demo comparing insured and uninsured LPs

### Should Build

- dynamic premium based on risk state
- vault solvency ratio
- mocked yield accrual
- coverage pause when vault is undercapitalized
- scenario presets: calm, volatile, shock

### Nice To Have

- actual Aave or Morpho integration
- junior risk tranche
- NFT policy receipt
- multiple coverage tiers
- real oracle integration

Do not let nice-to-have features weaken the core demo. The winning demo is the one where judges instantly understand that the LP bought protection and got paid when IL happened.

## Build Plan

### Phase 1: Contracts

Implement the hook and vault with a deterministic local test path.

Core functions:

- `createPolicy(positionId, thresholdBps, maxPayout)`
- `payPremium(policyId)`
- `recordRiskState(poolId, riskState)`
- `requestClaim(policyId)`
- `settleClaim(policyId, exitPrice)`
- `accrueMockYield(amount)`
- `pauseCoverage(poolId)`
- `resumeCoverage(poolId)`

### Phase 2: Reactive Integration

Implement Reactive event subscriptions for:

- policy creation
- swap activity
- price divergence
- LP withdrawal
- vault solvency changes

At minimum, the demo should show Reactive Network triggering:

- risk-state update after volatility spike
- claim settlement after LP withdrawal

### Phase 3: Scenario Engine

Create three deterministic scenarios:

**Calm**

- low volatility
- low premium
- no claim
- vault earns yield

**Volatile**

- medium price divergence
- premium increases
- small claim
- vault remains healthy

**Shock**

- large price divergence
- claim paid
- solvency ratio falls
- coverage pauses or reprices

### Phase 4: Demo UI

The UI should walk through the insurance story in order:

1. create LP positions
2. buy coverage
3. fund vault
4. trigger volatility
5. Reactive detects event
6. LPs exit
7. claim settles
8. compare outcomes

## Judge Questions This Demo Should Pre-Answer

### Where does the payout money come from?

From LP premiums, a share of swap fees, external yield on idle reserves, and optional protocol-seeded capital.

### Is this pretending IL disappears?

No. IL is transferred from individual LPs to a priced insurance vault with explicit solvency limits.

### Why does this need Reactive Network?

Because risk monitoring, premium repricing, claim settlement, and vault health responses are event-driven. Reactive Network removes the need for a centralized keeper and makes the automation visible.

### What happens if the vault cannot pay?

Payouts are capped by vault solvency and policy limits. If utilization becomes unsafe, Reactive Network can pause new coverage, raise premiums, or reduce max coverage.

### Why would LPs use this?

They get more predictable downside on volatile pairs. That can make them willing to provide liquidity for longer.

### Why would Uniswap care?

Stickier LP capital, better volatile-pair liquidity, and a hook-native protection primitive that can be reused across pools.

## Final Positioning

Indemnifi is not just another dynamic fee hook. It is a visible LP protection product.

It combines:

- impermanent-loss protection
- sustainable yield from premiums and reserves
- event-driven automation through Reactive Network
- a demo where the user can see the same market move hurt one LP and protect another

The core thesis:

> Uniswap v4 hooks can turn LP risk into an automated, priced, yield-backed insurance market. Reactive Network is the automation layer that makes the insurance responsive without relying on centralized keepers.
