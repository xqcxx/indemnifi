// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20 as SolmateMockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {IndemnifiHook} from "../../src/hook/IndemnifiHook.sol";
import {InsuranceVault} from "../../src/vault/InsuranceVault.sol";
import {MockYieldVault} from "../../src/vault/MockYieldVault.sol";
import {MockReactiveMonitor} from "../mocks/MockReactiveMonitor.sol";
import {IIndemnifiHook} from "../../src/interfaces/IIndemnifiHook.sol";
import {Constants} from "../../src/libraries/Constants.sol";
import {ILMath} from "../../src/libraries/ILMath.sol";

// Exercises the Reactive callback paths locally (no fork). MockReactiveMonitor
// impersonates the callback proxy. Focuses on settlement math correctness and
// the risk/solvency edge cases (caps, calm no-payout, auto-pause, resume gate).
contract ReactiveCallbackTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    uint160 constant FLAGS = uint160(Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG);

    MockYieldVault      yieldVault;
    InsuranceVault      vault;
    IndemnifiHook       hook;
    MockReactiveMonitor monitor;
    address reserve;

    PoolKey poolKey;
    bytes32 poolId;
    address bob = makeAddr("bob");

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();
        reserve = Currency.unwrap(currency0);

        yieldVault = new MockYieldVault(IERC20(reserve), address(this));
        vault      = new InsuranceVault(address(this), IERC20(reserve), yieldVault);

        address hookAddr = address(uint160(FLAGS));
        deployCodeTo("IndemnifiHook.sol:IndemnifiHook", abi.encode(manager, vault, address(this)), hookAddr);
        hook = IndemnifiHook(hookAddr);

        monitor = new MockReactiveMonitor(hook);
        vault.setHook(address(hook));
        hook.setCallbackProxy(address(monitor));

        (poolKey,) = initPoolAndAddLiquidity(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
        poolId = PoolId.unwrap(poolKey.toId());

        // Fund bob and a deep vault so payouts are not vault-limited.
        SolmateMockERC20(reserve).mint(bob, 1_000_000e18);
        vm.prank(bob);
        IERC20(reserve).approve(address(hook), type(uint256).max);

        SolmateMockERC20(reserve).mint(address(this), 100_000e18);
        IERC20(reserve).approve(address(vault), type(uint256).max);
        vault.accrueYield(50_000e18);
    }

    function _buyPolicy(uint256 notional, uint256 thresholdBps, uint256 maxPayout) internal returns (uint256) {
        vm.prank(bob);
        return hook.createPolicy(poolKey, notional, thresholdBps, maxPayout, 0);
    }

    // sqrt(2)x move from 1:1 entry -> ~5.72% IL.
    function _exit2x() internal pure returns (uint160) {
        return uint160(uint256(SQRT_PRICE_1_1) * 1414213 / 1_000_000);
    }

    // ── Settlement math ──────────────────────────────────────────────────────

    function test_settle_paysExactComputedAmount() public {
        uint256 pid = _buyPolicy(10_000e18, 500, 1_000e18);
        IIndemnifiHook.Policy memory p = hook.getPolicy(pid);

        uint160 exit = _exit2x();
        uint256 ilBps    = ILMath.calculateILBps(p.entryPrice, exit);
        uint256 ilAmount = ILMath.calculateILAmount(ilBps, p.notional);
        (,, uint256 expected) =
            ILMath.calculatePayout(ilAmount, p.thresholdBps, p.notional, p.maxPayout, vault.availableForClaims());

        uint256 before = IERC20(reserve).balanceOf(bob);
        monitor.triggerSettleClaim(pid, exit);

        assertEq(IERC20(reserve).balanceOf(bob) - before, expected);
        assertEq(uint8(hook.getPolicy(pid).status), uint8(IIndemnifiHook.PolicyStatus.PAID));
    }

    function test_settle_belowDeductible_noPayout() public {
        uint256 pid = _buyPolicy(10_000e18, 500, 1_000e18);
        uint160 calmExit = uint160(uint256(SQRT_PRICE_1_1) * 101 / 100); // +1% -> IL << 5%

        uint256 before = IERC20(reserve).balanceOf(bob);
        monitor.triggerSettleClaim(pid, calmExit);

        assertEq(IERC20(reserve).balanceOf(bob), before);
        assertEq(uint8(hook.getPolicy(pid).status), uint8(IIndemnifiHook.PolicyStatus.PAID));
    }

    function test_settle_cappedByMaxPayout() public {
        // Big move, tiny cap.
        uint256 pid = _buyPolicy(10_000e18, 500, 50e18);
        uint160 exit = uint160(uint256(SQRT_PRICE_1_1) * 2); // 4x price -> large IL

        uint256 before = IERC20(reserve).balanceOf(bob);
        monitor.triggerSettleClaim(pid, exit);
        assertEq(IERC20(reserve).balanceOf(bob) - before, 50e18);
    }

    function test_settle_cappedByVaultAvailable() public {
        // Drain the vault first via a separate large claim, leaving little.
        // Easier: deploy a shallow vault scenario by paying down.
        uint256 pid = _buyPolicy(1_000_000e18, 100, type(uint128).max); // huge notional, low deductible
        uint160 exit = uint160(uint256(SQRT_PRICE_1_1) * 2);

        uint256 avail = vault.availableForClaims();
        uint256 before = IERC20(reserve).balanceOf(bob);
        monitor.triggerSettleClaim(pid, exit);
        // Payout cannot exceed what the vault had available.
        assertLe(IERC20(reserve).balanceOf(bob) - before, avail);
    }

    // ── Risk / solvency edge cases ───────────────────────────────────────────

    function test_updateRiskTier_volatile_raisesPremium() public {
        monitor.triggerUpdateRiskTier(poolId, IIndemnifiHook.RiskTier.VOLATILE);
        assertEq(hook.getCurrentPremiumBps(poolId), Constants.VOLATILE_PREMIUM_BPS);
    }

    function test_shockWithLowSolvency_autoPauses() public {
        // Create a low-solvency situation: many premiums, then pay a big claim.
        uint256 pid = _buyPolicy(1_000_000e18, 100, type(uint128).max);
        monitor.triggerSettleClaim(pid, uint160(uint256(SQRT_PRICE_1_1) * 2));
        // After a big payout, solvency drops; a SHOCK update should auto-pause.
        if (vault.solvencyRatioBps() < Constants.SOLVENCY_PAUSE_BPS) {
            monitor.triggerUpdateRiskTier(poolId, IIndemnifiHook.RiskTier.SHOCK);
            assertTrue(hook.isCoveragePaused(poolId));
        }
    }

    function test_resume_revertsWhenSolvencyTooLow() public {
        // Force low solvency, pause, then resume should revert.
        uint256 pid = _buyPolicy(1_000_000e18, 100, type(uint128).max);
        monitor.triggerSettleClaim(pid, uint160(uint256(SQRT_PRICE_1_1) * 2));
        monitor.triggerPauseCoverage(poolId);

        if (vault.solvencyRatioBps() < Constants.SOLVENCY_RESUME_BPS) {
            vm.expectRevert(bytes("vault not recovered"));
            monitor.triggerResumeCoverage(poolId);
        }
    }

    function test_pause_blocksCreation_thenResumeAllows() public {
        monitor.triggerPauseCoverage(poolId);
        vm.prank(bob);
        vm.expectRevert(IndemnifiHook.CoveragePausedForPool.selector);
        hook.createPolicy(poolKey, 10_000e18, 500, 1_000e18, 0);

        monitor.triggerResumeCoverage(poolId);
        vm.prank(bob);
        hook.createPolicy(poolKey, 10_000e18, 500, 1_000e18, 0);
    }
}
