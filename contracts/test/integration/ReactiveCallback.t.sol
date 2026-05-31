// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

import {IndemnifiHook} from "../../src/hook/IndemnifiHook.sol";
import {InsuranceVault} from "../../src/vault/InsuranceVault.sol";
import {MockYieldVault} from "../../src/vault/MockYieldVault.sol";
import {MockReactiveMonitor} from "../mocks/MockReactiveMonitor.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IIndemnifiHook} from "../../src/interfaces/IIndemnifiHook.sol";
import {Constants} from "../../src/libraries/Constants.sol";
import {ILMath} from "../../src/libraries/ILMath.sol";

// Tests the Reactive callback paths without Reactive Network.
// MockReactiveMonitor impersonates the callback proxy, verifying that:
//   - settleClaim() correctly computes IL and pays from vault
//   - updateRiskTier() updates premium rates
//   - pauseCoverage() / resumeCoverage() gate policy creation
//   - Unauthorized callers are rejected
//
// Requires Unichain Sepolia fork for hook deployment.
contract ReactiveCallbackTest is Test {
    using SafeERC20 for IERC20;
    using PoolIdLibrary for PoolKey;

    address constant POOL_MANAGER_ADDR = 0x7c13D90950F542B297179e09f3A36EaA917A40C1;

    uint160 constant PRICE_2000 = 3543191142285914327220224;
    uint160 constant PRICE_2800 = 5010828967500958937382912;
    uint160 constant PRICE_4000 = 7086382284571828654440448;

    uint160 constant FLAGS = uint160(
        Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG
    );

    IPoolManager   poolManager;
    MockERC20      usdc;
    MockERC20      weth;
    MockYieldVault yieldVault;
    InsuranceVault vault;
    IndemnifiHook  hook;
    MockReactiveMonitor monitor;
    PoolKey        poolKey;

    address owner = address(this);
    address bob   = makeAddr("bob");

    bool forked;

    function setUp() public {
        forked = block.chainid == 1301;

        usdc       = new MockERC20("Mock USDC", "mUSDC", 6);
        weth       = new MockERC20("WETH", "WETH", 18);
        yieldVault = new MockYieldVault(IERC20(address(usdc)), owner);
        vault      = new InsuranceVault(owner, IERC20(address(usdc)), yieldVault);

        if (!forked) return;

        poolManager = IPoolManager(POOL_MANAGER_ADDR);

        address hookAddr = address(uint160(FLAGS));
        deployCodeTo(
            "IndemnifiHook.sol:IndemnifiHook",
            abi.encode(poolManager, vault, owner),
            hookAddr
        );
        hook    = IndemnifiHook(hookAddr);
        monitor = new MockReactiveMonitor(hook);

        vault.setHook(address(hook));
        hook.setCallbackProxy(address(monitor));

        (address t0, address t1) = address(weth) < address(usdc)
            ? (address(weth), address(usdc))
            : (address(usdc), address(weth));

        poolKey = PoolKey({
            currency0:   Currency.wrap(t0),
            currency1:   Currency.wrap(t1),
            fee:         3000,
            tickSpacing: 60,
            hooks:       IHooks(address(hook))
        });

        poolManager.initialize(poolKey, PRICE_2000);

        // Seed vault so claims can be paid
        usdc.mint(owner, 50_000e6);
        usdc.approve(address(vault), 50_000e6);
        // Simulate premium via direct deposit (owner has hook role here for seeding)
        vault.setHook(owner);
        IERC20(address(usdc)).safeTransfer(address(vault), 10_000e6);
        vault.depositPremium(address(usdc), 10_000e6);
        vault.setHook(address(hook));

        usdc.mint(bob, 10_000e6);
        vm.prank(bob); usdc.approve(address(hook), type(uint256).max);
    }

    // ── settleClaim ───────────────────────────────────────────────────────

    function test_settleClaimVolatile_paysCorrectAmount() public {
        if (!forked) return;

        vm.prank(bob);
        uint256 pid = hook.createPolicy(poolKey, 10_000e6, 500, 1_000e6, 0);

        IIndemnifiHook.Policy memory p = hook.getPolicy(pid);

        uint256 ilBps   = ILMath.calculateILBps(p.entryPrice, PRICE_2800);
        uint256 ilAmount = ILMath.calculateILAmount(ilBps, p.notional);
        (,, uint256 expected) = ILMath.calculatePayout(
            ilAmount, p.thresholdBps, p.notional, p.maxPayout, vault.availableForClaims()
        );

        uint256 bobBefore = usdc.balanceOf(bob);
        monitor.triggerSettleClaim(pid, PRICE_2800);

        assertEq(usdc.balanceOf(bob) - bobBefore, expected);
        assertEq(uint8(hook.getPolicy(pid).status), uint8(IIndemnifiHook.PolicyStatus.PAID));
    }

    function test_settleClaimCalm_noPayment() public {
        if (!forked) return;

        // Use a price very close to entry so IL < threshold
        uint160 calmExit = uint160(uint256(PRICE_2000) * 102 / 100); // +2%

        vm.prank(bob);
        uint256 pid = hook.createPolicy(poolKey, 10_000e6, 500, 1_000e6, 0);

        uint256 bobBefore = usdc.balanceOf(bob);
        monitor.triggerSettleClaim(pid, calmExit);

        // No payout for small IL
        assertEq(usdc.balanceOf(bob), bobBefore);
        assertEq(uint8(hook.getPolicy(pid).status), uint8(IIndemnifiHook.PolicyStatus.PAID));
    }

    function test_settleClaimUnauthorized_reverts() public {
        if (!forked) return;

        vm.prank(bob);
        uint256 pid = hook.createPolicy(poolKey, 10_000e6, 500, 1_000e6, 0);

        vm.prank(makeAddr("stranger"));
        vm.expectRevert(IndemnifiHook.Unauthorized.selector);
        hook.settleClaim(pid, PRICE_2800);
    }

    // ── Risk tier updates ─────────────────────────────────────────────────

    function test_updateRiskTier_volatile_raisesPremium() public {
        if (!forked) return;

        bytes32 pid = PoolId.unwrap(poolKey.toId());
        monitor.triggerUpdateRiskTier(pid, IIndemnifiHook.RiskTier.VOLATILE);
        assertEq(hook.getCurrentPremiumBps(pid), Constants.VOLATILE_PREMIUM_BPS);
    }

    function test_updateRiskTier_calm_noPremiumChange() public {
        if (!forked) return;

        bytes32 pid = PoolId.unwrap(poolKey.toId());
        // Already calm — should be a no-op
        monitor.triggerUpdateRiskTier(pid, IIndemnifiHook.RiskTier.CALM);
        assertEq(hook.getCurrentPremiumBps(pid), Constants.CALM_PREMIUM_BPS);
    }

    // ── Pause / resume ────────────────────────────────────────────────────

    function test_pauseAndResume_controlsPolicyCreation() public {
        if (!forked) return;

        bytes32 pid = PoolId.unwrap(poolKey.toId());
        monitor.triggerPauseCoverage(pid);

        vm.prank(bob);
        vm.expectRevert(IndemnifiHook.CoveragePausedForPool.selector);
        hook.createPolicy(poolKey, 10_000e6, 500, 1_000e6, 0);

        monitor.triggerResumeCoverage(pid);
        // Should now succeed
        vm.prank(bob);
        hook.createPolicy(poolKey, 10_000e6, 500, 1_000e6, 0);
    }
}
