// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IndemnifiHook} from "../../src/hook/IndemnifiHook.sol";
import {BaseHook} from "../../src/hook/BaseHook.sol";
import {InsuranceVault} from "../../src/vault/InsuranceVault.sol";
import {MockYieldVault} from "../../src/vault/MockYieldVault.sol";

// Verifies the BaseHook scaffolding: unimplemented callbacks revert with
// HookNotImplemented, and onlyPoolManager gating is enforced.
contract BaseHookTest is Test, Deployers {
    uint160 constant FLAGS = uint160(Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG);

    IndemnifiHook hook;
    PoolKey emptyKey;

    function setUp() public {
        deployFreshManagerAndRouters();
        MockYieldVault yv = new MockYieldVault(IERC20(address(0xdEaD)), address(this));
        // dummy asset only to construct; not used by these tests.
        InsuranceVault vault = new InsuranceVault(address(this), IERC20(address(0xdEaD)), yv);

        address hookAddr = address(uint160(FLAGS));
        deployCodeTo("IndemnifiHook.sol:IndemnifiHook", abi.encode(manager, vault, address(this)), hookAddr);
        hook = IndemnifiHook(hookAddr);
    }

    function test_beforeInitialize_revertsNotImplemented() public {
        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.beforeInitialize(address(0), emptyKey, 0);
    }

    function test_afterInitialize_revertsNotImplemented() public {
        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.afterInitialize(address(0), emptyKey, 0, 0);
    }

    function test_beforeAddLiquidity_revertsNotImplemented() public {
        IPoolManager.ModifyLiquidityParams memory p;
        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.beforeAddLiquidity(address(0), emptyKey, p, "");
    }

    function test_afterAddLiquidity_revertsNotImplemented() public {
        IPoolManager.ModifyLiquidityParams memory p;
        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.afterAddLiquidity(address(0), emptyKey, p, BalanceDelta.wrap(0), BalanceDelta.wrap(0), "");
    }

    function test_beforeRemoveLiquidity_revertsNotImplemented() public {
        IPoolManager.ModifyLiquidityParams memory p;
        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.beforeRemoveLiquidity(address(0), emptyKey, p, "");
    }

    function test_beforeSwap_revertsNotImplemented() public {
        IPoolManager.SwapParams memory p;
        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.beforeSwap(address(0), emptyKey, p, "");
    }

    function test_beforeDonate_revertsNotImplemented() public {
        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.beforeDonate(address(0), emptyKey, 0, 0, "");
    }

    function test_afterDonate_revertsNotImplemented() public {
        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.afterDonate(address(0), emptyKey, 0, 0, "");
    }

    function test_afterSwap_onlyPoolManager() public {
        IPoolManager.SwapParams memory p;
        vm.expectRevert(BaseHook.NotPoolManager.selector);
        hook.afterSwap(address(0), emptyKey, p, BalanceDelta.wrap(0), "");
    }

    function test_afterRemoveLiquidity_onlyPoolManager() public {
        IPoolManager.ModifyLiquidityParams memory p;
        vm.expectRevert(BaseHook.NotPoolManager.selector);
        hook.afterRemoveLiquidity(address(0), emptyKey, p, BalanceDelta.wrap(0), BalanceDelta.wrap(0), "");
    }

    function test_unlockCallback_onlyPoolManager() public {
        vm.expectRevert(BaseHook.NotPoolManager.selector);
        hook.unlockCallback("");
    }

    function test_poolManager_set() public view {
        assertEq(address(hook.poolManager()), address(manager));
    }
}
