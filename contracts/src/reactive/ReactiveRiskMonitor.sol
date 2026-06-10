// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AbstractReactive} from "reactive-lib/abstract-base/AbstractReactive.sol";
import {LogRecord} from "reactive-lib/interfaces/IReactive.sol";
import {IIndemnifiHook} from "../interfaces/IIndemnifiHook.sol";
import {Constants} from "../libraries/Constants.sol";

// Reactive Smart Contract on Lasna. Subscribes to IndemnifiHook/InsuranceVault
// events on Unichain Sepolia and fires callbacks: settleClaim on exit,
// updateRiskTier on swap divergence, pauseCoverage on low solvency.
// Deploy with --value to fund subscription gas.
contract ReactiveRiskMonitor is AbstractReactive {
    address public immutable hookAddress;
    address public immutable vaultAddress;

    // Price snapshot per pool (bytes32 poolId → last sqrtPriceX96).
    mapping(bytes32 => uint160) public lastSqrtPrice;

    // A price move this large (relative to last snapshot) upgrades the risk tier.
    uint256 public constant VOLATILE_THRESHOLD_BPS = 1000; // 10%
    uint256 public constant SHOCK_THRESHOLD_BPS    = 2500; // 25%

    event ReactiveCallback(string action, uint256 indexed ref);

    uint64 internal constant CALLBACK_GAS = uint64(Constants.CALLBACK_GAS);

    constructor(address _hookAddress, address _vaultAddress) payable {
        hookAddress  = _hookAddress;
        vaultAddress = _vaultAddress;

        // Subscriptions register on the Reactive Network, not inside the ReactVM.
        if (!vm) {
            service.subscribe(
                Constants.UNICHAIN_CHAIN_ID,
                _hookAddress,
                uint256(Constants.POLICY_EXIT_REQUESTED_TOPIC),
                REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
            );
            service.subscribe(
                Constants.UNICHAIN_CHAIN_ID,
                _hookAddress,
                uint256(Constants.SWAP_OBSERVED_TOPIC),
                REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
            );
            service.subscribe(
                Constants.UNICHAIN_CHAIN_ID,
                _vaultAddress,
                uint256(Constants.VAULT_HEALTH_UPDATED_TOPIC),
                REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
            );
        }
    }

    // Entry point invoked by the ReactVM. Indexed args travel in the topics.
    function react(LogRecord calldata log) external override vmOnly {
        bytes32 sig = bytes32(log.topic_0);

        if (sig == Constants.POLICY_EXIT_REQUESTED_TOPIC) {
            // forge-lint: disable-next-line(unsafe-typecast)
            _handlePolicyExit(log.topic_1, uint160(log.topic_2));
        } else if (sig == Constants.SWAP_OBSERVED_TOPIC) {
            // forge-lint: disable-next-line(unsafe-typecast)
            _handleSwapObserved(bytes32(log.topic_1), uint160(log.topic_2));
        } else if (sig == Constants.VAULT_HEALTH_UPDATED_TOPIC) {
            _handleVaultHealth(log.topic_1);
        }
    }

    function _handlePolicyExit(uint256 policyId, uint160 exitPrice) internal {
        emit Callback(
            Constants.UNICHAIN_CHAIN_ID,
            hookAddress,
            CALLBACK_GAS,
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
            return; // small move, no tier change
        }

        emit Callback(
            Constants.UNICHAIN_CHAIN_ID,
            hookAddress,
            CALLBACK_GAS,
            abi.encodeCall(IIndemnifiHook.updateRiskTier, (poolId, tier))
        );
        emit ReactiveCallback("updateRiskTier", uint256(divergeBps));
    }

    function _handleVaultHealth(uint256 solvencyBps) internal {
        if (solvencyBps >= Constants.SOLVENCY_PAUSE_BPS) return;

        // bytes32(0) is the global-pause sentinel; vault health is pool-agnostic.
        emit Callback(
            Constants.UNICHAIN_CHAIN_ID,
            hookAddress,
            CALLBACK_GAS,
            abi.encodeCall(IIndemnifiHook.pauseCoverage, (bytes32(0)))
        );
        emit ReactiveCallback("pauseCoverage", solvencyBps);
    }
}
