# Testing

## Contracts (Foundry)

```bash
cd contracts
forge test               # run all tests (106)
forge test -vvv          # with traces
forge test --match-contract HookLifecycleTest   # one suite
forge coverage           # coverage report (~95% lines)
```

Integration tests deploy a real in-memory Uniswap v4 `PoolManager`, so no fork
or RPC is required.

```
test/
  unit/         ILMath, PremiumMath, InsuranceVault, MockYieldVault, BaseHook, ReactiveRiskMonitor
  integration/  HookLifecycle, ReactiveCallback, DemoScenarioRunner
  mocks/        MockERC20, MockReactiveMonitor
```

## Frontend

```bash
cd frontend
npm run lint     # eslint
npm run build    # type-check + production build
```

## Everything

From the repo root:

```bash
make test        # contracts
make frontend-build
```
