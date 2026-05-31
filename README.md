# Indemnifi

Indemnifi is a Uniswap v4 hook system for explicit impermanent-loss protection.

The repo is split into two main workstreams:

- `contracts/`: Foundry-based smart contracts, scripts, and tests
- `frontend/`: Next.js app for the product demo and UI

## Docs

- [Product overview](docs/indemnifi.md)
- [Contract implementation guide](docs/contract-implementation.md)

## Common Tasks

```bash
make build
make test
make frontend-dev
```

## Deployment Helpers

The top-level `Makefile` contains helpers for:

- building and testing contracts
- deploying the hook, vault, and reactive monitor
- syncing generated ABIs into the frontend
