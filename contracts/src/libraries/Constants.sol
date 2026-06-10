// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Constants {
    uint256 internal constant UNICHAIN_CHAIN_ID  = 1301;
    uint256 internal constant REACTIVE_CHAIN_ID  = 5318007; // Lasna testnet

    // Callback proxy on Unichain Sepolia — only this address may call hook risk functions
    address internal constant CALLBACK_PROXY_ADDRESS = 0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4;

    // Reactive system address that calls react() on RSCs
    address internal constant REACTIVE_SYSTEM = 0x0000000000000000000000000000000000fffFfF;

    // Premium rates by risk tier (basis points, 1 bps = 0.01%)
    uint256 internal constant CALM_PREMIUM_BPS     = 150; // 1.5%
    uint256 internal constant VOLATILE_PREMIUM_BPS = 300; // 3.0%
    uint256 internal constant SHOCK_PREMIUM_BPS    = 700; // 7.0%

    // Vault solvency thresholds
    uint256 internal constant SOLVENCY_PAUSE_BPS  = 7000; // pause new policies below 70%
    uint256 internal constant SOLVENCY_RESUME_BPS = 8500; // resume above 85%

    // Gas limit for Reactive Network callbacks back to Unichain
    uint256 internal constant CALLBACK_GAS = 500_000;

    // keccak256 of event signatures — used by ReactiveRiskMonitor subscriptions
    bytes32 internal constant POLICY_EXIT_REQUESTED_TOPIC =
        keccak256("PolicyExitRequested(uint256,address,bytes32,uint160)");
    bytes32 internal constant SWAP_OBSERVED_TOPIC =
        keccak256("SwapObserved(bytes32,uint160,int24,uint256)");
    bytes32 internal constant VAULT_HEALTH_UPDATED_TOPIC =
        keccak256("VaultHealthUpdated(uint256,uint256)");
}
