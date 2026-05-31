// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {InsuranceVault} from "../../src/vault/InsuranceVault.sol";
import {MockYieldVault} from "../../src/vault/MockYieldVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract InsuranceVaultTest is Test {
    using SafeERC20 for IERC20;
    InsuranceVault vault;
    MockYieldVault yieldVault;
    MockERC20 usdc;

    address owner  = address(this);
    address hook   = makeAddr("hook");
    address alice  = makeAddr("alice");

    function setUp() public {
        usdc       = new MockERC20("Mock USDC", "mUSDC", 6);
        yieldVault = new MockYieldVault(IERC20(address(usdc)), owner);
        vault      = new InsuranceVault(owner, IERC20(address(usdc)), yieldVault);
        vault.setHook(hook);

        usdc.mint(owner, 1_000_000e6);
        usdc.mint(hook,  1_000_000e6);

        vm.prank(hook);
        usdc.approve(address(vault), type(uint256).max);
    }

    function _depositPremium(uint256 amount) internal {
        // Tokens must be in vault before depositPremium() is called
        // (same as the hook pattern: hook transfers, then calls depositPremium).
        vm.startPrank(hook);
        IERC20(address(usdc)).safeTransfer(address(vault), amount);
        vault.depositPremium(address(usdc), amount);
        vm.stopPrank();
    }

    function test_depositPremium_updatesTotals() public {
        _depositPremium(1_000e6);
        assertEq(vault.totalPremiums(), 1_000e6);
    }

    function test_depositPremium_splitsLiquidAndYield() public {
        _depositPremium(1_000e6);
        // 20% liquid = 200e6, 80% in yield vault
        assertEq(vault.liquidReserve(), 200e6);
        assertEq(yieldVault.maxWithdraw(address(vault)), 800e6);
    }

    function test_depositPremium_onlyHook() public {
        IERC20(address(usdc)).safeTransfer(address(vault), 100e6);
        vm.prank(alice);
        vm.expectRevert(InsuranceVault.OnlyHook.selector);
        vault.depositPremium(address(usdc), 100e6);
    }

    function test_depositPremium_unsupportedToken() public {
        MockERC20 other = new MockERC20("Other", "OTH", 18);
        other.mint(hook, 1_000e18);
        vm.startPrank(hook);
        IERC20(address(other)).safeTransfer(address(vault), 100e18);
        vm.expectRevert(InsuranceVault.UnsupportedToken.selector);
        vault.depositPremium(address(other), 100e18);
        vm.stopPrank();
    }

    function test_payClaim_transfersToRecipient() public {
        _depositPremium(2_000e6);
        uint256 before = usdc.balanceOf(alice);

        vm.prank(hook);
        vault.payClaim(alice, address(usdc), 500e6);

        assertEq(usdc.balanceOf(alice) - before, 500e6);
        assertEq(vault.totalClaimsPaid(), 500e6);
    }

    function test_payClaim_revertsIfInsufficient() public {
        vm.prank(hook);
        vm.expectRevert(InsuranceVault.InsufficientReserves.selector);
        vault.payClaim(alice, address(usdc), 1e6);
    }

    function test_payClaim_drainsLiquidFirst() public {
        _depositPremium(1_000e6); // 200e6 liquid, 800e6 in yield

        vm.prank(hook);
        vault.payClaim(alice, address(usdc), 150e6); // within liquid

        assertEq(vault.liquidReserve(), 50e6);
        assertEq(yieldVault.maxWithdraw(address(vault)), 800e6); // yield untouched
    }

    function test_payClaim_redeemFromYieldWhenLiquidInsufficient() public {
        _depositPremium(1_000e6); // 200e6 liquid

        vm.prank(hook);
        vault.payClaim(alice, address(usdc), 600e6); // > liquid

        assertEq(vault.liquidReserve(), 0);
        // 400e6 should remain in yield vault (800 - 400)
        assertEq(yieldVault.maxWithdraw(address(vault)), 400e6);
    }

    function test_accrueYield_increasesBalance() public {
        _depositPremium(1_000e6);
        uint256 before = vault.totalAssets();

        usdc.approve(address(vault), 100e6);
        vault.accrueYield(100e6);

        assertGt(vault.totalAssets(), before);
        assertEq(vault.totalYieldEarned(), 100e6);
    }

    function test_solvencyRatio_initiallyFull() public {
        _depositPremium(1_000e6);
        assertEq(vault.solvencyRatioBps(), 10_000);
    }

    function test_solvencyRatio_dropsAfterClaim() public {
        _depositPremium(1_000e6);
        vm.prank(hook);
        vault.payClaim(alice, address(usdc), 200e6);

        // ~800/1000 = 8000 bps (exact depends on yield vault rounding)
        assertApproxEqAbs(vault.solvencyRatioBps(), 8_000, 100);
    }

    function test_rebalance_movesExcessLiquidToYield() public {
        _depositPremium(1_000e6); // 200 liquid, 800 yield
        // Force excess liquid by direct transfer
        usdc.mint(address(vault), 2_000e6);
        vm.store(address(vault), keccak256("liquidReserve"), bytes32(uint256(2_200e6)));

        vault.rebalance();
        // After rebalance, liquid should be closer to 20% target
        uint256 total = vault.totalAssets();
        uint256 target = total * 2000 / 10_000;
        assertApproxEqAbs(vault.liquidReserve(), target, target / 10);
    }
}
