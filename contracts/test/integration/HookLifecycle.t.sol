// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20 as SolmateMockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {IndemnifiHook} from "../../src/hook/IndemnifiHook.sol";
import {InsuranceVault} from "../../src/vault/InsuranceVault.sol";
import {MockYieldVault} from "../../src/vault/MockYieldVault.sol";
import {MockReactiveMonitor} from "../mocks/MockReactiveMonitor.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IIndemnifiHook} from "../../src/interfaces/IIndemnifiHook.sol";
import {Constants} from "../../src/libraries/Constants.sol";
import {ILMath} from "../../src/libraries/ILMath.sol";

// Full hook lifecycle exercised against a real, locally-deployed v4 PoolManager.
//
// This runs in plain `forge test` (no fork required). It deploys a PoolManager,
// the modify-liquidity / swap routers, the Indemnifi stack, initializes a pool
// whose currency0 is the reserve token, and drives:
//   addLiquidity -> createPolicy -> swap (afterSwap) -> removeLiquidity
//   (afterRemoveLiquidity emits PolicyExitRequested) -> settleClaim.
contract HookLifecycleTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    // afterRemoveLiquidity + afterSwap
    uint160 constant FLAGS = uint160(Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG);

    MockYieldVault      yieldVault;
    InsuranceVault      insuranceVault;
    IndemnifiHook       hook;
    MockReactiveMonitor monitor;

    // reserve token = currency0 (premiums + claims are paid in this)
    address reserve;

    PoolKey poolKey;
    bytes32 poolId;

    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();
        reserve = Currency.unwrap(currency0);

        // Vault stack uses currency0 as its reserve asset.
        yieldVault     = new MockYieldVault(IERC20(reserve), address(this));
        insuranceVault = new InsuranceVault(address(this), IERC20(reserve), yieldVault);

        // Deploy hook at a flag-correct address.
        address hookAddr = address(uint160(FLAGS));
        deployCodeTo(
            "IndemnifiHook.sol:IndemnifiHook",
            abi.encode(manager, insuranceVault, address(this)),
            hookAddr
        );
        hook = IndemnifiHook(hookAddr);

        monitor = new MockReactiveMonitor(hook);
        insuranceVault.setHook(address(hook));
        hook.setCallbackProxy(address(monitor));

        // Pool at 1:1.
        (poolKey,) = initPoolAndAddLiquidity(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
        poolId = PoolId.unwrap(poolKey.toId());

        // Fund alice & bob with the reserve token and approve hook + routers.
        _fund(alice);
        _fund(bob);
    }

    function _fund(address who) internal {
        SolmateMockERC20(reserve).mint(who, 1_000_000e18);
        SolmateMockERC20(Currency.unwrap(currency1)).mint(who, 1_000_000e18);
        vm.startPrank(who);
        IERC20(reserve).approve(address(hook), type(uint256).max);
        IERC20(reserve).approve(address(modifyLiquidityRouter), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(modifyLiquidityRouter), type(uint256).max);
        IERC20(reserve).approve(address(swapRouter), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    // ── Deployment wiring ───────────────────────────────────────────────────

    function test_hook_deployed_withCorrectWiring() public view {
        assertEq(address(hook.vault()), address(insuranceVault));
        assertEq(hook.callbackProxy(), address(monitor));
        assertEq(insuranceVault.hook(), address(hook));
        // permissions encoded in address
        Hooks.Permissions memory p = hook.getHookPermissions();
        assertTrue(p.afterRemoveLiquidity);
        assertTrue(p.afterSwap);
        assertFalse(p.beforeSwap);
    }

    // ── createPolicy ────────────────────────────────────────────────────────

    function test_createPolicy_recordsPolicyAndCollectsPremium() public {
        uint256 notional = 10_000e18;
        uint256 before   = IERC20(reserve).balanceOf(address(insuranceVault));

        vm.prank(bob);
        uint256 pid = hook.createPolicy(poolKey, notional, 500, 1_000e18, 0);

        IIndemnifiHook.Policy memory p = hook.getPolicy(pid);
        assertEq(p.owner, bob);
        assertEq(p.notional, notional);
        assertEq(p.thresholdBps, 500);
        assertEq(p.token, reserve);
        assertEq(uint8(p.status), uint8(IIndemnifiHook.PolicyStatus.ACTIVE));
        assertEq(p.premiumPaid, notional * Constants.CALM_PREMIUM_BPS / 10_000);

        // Premium entered the vault.
        assertGt(IERC20(reserve).balanceOf(address(insuranceVault)), before);
        assertEq(insuranceVault.totalPremiums(), p.premiumPaid);

        // Owner index populated.
        uint256[] memory owned = hook.getPoliciesForOwner(bob);
        assertEq(owned.length, 1);
        assertEq(owned[0], pid);
    }

    function test_createPolicy_defaultsMaxPayoutToNotional() public {
        vm.prank(bob);
        uint256 pid = hook.createPolicy(poolKey, 5_000e18, 500, 0, 0);
        assertEq(hook.getPolicy(pid).maxPayout, 5_000e18);
    }

    function test_createPolicy_revertsZeroNotional() public {
        vm.prank(bob);
        vm.expectRevert(IndemnifiHook.ZeroNotional.selector);
        hook.createPolicy(poolKey, 0, 500, 1_000e18, 0);
    }

    function test_createPolicy_revertsInvalidThreshold() public {
        vm.prank(bob);
        vm.expectRevert(IndemnifiHook.InvalidThreshold.selector);
        hook.createPolicy(poolKey, 10_000e18, 10_000, 1_000e18, 0);
    }

    function test_createPolicy_revertsWhenPaused() public {
        monitor.triggerPauseCoverage(poolId);
        vm.prank(bob);
        vm.expectRevert(IndemnifiHook.CoveragePausedForPool.selector);
        hook.createPolicy(poolKey, 10_000e18, 500, 1_000e18, 0);
    }

    // ── afterSwap emits SwapObserved ──────────────────────────────────────────

    function test_afterSwap_emitsSwapObserved() public {
        // We can't easily predict the exact post-swap price, so just assert the
        // event topic fires by recording logs.
        vm.recordLogs();
        swap(poolKey, true, -1e15, "");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 sig = keccak256("SwapObserved(bytes32,uint160,int24,uint256)");
        bool found;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == sig) found = true;
        }
        assertTrue(found, "SwapObserved not emitted");
    }

    // ── afterRemoveLiquidity emits PolicyExitRequested ───────────────────────

    function test_removeLiquidity_withPolicyId_emitsExitAndFlipsStatus() public {
        // Bob adds his own liquidity, buys a policy, then removes encoding the policyId.
        vm.startPrank(bob);
        modifyLiquidityRouter.modifyLiquidity(poolKey, LIQUIDITY_PARAMS, "");
        uint256 pid = hook.createPolicy(poolKey, 10_000e18, 500, 1_000e18, 0);

        vm.recordLogs();
        modifyLiquidityRouter.modifyLiquidity(poolKey, REMOVE_LIQUIDITY_PARAMS, abi.encode(pid));
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sig = keccak256("PolicyExitRequested(uint256,address,bytes32,uint160)");
        bool found;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == sig) found = true;
        }
        assertTrue(found, "PolicyExitRequested not emitted");
        assertEq(uint8(hook.getPolicy(pid).status), uint8(IIndemnifiHook.PolicyStatus.PENDING_CLAIM));
    }

    function test_removeLiquidity_withoutPolicyData_noExit() public {
        vm.startPrank(bob);
        modifyLiquidityRouter.modifyLiquidity(poolKey, LIQUIDITY_PARAMS, "");
        uint256 pid = hook.createPolicy(poolKey, 10_000e18, 500, 1_000e18, 0);
        // remove with empty hookData -> no exit, policy stays ACTIVE
        modifyLiquidityRouter.modifyLiquidity(poolKey, REMOVE_LIQUIDITY_PARAMS, "");
        vm.stopPrank();
        assertEq(uint8(hook.getPolicy(pid).status), uint8(IIndemnifiHook.PolicyStatus.ACTIVE));
    }

    // ── Full settle path via monitor ─────────────────────────────────────────

    function test_settleClaim_paysInsuredLP() public {
        // Seed vault so a claim can be paid.
        IERC20(reserve).approve(address(insuranceVault), 20_000e18);
        SolmateMockERC20(reserve).mint(address(this), 20_000e18);
        IERC20(reserve).approve(address(insuranceVault), 20_000e18);
        insuranceVault.accrueYield(20_000e18);

        vm.prank(bob);
        uint256 pid = hook.createPolicy(poolKey, 10_000e18, 500, 1_000e18, 0);

        uint256 bobBefore = IERC20(reserve).balanceOf(bob);

        // entry was at SQRT_PRICE_1_1; settle at 2x price -> meaningful IL.
        uint160 exit2x = uint160(uint256(SQRT_PRICE_1_1) * 1414213 / 1_000_000); // sqrt(2) factor
        monitor.triggerSettleClaim(pid, exit2x);

        IIndemnifiHook.Policy memory p = hook.getPolicy(pid);
        assertEq(uint8(p.status), uint8(IIndemnifiHook.PolicyStatus.PAID));
        assertGt(IERC20(reserve).balanceOf(bob), bobBefore, "bob should receive payout");
    }

    function test_settleClaim_expiredPolicy_marksExpired() public {
        vm.prank(bob);
        uint256 pid = hook.createPolicy(poolKey, 10_000e18, 500, 1_000e18, block.timestamp + 1);
        vm.warp(block.timestamp + 100);

        uint160 exit2x = uint160(uint256(SQRT_PRICE_1_1) * 1414213 / 1_000_000);
        monitor.triggerSettleClaim(pid, exit2x);
        assertEq(uint8(hook.getPolicy(pid).status), uint8(IIndemnifiHook.PolicyStatus.EXPIRED));
    }

    function test_settleClaim_unknownPolicy_reverts() public {
        vm.expectRevert(IndemnifiHook.PolicyNotFound.selector);
        monitor.triggerSettleClaim(999, SQRT_PRICE_1_1);
    }

    function test_settleClaim_unauthorized_reverts() public {
        vm.prank(bob);
        uint256 pid = hook.createPolicy(poolKey, 10_000e18, 500, 1_000e18, 0);
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(IndemnifiHook.Unauthorized.selector);
        hook.settleClaim(pid, SQRT_PRICE_1_1);
    }

    // ── Risk tier + pause/resume ─────────────────────────────────────────────

    function test_updateRiskTier_changesPremium() public {
        assertEq(hook.getCurrentPremiumBps(poolId), Constants.CALM_PREMIUM_BPS);
        monitor.triggerUpdateRiskTier(poolId, IIndemnifiHook.RiskTier.VOLATILE);
        assertEq(hook.getCurrentPremiumBps(poolId), Constants.VOLATILE_PREMIUM_BPS);
        assertEq(uint8(hook.getRiskTier(poolId)), uint8(IIndemnifiHook.RiskTier.VOLATILE));
        monitor.triggerUpdateRiskTier(poolId, IIndemnifiHook.RiskTier.SHOCK);
        assertEq(hook.getCurrentPremiumBps(poolId), Constants.SHOCK_PREMIUM_BPS);
    }

    function test_updateRiskTier_sameTier_noop() public {
        monitor.triggerUpdateRiskTier(poolId, IIndemnifiHook.RiskTier.CALM);
        assertEq(hook.getCurrentPremiumBps(poolId), Constants.CALM_PREMIUM_BPS);
    }

    function test_pauseResume_gatesCreation() public {
        monitor.triggerPauseCoverage(poolId);
        assertTrue(hook.isCoveragePaused(poolId));

        vm.prank(bob);
        vm.expectRevert(IndemnifiHook.CoveragePausedForPool.selector);
        hook.createPolicy(poolKey, 10_000e18, 500, 1_000e18, 0);

        // No premiums => solvency 100% => resume allowed.
        monitor.triggerResumeCoverage(poolId);
        assertFalse(hook.isCoveragePaused(poolId));

        vm.prank(bob);
        hook.createPolicy(poolKey, 10_000e18, 500, 1_000e18, 0);
    }

    function test_getPremiumForNotional_matchesRate() public view {
        uint256 q = hook.getPremiumForNotional(poolId, 10_000e18);
        assertEq(q, 10_000e18 * Constants.CALM_PREMIUM_BPS / 10_000);
    }
}
