# Indemnifi — Contracts

Solidity contracts for Indemnifi: a Uniswap v4 hook that sells impermanent-loss
insurance, backed by a yield-bearing vault, with risk monitoring on Reactive Network.

## Layout

```
src/
  hook/IndemnifiHook.sol        v4 hook — sells policies, collects premiums, settles claims
  hook/BaseHook.sol             minimal v4 BaseHook
  vault/InsuranceVault.sol      holds premiums, pays claims, routes idle capital to yield
  vault/MockYieldVault.sol      ERC-4626-style demo yield vault
  reactive/ReactiveRiskMonitor.sol   RSC on Reactive Lasna — auto risk/settlement
  demo/DemoScenarioRunner.sol   one-tx Alice-vs-Bob comparison for the demo
  libraries/                    ILMath, PremiumMath, Constants
  interfaces/                   IIndemnifiHook, IInsuranceVault
  mocks/FaucetToken.sol         testnet ERC-20 with a public faucet
script/                         deployment scripts
test/                           unit + integration tests
```

## Quick start

```bash
forge install      # if libs are missing
forge build
forge test
```

## Tests

```bash
forge test               # all tests
forge test -vvv          # with traces
forge coverage           # coverage report
```

Integration tests run against a real in-memory v4 `PoolManager` (no fork needed).
Current: **106 tests, ~95% line coverage.**

## Deployment

Create `contracts/.env` (gitignored):

```
PRIVATE_KEY=0x...
UNICHAIN_RPC_URL=https://sepolia.unichain.org
REACTIVE_RPC_URL=https://lasna-rpc.rnk.dev/
```

From the repo root:

```bash
make deploy-testnet     # Unichain Sepolia: tokens, vaults, hook, pool, seed, runner
make deploy-reactive    # Reactive Lasna: ReactiveRiskMonitor (needs REACT for gas)
make set-proxy          # authorize the Reactive callback proxy on the hook
make sync-abis          # copy ABIs to frontend/src/abis
```

`deploy-testnet` prints a ready-to-paste `frontend/.env.local` block with all
addresses.

## How it works

1. An LP calls `createPolicy(poolKey, notional, deductibleBps, maxPayout, expiry)`
   and pays a premium (in currency0) priced by current pool risk.
2. Premiums pool into `InsuranceVault`; idle capital earns yield.
3. On `afterSwap` / `afterRemoveLiquidity` the hook emits events.
4. `ReactiveRiskMonitor` (on Lasna) reacts: reprices premiums on volatility and
   settles claims on exit by calling back into the hook.

## Notes

- The hook address is CREATE2-mined so its low bits encode the v4 permission
  flags (`AFTER_REMOVE_LIQUIDITY | AFTER_SWAP`).
- Premiums/claims use currency0 (the lower token address).
- `ReactiveRiskMonitor` subscribes via the system contract and fires callbacks
  through the Reactive callback proxy. After deploying it, run `make set-proxy`
  to authorize that proxy on the hook (the address is in `Constants.sol`).
