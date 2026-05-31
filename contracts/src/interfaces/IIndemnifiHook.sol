// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

interface IIndemnifiHook {
    // ── Types ─────────────────────────────────────────────────────────────

    enum RiskTier { CALM, VOLATILE, SHOCK }

    enum PolicyStatus { ACTIVE, PENDING_CLAIM, PAID, EXPIRED, CANCELLED }

    struct Policy {
        address owner;
        PoolId  poolId;
        // token used as premium and claim currency (currency0 of the pool key)
        address token;
        uint256 notional;
        uint160 entryPrice;   // sqrtPriceX96 at deposit
        uint256 thresholdBps; // deductible — IL below this is uninsured
        uint256 maxPayout;
        uint256 premiumPaid;
        uint256 createdAt;
        uint256 expiry;       // 0 = no expiry
        PolicyStatus status;
    }

    // ── Events ────────────────────────────────────────────────────────────

    event PolicyCreated(
        uint256 indexed policyId,
        address indexed owner,
        bytes32 indexed poolId,
        uint256 notional,
        uint256 thresholdBps,
        uint256 premiumPaid
    );
    event PolicyExitRequested(
        uint256 indexed policyId,
        address indexed owner,
        bytes32 indexed poolId,
        uint160 exitSqrtPriceX96
    );
    event ClaimRequested(uint256 indexed policyId, address indexed owner, uint256 ilBps);
    event ClaimPaid(uint256 indexed policyId, address indexed owner, uint256 payout, uint256 vaultBalance);
    event ClaimExpired(uint256 indexed policyId);
    event RiskTierChanged(bytes32 indexed poolId, RiskTier oldTier, RiskTier newTier, uint256 solvencyBps);
    event PremiumRateUpdated(bytes32 indexed poolId, uint256 oldBps, uint256 newBps);
    event CoveragePaused(bytes32 indexed poolId, string reason);
    event CoverageResumed(bytes32 indexed poolId);
    event SwapObserved(bytes32 indexed poolId, uint160 sqrtPriceX96, int24 tick, uint256 timestamp);

    // ── Write functions ───────────────────────────────────────────────────

    function createPolicy(
        PoolKey calldata key,
        uint256 notional,
        uint256 thresholdBps,
        uint256 maxPayout,
        uint256 expiry
    ) external returns (uint256 policyId);

    // Called by ReactiveRiskMonitor (via callback proxy) after PolicyExitRequested
    function settleClaim(uint256 policyId, uint160 exitSqrtPriceX96) external;

    // Called by ReactiveRiskMonitor when swap activity signals a risk tier change
    function updateRiskTier(bytes32 poolId, RiskTier newTier) external;

    // Called by ReactiveRiskMonitor when vault solvency falls below threshold
    function pauseCoverage(bytes32 poolId) external;
    function resumeCoverage(bytes32 poolId) external;

    // ── View functions ────────────────────────────────────────────────────

    function getPolicy(uint256 policyId) external view returns (Policy memory);
    function getPoliciesForOwner(address owner) external view returns (uint256[] memory);
    function getPremiumForNotional(bytes32 poolId, uint256 notional) external view returns (uint256);
    function isCoveragePaused(bytes32 poolId) external view returns (bool);
    function getRiskTier(bytes32 poolId) external view returns (RiskTier);
    function getCurrentPremiumBps(bytes32 poolId) external view returns (uint256);
}
