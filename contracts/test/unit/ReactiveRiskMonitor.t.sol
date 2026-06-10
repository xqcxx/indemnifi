// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ReactiveRiskMonitor} from "../../src/reactive/ReactiveRiskMonitor.sol";
import {LogRecord} from "reactive-lib/interfaces/IReactive.sol";
import {IIndemnifiHook} from "../../src/interfaces/IIndemnifiHook.sol";
import {Constants} from "../../src/libraries/Constants.sol";

// Unit tests for the Reactive Smart Contract dispatcher. In tests the system
// contract is absent, so the RSC runs as a ReactVM (vm == true) and react() is
// callable directly. We assert the Callback payloads emitted per topic.
contract ReactiveRiskMonitorTest is Test {
    bytes32 constant CB_TOPIC = keccak256("Callback(uint256,address,uint64,bytes)");

    ReactiveRiskMonitor monitor;
    address hookAddr  = makeAddr("hook");
    address vaultAddr = makeAddr("vault");
    bytes32 poolId    = keccak256("ETH/USDC");

    function setUp() public {
        monitor = new ReactiveRiskMonitor(hookAddr, vaultAddr);
    }

    function _react(bytes32 topic0, uint256 t1, uint256 t2) internal {
        LogRecord memory log;
        log.chain_id = Constants.UNICHAIN_CHAIN_ID;
        log._contract = hookAddr;
        log.topic_0 = uint256(topic0);
        log.topic_1 = t1;
        log.topic_2 = t2;
        monitor.react(log);
    }

    // Decode the most recent Callback event's payload from recorded logs.
    function _lastCallbackPayload(Vm.Log[] memory logs) internal pure returns (bytes memory payload, bool found) {
        for (uint256 i = logs.length; i > 0; i--) {
            Vm.Log memory l = logs[i - 1];
            if (l.topics.length > 0 && l.topics[0] == CB_TOPIC) {
                payload = abi.decode(l.data, (bytes));
                return (payload, true);
            }
        }
    }

    // ── Constructor emits 3 subscriptions ────────────────────────────────────

    function test_constructor_storesAddresses() public view {
        assertEq(monitor.hookAddress(), hookAddr);
        assertEq(monitor.vaultAddress(), vaultAddr);
    }

    // In tests the system contract is absent, so the RSC is a ReactVM and
    // react() is callable. (On the real network, vmOnly would reject it.)

    // ── PolicyExitRequested -> settleClaim callback ──────────────────────────

    function test_policyExit_emitsSettleClaimCallback() public {
        uint256 policyId = 7;
        uint160 exitPrice = 5010828967500958937382912;

        vm.recordLogs();
        _react(Constants.POLICY_EXIT_REQUESTED_TOPIC, policyId, exitPrice);
        (bytes memory payload, bool found) = _lastCallbackPayload(vm.getRecordedLogs());

        assertTrue(found, "no Callback emitted");
        bytes memory expected = abi.encodeCall(IIndemnifiHook.settleClaim, (policyId, exitPrice));
        assertEq(keccak256(payload), keccak256(expected), "settleClaim payload mismatch");
    }

    // ── SwapObserved -> first snapshot is no-op ──────────────────────────────

    function test_swap_firstObservation_noCallback() public {
        vm.recordLogs();
        _react(Constants.SWAP_OBSERVED_TOPIC, uint256(poolId), 1000);
        (, bool found) = _lastCallbackPayload(vm.getRecordedLogs());
        assertFalse(found, "first snapshot should not callback");
        assertEq(monitor.lastSqrtPrice(poolId), 1000);
    }

    function test_swap_smallMove_noTierChange() public {
        _react(Constants.SWAP_OBSERVED_TOPIC, uint256(poolId), 1000);
        // +5% < 10% volatile threshold
        vm.recordLogs();
        _react(Constants.SWAP_OBSERVED_TOPIC, uint256(poolId), 1050);
        (, bool found) = _lastCallbackPayload(vm.getRecordedLogs());
        assertFalse(found, "small move should not change tier");
        assertEq(monitor.lastSqrtPrice(poolId), 1050);
    }

    function test_swap_volatileMove_emitsUpdateRiskTierVolatile() public {
        _react(Constants.SWAP_OBSERVED_TOPIC, uint256(poolId), 1000);
        // +15% -> volatile (>=10%, <25%)
        vm.recordLogs();
        _react(Constants.SWAP_OBSERVED_TOPIC, uint256(poolId), 1150);
        (bytes memory payload, bool found) = _lastCallbackPayload(vm.getRecordedLogs());

        assertTrue(found);
        bytes memory expected =
            abi.encodeCall(IIndemnifiHook.updateRiskTier, (poolId, IIndemnifiHook.RiskTier.VOLATILE));
        assertEq(keccak256(payload), keccak256(expected));
    }

    function test_swap_shockMove_emitsUpdateRiskTierShock() public {
        _react(Constants.SWAP_OBSERVED_TOPIC, uint256(poolId), 1000);
        // +30% -> shock (>=25%)
        vm.recordLogs();
        _react(Constants.SWAP_OBSERVED_TOPIC, uint256(poolId), 1300);
        (bytes memory payload, bool found) = _lastCallbackPayload(vm.getRecordedLogs());

        assertTrue(found);
        bytes memory expected =
            abi.encodeCall(IIndemnifiHook.updateRiskTier, (poolId, IIndemnifiHook.RiskTier.SHOCK));
        assertEq(keccak256(payload), keccak256(expected));
    }

    function test_swap_downwardMove_alsoCountsAbsolute() public {
        _react(Constants.SWAP_OBSERVED_TOPIC, uint256(poolId), 1000);
        // -30% -> shock
        vm.recordLogs();
        _react(Constants.SWAP_OBSERVED_TOPIC, uint256(poolId), 700);
        (bytes memory payload, bool found) = _lastCallbackPayload(vm.getRecordedLogs());
        assertTrue(found);
        bytes memory expected =
            abi.encodeCall(IIndemnifiHook.updateRiskTier, (poolId, IIndemnifiHook.RiskTier.SHOCK));
        assertEq(keccak256(payload), keccak256(expected));
    }

    // ── VaultHealthUpdated -> pause callback when below threshold ─────────────

    function test_vaultHealth_healthy_noCallback() public {
        vm.recordLogs();
        _react(Constants.VAULT_HEALTH_UPDATED_TOPIC, 9000, 0); // 90% >= 70%
        (, bool found) = _lastCallbackPayload(vm.getRecordedLogs());
        assertFalse(found, "healthy vault should not pause");
    }

    function test_vaultHealth_lowSolvency_emitsPauseCallback() public {
        vm.recordLogs();
        _react(Constants.VAULT_HEALTH_UPDATED_TOPIC, 5000, 0); // 50% < 70%
        (bytes memory payload, bool found) = _lastCallbackPayload(vm.getRecordedLogs());

        assertTrue(found);
        bytes memory expected = abi.encodeCall(IIndemnifiHook.pauseCoverage, (bytes32(0)));
        assertEq(keccak256(payload), keccak256(expected));
    }

    function test_unknownTopic_noCallback() public {
        vm.recordLogs();
        _react(keccak256("SomethingElse()"), 1, 2);
        (, bool found) = _lastCallbackPayload(vm.getRecordedLogs());
        assertFalse(found);
    }
}
