# Indemnifi — Contract Implementation Guide

This document is the authoritative reference for what to build, how to test it, and what the frontend needs to integrate against. Read the product doc (`indemnifi.md`) first for context on the *why*; this doc covers the *how*.

---

## Architecture Overview

```
Uniswap v4 PoolManager
        │
        ▼
IndemnifiHook.sol          ◄──── afterRemoveLiquidity: emits PolicyExitRequested
        │
        ├── creates/settles policies
        ├── collects premiums
        └── records entry state
                │
                ▼
        InsuranceVault.sol
                │
                ├── holds premium reserves
                ├── routes idle capital → MockYieldVault
                ├── pays claims
                └── tracks solvency ratio
                        │
                        ▼
                MockYieldVault.sol  (ERC4626-style)
                        │
                        └── simulates Aave/Morpho yield accrual

ReactiveRiskMonitor.sol    ← deployed on Reactive Lasna (chain 5318007)
        │
        ├── subscribes to: PolicyExitRequested, swap events, oracle events
        ├── calls: updateRiskState(poolId, riskState)
        ├── calls: settleClaim(policyId, exitPrice)
        └── calls: pauseCoverage(poolId)

DemoScenarioRunner.sol     ← local Anvil + testnet helper
        └── one-tx execution of full Alice/Bob lifecycle
```

---

## Chain Deployment Targets

| Contract | Chain | Network |
|---|---|---|
| `IndemnifiHook` | Unichain Sepolia | Chain ID 1301 |
| `InsuranceVault` | Unichain Sepolia | Chain ID 1301 |
| `MockYieldVault` | Unichain Sepolia | Chain ID 1301 |
| `DemoScenarioRunner` | Unichain Sepolia | Chain ID 1301 |
| `ReactiveRiskMonitor` | Reactive Lasna | Chain ID 5318007 |

---

## Contract Specifications

### 1. `IndemnifiHook.sol`

**Location:** `contracts/src/hook/IndemnifiHook.sol`

**Inherits:** `BaseHook` (v4-periphery), `Ownable` (OZ)

**Hook flags required** (must be encoded in deployed address via CREATE2 mining):
- `BEFORE_ADD_LIQUIDITY_FLAG`
- `AFTER_ADD_LIQUIDITY_FLAG`
- `AFTER_REMOVE_LIQUIDITY_FLAG`
- `AFTER_SWAP_FLAG`

**State:**

```solidity
mapping(uint256 policyId => Policy) public policies;
mapping(PoolId => PoolRiskState) public poolRiskState;
mapping(PoolId => uint256) public premiumBps;           // e.g. 150 = 1.5%
mapping(PoolId => bool) public coveragePaused;
mapping(address => uint256[]) public ownerPolicies;

uint256 public nextPolicyId;
InsuranceVault public vault;
address public reactiveMonitor;                          // authorized caller for risk updates

enum RiskState { CALM, VOLATILE, SHOCK }

struct Policy {
    address owner;
    PoolId poolId;
    bytes32 positionId;       // keccak256(owner, tickLower, tickUpper, salt)
    uint256 notional;         // USD-denominated value at entry (18 dec)
    uint256 entryPrice;       // sqrtPriceX96 at deposit
    uint256 thresholdBps;     // deductible, e.g. 500 = 5%
    uint256 maxPayout;        // cap in notional token units
    uint256 premiumPaid;
    uint256 createdAt;
    uint256 expiry;           // 0 = no expiry
    PolicyStatus status;
}

enum PolicyStatus { ACTIVE, PENDING_CLAIM, PAID, EXPIRED, CANCELLED }
```

**Key functions:**

```solidity
// Called by LP during addLiquidity — policy ID returned
function createPolicy(
    PoolKey calldata key,
    bytes32 positionId,
    uint256 notional,
    uint256 thresholdBps,
    uint256 maxPayout,
    uint256 expiry
) external payable returns (uint256 policyId);

// Called by ReactiveRiskMonitor after detecting LP exit event
function settleClaim(uint256 policyId, uint256 exitSqrtPriceX96) external;

// Called by ReactiveRiskMonitor when volatility crosses threshold
function updateRiskState(PoolId poolId, RiskState newState) external onlyReactiveMonitor;

// Called by ReactiveRiskMonitor when solvency falls below threshold
function pauseCoverage(PoolId poolId) external onlyReactiveMonitor;
function resumeCoverage(PoolId poolId) external onlyReactiveMonitor;

// View helpers for frontend
function getPolicy(uint256 policyId) external view returns (Policy memory);
function getPremiumForNotional(PoolId poolId, uint256 notional) external view returns (uint256);
function calculateIL(uint256 entryPrice, uint256 exitPrice, uint256 notional) external pure returns (uint256 ilBps, uint256 ilAmount);
```

**Hook callbacks:**

```solidity
// afterAddLiquidity: nothing required, policy is created via createPolicy() directly
// afterRemoveLiquidity: emit PolicyExitRequested so Reactive can trigger settlement
function afterRemoveLiquidity(...) external override returns (bytes4, BalanceDelta);
// afterSwap: emit SwapObserved so Reactive can track price movement
function afterSwap(...) external override returns (bytes4, int128);
```

**Events:**

```solidity
event PolicyCreated(uint256 indexed policyId, address indexed owner, PoolId poolId, uint256 notional, uint256 thresholdBps, uint256 premiumPaid);
event PolicyExitRequested(uint256 indexed policyId, address indexed owner, PoolId poolId, uint256 exitSqrtPriceX96);
event RiskStateChanged(PoolId indexed poolId, RiskState oldState, RiskState newState, uint256 volatilityBps, uint256 solvencyBps);
event PremiumUpdated(PoolId indexed poolId, uint256 oldPremiumBps, uint256 newPremiumBps, string reason);
event ClaimRequested(uint256 indexed policyId, address indexed owner, uint256 realizedIlBps);
event ClaimPaid(uint256 indexed policyId, address indexed owner, uint256 payout, uint256 vaultBalanceAfter);
event CoveragePaused(PoolId indexed poolId, string reason);
event CoverageResumed(PoolId indexed poolId);
event SwapObserved(PoolId indexed poolId, uint160 sqrtPriceX96, int24 tick, uint256 timestamp);
```

**IL calculation formula:**

```
Given sqrtPriceX96 entry (p0) and exit (p1):
  price_ratio = (p1/p0)^2
  il_bps = 10000 * (2*sqrt(price_ratio)/(1+price_ratio) - 1) * -1
  covered_il = max(0, il_amount - deductible)
  payout = min(covered_il, maxPayout, vault.availableForClaims())
```

---

### 2. `InsuranceVault.sol`

**Location:** `contracts/src/vault/InsuranceVault.sol`

**Inherits:** `Ownable`, `ReentrancyGuard`

**State:**

```solidity
MockYieldVault public yieldVault;
address public hook;                  // only hook can call depositPremium / payClaim
uint256 public totalPremiums;
uint256 public totalClaimsPaid;
uint256 public totalYieldEarned;
uint256 public liquidReserve;         // tokens held directly (not in yield vault)
uint256 public constant SOLVENCY_THRESHOLD_BPS = 8000;  // 80%
uint256 public constant MIN_LIQUID_RATIO_BPS = 2000;    // 20% of reserves stay liquid
```

**Key functions:**

```solidity
function depositPremium(uint256 amount, address token) external;          // called by hook on policy creation
function payClaim(address recipient, uint256 amount, address token) external; // called by hook on settlement
function accrueYield() external;                                           // called by DemoScenarioRunner or keeper
function rebalance() external;                                             // move between liquid + yield vault
function solvencyRatioBps() external view returns (uint256);               // totalAssets / maxLiability * 10000
function availableForClaims() external view returns (uint256);             // liquid reserve + redeemable from yield vault
function totalAssets() external view returns (uint256);

event PremiumDeposited(address indexed from, uint256 amount, uint256 newVaultBalance);
event ClaimPaid(address indexed to, uint256 amount, uint256 vaultBalanceAfter);
event YieldAccrued(uint256 amount, uint256 newVaultBalance);
event VaultRebalanced(uint256 toYieldVault, uint256 fromYieldVault);
event VaultHealthUpdated(uint256 solvencyBps, uint256 totalAssets);
```

---

### 3. `MockYieldVault.sol`

**Location:** `contracts/src/vault/MockYieldVault.sol`

**Inherits:** `ERC4626` (OZ)

Simple ERC4626 wrapper with an admin-callable `accrueYield(uint256 amount)` that mints extra assets to simulate Aave/Morpho returns. Frontend labels this as "Demo yield vault. Production target: Aave v3 / Morpho / ERC4626."

```solidity
function accrueYield(uint256 amount) external onlyOwner; // mints amount to vault, simulating yield
function totalAssets() public view override returns (uint256);
```

---

### 4. `ReactiveRiskMonitor.sol`

**Location:** `contracts/src/reactive/ReactiveRiskMonitor.sol`

**Deployed on:** Reactive Lasna (chain 5318007)

**Inherits:** `AbstractReactive` (reactive-lib)

This is the Reactive Smart Contract (RSC). It runs on Reactive Network, listens to events on Unichain Sepolia, and fires callback transactions back to `IndemnifiHook`.

**Subscriptions (set in constructor):**

```solidity
// Subscribe to IndemnifiHook on Unichain Sepolia (chain 1301)
service.subscribe(1301, hookAddress, POLICY_EXIT_REQUESTED_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
service.subscribe(1301, hookAddress, SWAP_OBSERVED_TOPIC,         REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
service.subscribe(1301, vaultAddress, VAULT_HEALTH_UPDATED_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
```

**React function:**

```solidity
function react(
    uint256 chainId,
    address _contract,
    uint256 topic_0,
    uint256 topic_1,
    uint256 topic_2,
    uint256 topic_3,
    bytes calldata data,
    uint256 blockNumber,
    uint256 /* opCode */
) external vmOnly {
    if (topic_0 == POLICY_EXIT_REQUESTED_TOPIC) {
        _handlePolicyExit(topic_1 /* policyId */, topic_2 /* exitPrice */);
    } else if (topic_0 == SWAP_OBSERVED_TOPIC) {
        _handleSwapObserved(topic_1 /* poolId */, topic_2 /* sqrtPrice */);
    } else if (topic_0 == VAULT_HEALTH_UPDATED_TOPIC) {
        _handleVaultHealth(topic_1 /* solvencyBps */);
    }
}
```

**Callback payloads it sends back to Unichain:**

```solidity
// Settle a claim after LP exit
emit Callback(1301, hookAddress, GAS_LIMIT, abi.encodeCall(IndemnifiHook.settleClaim, (policyId, exitSqrtPriceX96)));

// Update risk state when volatility spike detected
emit Callback(1301, hookAddress, GAS_LIMIT, abi.encodeCall(IndemnifiHook.updateRiskState, (poolId, newRiskState)));

// Pause coverage when solvency too low
emit Callback(1301, hookAddress, GAS_LIMIT, abi.encodeCall(IndemnifiHook.pauseCoverage, (poolId)));
```

**Funding:** Deploy with `--value 0.1ether` on Reactive Lasna to pay for subscription gas.

---

### 5. `DemoScenarioRunner.sol`

**Location:** `contracts/src/demo/DemoScenarioRunner.sol`

Convenience contract for local Anvil runs and testnet demoing. Executes the complete Alice/Bob scenario in a single transaction or step-by-step.

```solidity
enum Scenario { CALM, VOLATILE, SHOCK }

struct ScenarioConfig {
    uint256 depositAmount;     // e.g. 10_000e18
    uint256 entryPrice;        // sqrtPriceX96
    uint256 exitPrice;         // sqrtPriceX96 after market move
    uint256 thresholdBps;      // Bob's deductible (e.g. 500)
    uint256 maxPayout;         // Bob's policy cap
    uint256 yieldAmount;       // mock yield to accrue in vault
}

function runScenario(Scenario s) external;
function runStep(uint8 step) external;   // 1-11 matching the doc story steps
function getScenarioConfig(Scenario s) external pure returns (ScenarioConfig memory);
function getLastRunResult() external view returns (RunResult memory);

struct RunResult {
    uint256 aliceFinalLoss;
    uint256 bobFinalLoss;
    uint256 bobPayout;
    uint256 vaultBalanceAfter;
    uint256 vaultSolvencyBps;
    bool coveragePaused;
}
```

---

### 6. Libraries

#### `contracts/src/libraries/ILMath.sol`

```solidity
library ILMath {
    // Returns IL in basis points (10000 = 100%) — always positive
    function calculateILBps(uint160 sqrtPriceX96Entry, uint160 sqrtPriceX96Exit) internal pure returns (uint256 ilBps);

    // Returns dollar amount of IL given notional
    function calculateILAmount(uint256 ilBps, uint256 notional) internal pure returns (uint256 ilAmount);

    // Returns the covered portion (above deductible) and payout (capped by maxPayout and available)
    function calculatePayout(
        uint256 ilAmount,
        uint256 thresholdBps,
        uint256 notional,
        uint256 maxPayout,
        uint256 availableInVault
    ) internal pure returns (uint256 deductible, uint256 coveredIl, uint256 payout);
}
```

#### `contracts/src/libraries/PremiumMath.sol`

```solidity
library PremiumMath {
    // Returns premium in token units given notional and current risk state
    function calculatePremium(uint256 notional, uint256 premiumBps) internal pure returns (uint256);

    // Returns new premiumBps based on risk state transition
    function premiumForRiskState(RiskState state) internal pure returns (uint256 bps);
    // CALM    → 150 bps (1.5%)
    // VOLATILE→ 300 bps (3%)
    // SHOCK   → 700 bps (7%)
}
```

#### `contracts/src/libraries/Constants.sol`

```solidity
library Constants {
    uint256 internal constant UNICHAIN_CHAIN_ID  = 1301;     // Unichain Sepolia
    uint256 internal constant REACTIVE_CHAIN_ID  = 5318007;  // Reactive Lasna

    address internal constant CALLBACK_PROXY_ADDRESS = 0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4;

    uint256 internal constant CALM_PREMIUM_BPS     = 150;
    uint256 internal constant VOLATILE_PREMIUM_BPS = 300;
    uint256 internal constant SHOCK_PREMIUM_BPS    = 700;

    uint256 internal constant SOLVENCY_PAUSE_THRESHOLD_BPS = 7000; // pause new policies below 70%
    uint256 internal constant SOLVENCY_RESUME_THRESHOLD_BPS = 8500;

    bytes32 internal constant POLICY_EXIT_REQUESTED_TOPIC = keccak256("PolicyExitRequested(uint256,address,bytes32,uint256)");
    bytes32 internal constant SWAP_OBSERVED_TOPIC         = keccak256("SwapObserved(bytes32,uint160,int24,uint256)");
    bytes32 internal constant VAULT_HEALTH_UPDATED_TOPIC  = keccak256("VaultHealthUpdated(uint256,uint256)");
}
```

---

### 7. Interfaces

```
contracts/src/interfaces/
    IIndemnifiHook.sol
    IInsuranceVault.sol
    IReactiveRiskMonitor.sol
```

---

## Deployment Scripts

### `script/DeployAll.s.sol`
Deploys everything on Unichain Sepolia in sequence:
1. `PoolManager` (or reads existing)
2. Mock tokens (WETH + USDC mock)
3. `MockYieldVault`
4. `InsuranceVault` (linked to yield vault)
5. `PoolSwapTest` + `PoolModifyLiquidityTest` routers
6. Mines hook address with CREATE2
7. Deploys `IndemnifiHook` with mined salt
8. Initializes pool
9. Logs all addresses

### `script/DeployHook.s.sol`
Stand-alone hook deployment. Reads `POOL_MANAGER_ADDRESS` and `VAULT_ADDRESS` from env. Mines a CREATE2 salt matching the required hook flags.

**Required hook flags:**
```solidity
Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
Hooks.AFTER_ADD_LIQUIDITY_FLAG  |
Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
Hooks.AFTER_SWAP_FLAG
```

### `script/DeployReactive.s.sol`
Deploys `ReactiveRiskMonitor` on Reactive Lasna (chain 5318007). Must be sent with `--value 0.1ether` for subscription funding.

### `script/InitPool.s.sol`
Creates the ETH/USDC pool using the deployed hook. Sets initial `sqrtPriceX96` to match $2,000 ETH price.

### `script/RunScenario.s.sol`
Calls `DemoScenarioRunner.runScenario(Scenario.VOLATILE)` on testnet for a live demo.

### `script/HelperConfig.s.sol`
Returns network-specific config (PoolManager address, chain ID, callback proxy) based on `block.chainid`.

---

## Test Structure

```
contracts/test/
    unit/
        ILMath.t.sol              ← pure math, no forks needed
        PremiumMath.t.sol
        InsuranceVault.t.sol
        IndemnifiHook.t.sol       ← uses MockPoolManager
    integration/
        HookLifecycle.t.sol       ← full add/swap/remove/claim flow on local Anvil
        ReactiveCallback.t.sol    ← simulates Reactive callback (mocked caller)
        ScenarioRunner.t.sol      ← runs all 3 preset scenarios, checks exact numbers
    mocks/
        MockERC20.sol
        MockPoolManager.sol
        MockCallbackProxy.sol
        MockReactiveMonitor.sol   ← simulates RSC callbacks without Reactive Network
```

### Unit test example — `ILMath.t.sol`

```solidity
function test_ilBps_noMove() public pure {
    uint160 price = 1 << 96; // 1:1
    assertEq(ILMath.calculateILBps(price, price), 0);
}

function test_ilBps_doublePrice() public pure {
    // ETH goes 2x → IL ≈ 5.72% = 572 bps
    uint160 entry = encodeSqrtPrice(2000e6, 1e18);
    uint160 exit  = encodeSqrtPrice(4000e6, 1e18);
    uint256 il = ILMath.calculateILBps(entry, exit);
    assertApproxEqAbs(il, 572, 5); // ±5 bps tolerance
}
```

### Integration test example — `HookLifecycle.t.sol`

```solidity
function test_fullFlow_volatileScenario() public {
    // 1. Deploy everything locally
    // 2. Alice adds liquidity (no policy)
    // 3. Bob adds liquidity + creates policy (5% threshold, $1000 cap)
    // 4. Premium goes to vault
    // 5. Simulate ETH price 2000→2800 via MockPoolManager
    // 6. Simulate yield accrual on vault
    // 7. Alice removes — no payout
    // 8. Mock Reactive callback: settleClaim(bobPolicyId, exitPrice)
    // 9. Assert Bob received payout
    // 10. Assert vault solvency still > 80%
    // 11. Assert events emitted in correct order
}
```

### Scenario number assertions (exact)

The following table must pass in `ScenarioRunner.t.sol`:

| Scenario | Entry Price | Exit Price | Notional | Threshold | Expected IL | Expected Payout |
|---|---|---|---|---|---|---|
| CALM | $2,000 | $2,080 | $10,000 | 5% | ~0.4% | $0 |
| VOLATILE | $2,000 | $2,800 | $10,000 | 5% | ~9.1% | ~$410 |
| SHOCK | $2,000 | $4,000 | $10,000 | 5% | ~17.2% | min(~$1,220, maxPayout, vaultAvailable) |

---

## ABI Sync for Frontend

After compiling, run:

```bash
make sync-abis
```

This copies compiled ABIs from `contracts/out/` into `frontend/src/abis/`:
- `IndemnifiHook.json`
- `InsuranceVault.json`
- `MockYieldVault.json`
- `DemoScenarioRunner.json`

---

## Environment Variables

### `contracts/.env` (never commit)

```
PRIVATE_KEY=
UNICHAIN_RPC_URL=https://sepolia.unichain.org
REACTIVE_RPC_URL=https://lasna-rpc.rnk.dev/
ETHERSCAN_API_KEY=
POOL_MANAGER_ADDRESS=
VAULT_ADDRESS=
HOOK_ADDRESS=
CALLBACK_PROXY_ADDRESS=0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4
```

### `frontend/.env.local` (never commit)

```
NEXT_PUBLIC_CHAIN_ID=1301
NEXT_PUBLIC_HOOK_ADDRESS=
NEXT_PUBLIC_VAULT_ADDRESS=
NEXT_PUBLIC_YIELD_VAULT_ADDRESS=
NEXT_PUBLIC_SCENARIO_RUNNER_ADDRESS=
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=
```

---

## Frontend Integration Points

The frontend reads contract state and listens for events. All interactions go through wagmi hooks.

### Read operations

```typescript
// usePolicy(policyId: bigint) → Policy
// useVaultState() → { totalAssets, solvencyBps, premiumsDeposited, claimsPaid, yieldEarned }
// usePoolRiskState(poolId: Hex) → RiskState
// useCurrentPremiumBps(poolId: Hex) → bigint
// usePoliciesForOwner(address: Address) → Policy[]
```

### Write operations

```typescript
// useCreatePolicy(params) → wagmi writeContract
// useSettleClaim(policyId) → wagmi writeContract (only if Reactive not connected)
// useRunScenario(scenario: 0|1|2) → wagmi writeContract
```

### Event subscriptions (wagmi `useWatchContractEvent`)

```typescript
// PolicyCreated       → update policy list
// ClaimPaid           → update vault + policy status
// RiskStateChanged    → update risk meter + premium display
// PremiumUpdated      → update displayed premium bps
// VaultHealthUpdated  → update solvency bar
// CoveragePaused      → disable "Create Policy" button
```

---

## Step-by-Step Build Order

1. `ILMath.sol` + unit tests — get the math right first
2. `PremiumMath.sol` + unit tests
3. `MockYieldVault.sol` — simple ERC4626
4. `InsuranceVault.sol` + unit tests
5. `IndemnifiHook.sol` (no Reactive yet) + `HookLifecycle.t.sol`
6. `MockReactiveMonitor.sol` — simulate callbacks
7. `DemoScenarioRunner.sol` + `ScenarioRunner.t.sol` — verify exact numbers
8. `ReactiveRiskMonitor.sol` + `ReactiveCallback.t.sol`
9. Deployment scripts — DeployAll, DeployHook, DeployReactive
10. ABI sync → frontend integration
