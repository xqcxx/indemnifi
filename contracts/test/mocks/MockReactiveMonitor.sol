// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IndemnifiHook} from "../../src/hook/IndemnifiHook.sol";
import {IIndemnifiHook} from "../../src/interfaces/IIndemnifiHook.sol";

// Simulates the Reactive Network callback proxy in tests.
// Impersonates the proxy address so we can call hook risk functions
// without deploying the actual RSC on Reactive Lasna.
contract MockReactiveMonitor {
    IndemnifiHook public immutable hook;

    constructor(IndemnifiHook _hook) {
        hook = _hook;
    }

    function triggerSettleClaim(uint256 policyId, uint160 exitPrice) external {
        hook.settleClaim(policyId, exitPrice);
    }

    function triggerUpdateRiskTier(bytes32 poolId, IIndemnifiHook.RiskTier tier) external {
        hook.updateRiskTier(poolId, tier);
    }

    function triggerPauseCoverage(bytes32 poolId) external {
        hook.pauseCoverage(poolId);
    }

    function triggerResumeCoverage(bytes32 poolId) external {
        hook.resumeCoverage(poolId);
    }
}
