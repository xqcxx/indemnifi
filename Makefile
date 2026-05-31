# ============================================================
# Indemnifi — Top-Level Makefile
# ============================================================

.PHONY: build test test-fork \
        deploy-all deploy-hook deploy-reactive init-pool run-scenario \
        frontend-install frontend-dev frontend-build \
        install sync-abis clean

# ------- Contracts (Foundry) -------

build:
	cd contracts && forge build

test:
	cd contracts && forge test -vvv

test-fork:
	cd contracts && forge test --fork-url $(UNICHAIN_RPC_URL) -vvv

# Deploy infrastructure (PoolManager, tokens, vaults, routers)
deploy-all:
	cd contracts && forge script script/DeployAll.s.sol \
		--rpc-url $(UNICHAIN_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast -vvv

# Deploy IndemnifiHook via CREATE2 address mining
deploy-hook:
	cd contracts && forge script script/DeployHook.s.sol \
		--rpc-url $(UNICHAIN_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast -vvv

# Deploy ReactiveRiskMonitor on Reactive Lasna
deploy-reactive:
	cd contracts && forge script script/DeployReactive.s.sol \
		--rpc-url $(REACTIVE_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast -vvv

# Initialize ETH/USDC pool with the deployed hook
init-pool:
	cd contracts && forge script script/InitPool.s.sol \
		--rpc-url $(UNICHAIN_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast -vvv

# ------- Frontend (Next.js) -------

frontend-install:
	cd frontend && npm ci

frontend-dev:
	cd frontend && npm run dev

frontend-build:
	cd frontend && npm run build

# ------- Cross-Cutting -------

install: frontend-install
	cd contracts && forge install

# Copy compiled ABIs from contracts/out/ → frontend/src/abis/
sync-abis:
	mkdir -p frontend/src/abis
	cp contracts/out/IndemnifiHook.sol/IndemnifiHook.json     frontend/src/abis/
	cp contracts/out/InsuranceVault.sol/InsuranceVault.json   frontend/src/abis/
	cp contracts/out/MockYieldVault.sol/MockYieldVault.json   frontend/src/abis/
	cp contracts/out/DemoScenarioRunner.sol/DemoScenarioRunner.json frontend/src/abis/
	@echo "ABIs synced to frontend/src/abis/"

clean:
	cd contracts && forge clean
	cd frontend && rm -rf .next node_modules
