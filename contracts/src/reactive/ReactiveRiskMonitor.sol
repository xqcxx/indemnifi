// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AbstractReactive} from "reactive-lib/abstract-base/AbstractReactive.sol";
import {IIndemnifiHook} from "../interfaces/IIndemnifiHook.sol";
import {Constants} from "../libraries/Constants.sol";

// RSC deployed on Reactive Lasna (chain 5318008).
//
// Subscribes to three event streams from Unichain Sepolia:
//   1. IndemnifiHook  → PolicyExitRequested : triggers settleClaim()
//   2. IndemnifiHook  → SwapObserved        : detects price divergence, updates risk tier
//   3. InsuranceVault → VaultHealthUpdated  : pauses coverage when solvency is low
//
// Callbacks are fired back to IndemnifiHook on Unichain through the Reactive
// Network relay, which routes them through the CALLBACK_PROXY_ADDRESS.
//
// Deploy with: forge create --value 0.1ether ... (funds subscription gas)
contract ReactiveRiskMonitor is AbstractReactive {
    address public immutable hookAddress;
    address public immutable vaultAddress;

    // Price snapshot per pool (bytes32 poolId → last sqrtPriceX96).
    mapping(bytes32 => uint160) public lastSqrtPrice;

    // A price move this large (relative to last snapshot) upgrades the risk tier.
    uint256 public constant VOLATILE_THRESHOLD_BPS = 1000; // 10%
    uint256 public constant SHOCK_THRESHOLD_BPS    = 2500; // 25%

    event ReactiveCallback(string action, uint256 indexed ref);

    constructor(address _hookAddress, address _vaultAddress) payable {
        hookAddress  = _hookAddress;
        vaultAddress = _vaultAddress;

        // Subscribe on Unichain Sepolia (chain 1301).
        emit Subscribe(
            Constants.UNICHAIN_CHAIN_ID,
            _hookAddress,
            uint256(Constants.POLICY_EXIT_REQUESTED_TOPIC),
            0, 0, 0
        );
        emit Subscribe(
            Constants.UNICHAIN_CHAIN_ID,
            _hookAddress,
            uint256(Constants.SWAP_OBSERVED_TOPIC),
            0, 0, 0
        );
        emit Subscribe(
            Constants.UNICHAIN_CHAIN_ID,
            _vaultAddress,
            uint256(Constants.VAULT_HEALTH_UPDATED_TOPIC),
            0, 0, 0
        );
    }

    // ── Reactive entry point ──────────────────────────────────────────────

    function react(
        uint256, // chainId — always UNICHAIN_CHAIN_ID per subscriptions
        address, // _contract — filtered by subscription
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256, // topic_3 — unused
        bytes calldata, // data — not needed; everything is in indexed topics
        uint64,  // blockNumber
        uint256  // opCode
    ) external override vmOnly {
        bytes32 sig = bytes32(topic_0);

        if (sig == Constants.POLICY_EXIT_REQUESTED_TOPIC) {
            // topic_1 = policyId (indexed uint256)
            // topic_2 = exitSqrtPriceX96 (indexed uint160 packed into uint256, upper bits are 0)
            // forge-lint: disable-next-line(unsafe-typecast)
            _handlePolicyExit(topic_1, uint160(topic_2));

        } else if (sig == Constants.SWAP_OBSERVED_TOPIC) {
            // topic_1 = poolId (bytes32 → uint256)
            // topic_2 = sqrtPriceX96 (uint160 emitted into uint256 topic, upper bits are 0)
            // forge-lint: disable-next-line(unsafe-typecast)
            _handleSwapObserved(bytes32(topic_1), uint160(topic_2));

        } else if (sig == Constants.VAULT_HEALTH_UPDATED_TOPIC) {
            // topic_1 = solvencyBps
            _handleVaultHealth(topic_1);
        }
    }

    // ── Handlers ─────────────────────────────────────────────────────────

    function _handlePolicyExit(uint256 policyId, uint160 exitPrice) internal {
        emit Callback(
            Constants.UNICHAIN_CHAIN_ID,
            hookAddress,
            Constants.CALLBACK_GAS,
            abi.encodeCall(IIndemnifiHook.settleClaim, (policyId, exitPrice))
        );
        emit ReactiveCallback("settleClaim", policyId);
    }

    function _handleSwapObserved(bytes32 poolId, uint160 newPrice) internal {
        uint160 prev = lastSqrtPrice[poolId];

        if (prev == 0) {
            lastSqrtPrice[poolId] = newPrice;
            return;
        }

        uint256 divergeBps;
        if (newPrice > prev) {
            divergeBps = ((uint256(newPrice) - uint256(prev)) * 10_000) / uint256(prev);
        } else {
            divergeBps = ((uint256(prev) - uint256(newPrice)) * 10_000) / uint256(prev);
        }

        lastSqrtPrice[poolId] = newPrice;

        IIndemnifiHook.RiskTier tier;
        if (divergeBps >= SHOCK_THRESHOLD_BPS) {
            tier = IIndemnifiHook.RiskTier.SHOCK;
        } else if (divergeBps >= VOLATILE_THRESHOLD_BPS) {
            tier = IIndemnifiHook.RiskTier.VOLATILE;
        } else {
            // No tier change needed for small moves.
            return;
        }

        emit Callback(
            Constants.UNICHAIN_CHAIN_ID,
            hookAddress,
            Constants.CALLBACK_GAS,
            abi.encodeCall(IIndemnifiHook.updateRiskTier, (poolId, tier))
        );
        emit ReactiveCallback("updateRiskTier", uint256(divergeBps));
    }

    function _handleVaultHealth(uint256 solvencyBps) internal {
        if (solvencyBps >= Constants.SOLVENCY_PAUSE_BPS) return;

        // Pause coverage on the zero-address sentinel pool — the hook
        // treats this as a global pause signal in the demo. In production
        // the vault event would carry the specific poolId.
        emit Callback(
            Constants.UNICHAIN_CHAIN_ID,
            hookAddress,
            Constants.CALLBACK_GAS,
            abi.encodeCall(IIndemnifiHook.pauseCoverage, (bytes32(0)))
        );
        emit ReactiveCallback("pauseCoverage", solvencyBps);
    }
}
