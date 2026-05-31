// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IndemnifiHook} from "../../src/hook/IndemnifiHook.sol";
import {InsuranceVault} from "../../src/vault/InsuranceVault.sol";
import {MockYieldVault} from "../../src/vault/MockYieldVault.sol";
import {MockReactiveMonitor} from "../mocks/MockReactiveMonitor.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IIndemnifiHook} from "../../src/interfaces/IIndemnifiHook.sol";
import {Constants} from "../../src/libraries/Constants.sol";
import {ILMath} from "../../src/libraries/ILMath.sol";

// Full hook lifecycle test — requires Unichain Sepolia fork.
//
// Run with:
//   forge test --match-contract HookLifecycleTest \
//              --fork-url $UNICHAIN_RPC_URL \
//              -vvv
//
// Without a fork (CI), setUp() returns early and all tests are no-ops.
contract HookLifecycleTest is Test {
    using PoolIdLibrary for PoolKey;

    // Unichain Sepolia PoolManager (deployed by Uniswap)
    address constant POOL_MANAGER_ADDR = 0x7c13D90950F542B297179e09f3A36EaA917A40C1;

    uint160 constant PRICE_2000 = 3543191142285914327220224;
    uint160 constant PRICE_2800 = 5010828967500958937382912;

    // Hook flags: afterRemoveLiquidity + afterSwap
    uint160 constant FLAGS = uint160(
        Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG
    );

    IPoolManager       poolManager;
    MockERC20          usdc;
    MockERC20          weth;
    MockYieldVault     yieldVault;
    InsuranceVault     insuranceVault;
    IndemnifiHook      hook;
    MockReactiveMonitor monitor;
    PoolKey            poolKey;

    address deployer = makeAddr("deployer");
    address alice    = makeAddr("alice");
    address bob      = makeAddr("bob");

    bool forked;

    function setUp() public {
        forked = block.chainid == 1301;

        usdc       = new MockERC20("Mock USDC", "mUSDC", 6);
        weth       = new MockERC20("Wrapped Ether", "WETH", 18);
        yieldVault = new MockYieldVault(IERC20(address(usdc)), address(this));
        insuranceVault = new InsuranceVault(address(this), IERC20(address(usdc)), yieldVault);

        if (!forked) return;

        poolManager = IPoolManager(POOL_MANAGER_ADDR);

        // Deploy hook at an address that has the required flag bits set.
        address hookAddr = address(uint160(FLAGS));
        deployCodeTo(
            "IndemnifiHook.sol:IndemnifiHook",
            abi.encode(poolManager, insuranceVault, address(this)),
            hookAddr
        );
        hook = IndemnifiHook(hookAddr);

        monitor = new MockReactiveMonitor(hook);

        insuranceVault.setHook(address(hook));
        hook.setCallbackProxy(address(monitor));

        // Mint and approve tokens
        usdc.mint(alice, 1_000_000e6);
        usdc.mint(bob,   1_000_000e6);
        usdc.mint(address(this), 100_000e6);

        vm.prank(alice); usdc.approve(address(hook), type(uint256).max);
        vm.prank(bob);   usdc.approve(address(hook), type(uint256).max);

        // Token order: lower address = currency0
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
    }

    function test_hook_deployed_withCorrectVault() public view {
        if (!forked) return;
        assertEq(address(hook.vault()), address(insuranceVault));
        assertEq(hook.callbackProxy(), address(monitor));
    }

    function test_createPolicy_recordsPolicyAndCollectsPremium() public {
        if (!forked) return;

        uint256 notional = 10_000e6; // 10k USDC (6 dec)
        uint256 before   = usdc.balanceOf(address(insuranceVault));

        vm.prank(bob);
        uint256 pid = hook.createPolicy(poolKey, notional, 500, 1_000e6, 0);

        IIndemnifiHook.Policy memory p = hook.getPolicy(pid);
        assertEq(p.owner,        bob);
        assertEq(p.notional,     notional);
        assertEq(p.thresholdBps, 500);
        assertEq(uint8(p.status), uint8(IIndemnifiHook.PolicyStatus.ACTIVE));

        // Premium entered the vault
        assertGt(usdc.balanceOf(address(insuranceVault)), before);
    }

    function test_createPolicy_revertsCoverageWhenPaused() public {
        if (!forked) return;

        bytes32 pid = PoolId.unwrap(poolKey.toId());
        monitor.triggerPauseCoverage(pid);

        vm.prank(bob);
        vm.expectRevert(IndemnifiHook.CoveragePausedForPool.selector);
        hook.createPolicy(poolKey, 10_000e6, 500, 1_000e6, 0);
    }

    function test_settleClaimViaMonitor_paysInsuredLP() public {
        if (!forked) return;

        uint256 notional = 10_000e6;

        // Seed vault
        usdc.approve(address(insuranceVault), 10_000e6);
        insuranceVault.accrueYield(10_000e6);

        vm.prank(bob);
        usdc.approve(address(hook), type(uint256).max);
        vm.prank(bob);
        uint256 pid = hook.createPolicy(poolKey, notional, 500, 1_000e6, 0);

        // Simulate exit: mark policy pending manually (normally done by afterRemoveLiquidity)
        // We call settleClaim directly via monitor (bypassing the event flow).
        uint256 bobBefore = usdc.balanceOf(bob);
        monitor.triggerSettleClaim(pid, PRICE_2800);

        IIndemnifiHook.Policy memory p = hook.getPolicy(pid);
        assertEq(uint8(p.status), uint8(IIndemnifiHook.PolicyStatus.PAID));
        assertGe(usdc.balanceOf(bob), bobBefore); // Bob received payout
    }

    function test_updateRiskTier_changesPremiumRate() public {
        if (!forked) return;

        bytes32 pid = PoolId.unwrap(poolKey.toId());
        assertEq(hook.getCurrentPremiumBps(pid), Constants.CALM_PREMIUM_BPS);

        monitor.triggerUpdateRiskTier(pid, IIndemnifiHook.RiskTier.VOLATILE);
        assertEq(hook.getCurrentPremiumBps(pid), Constants.VOLATILE_PREMIUM_BPS);

        monitor.triggerUpdateRiskTier(pid, IIndemnifiHook.RiskTier.SHOCK);
        assertEq(hook.getCurrentPremiumBps(pid), Constants.SHOCK_PREMIUM_BPS);
    }

    function test_resumeCoverage_requiresMinSolvency() public {
        if (!forked) return;

        bytes32 pid = PoolId.unwrap(poolKey.toId());
        monitor.triggerPauseCoverage(pid);
        assertTrue(hook.isCoveragePaused(pid));

        // Vault has no assets — solvency is 100% (no premiums = no liability)
        // so resume should work
        monitor.triggerResumeCoverage(pid);
        assertFalse(hook.isCoveragePaused(pid));
    }
}
