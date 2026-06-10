// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockYieldVault} from "../../src/vault/MockYieldVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

// Unit tests for the ERC4626 demo yield vault.
contract MockYieldVaultTest is Test {
    MockYieldVault vault;
    MockERC20      asset;

    address depositor = makeAddr("depositor");

    function setUp() public {
        asset = new MockERC20("USDC", "USDC", 6);
        vault = new MockYieldVault(IERC20(address(asset)), address(this));

        asset.mint(depositor, 1_000_000e6);
        vm.prank(depositor);
        asset.approve(address(vault), type(uint256).max);

        asset.mint(address(this), 1_000_000e6);
        asset.approve(address(vault), type(uint256).max);
    }

    function test_metadata() public view {
        assertEq(vault.name(), "Indemnifi Yield Shares");
        assertEq(vault.symbol(), "idyV");
        assertEq(vault.asset(), address(asset));
    }

    function test_deposit_mintsSharesAndTracksAssets() public {
        vm.prank(depositor);
        uint256 shares = vault.deposit(100e6, depositor);
        assertEq(vault.totalAssets(), 100e6);
        assertEq(vault.balanceOf(depositor), shares);
        assertGt(shares, 0);
    }

    function test_withdraw_burnsSharesAndReturnsAssets() public {
        vm.startPrank(depositor);
        vault.deposit(100e6, depositor);
        uint256 before = asset.balanceOf(depositor);
        vault.withdraw(40e6, depositor, depositor);
        vm.stopPrank();

        assertEq(asset.balanceOf(depositor) - before, 40e6);
        assertEq(vault.totalAssets(), 60e6);
    }

    function test_withdraw_thirdParty_spendsAllowance() public {
        vm.prank(depositor);
        vault.deposit(100e6, depositor);

        address spender = makeAddr("spender");
        vm.prank(depositor);
        vault.approve(spender, type(uint256).max);

        vm.prank(spender);
        vault.withdraw(50e6, spender, depositor);
        assertEq(asset.balanceOf(spender), 50e6);
        assertEq(vault.totalAssets(), 50e6);
    }

    function test_accrueYield_increasesAssetsOnly() public {
        vm.prank(depositor);
        uint256 shares = vault.deposit(100e6, depositor);

        // owner (this) accrues yield -> assets up, shares unchanged.
        vault.accrueYield(20e6);
        assertEq(vault.totalAssets(), 120e6);
        assertEq(vault.balanceOf(depositor), shares);

        // Each share is now worth more: redeeming all shares returns ~120.
        assertApproxEqAbs(vault.maxWithdraw(depositor), 120e6, 1);
    }

    function test_accrueYield_onlyOwner() public {
        vm.prank(depositor);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, depositor));
        vault.accrueYield(10e6);
    }

    function test_yieldRaisesExistingDepositorValue() public {
        // Two depositors split yield pro-rata.
        vm.prank(depositor);
        vault.deposit(100e6, depositor);

        address d2 = makeAddr("d2");
        asset.mint(d2, 100e6);
        vm.prank(d2);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(d2);
        vault.deposit(100e6, d2);

        vault.accrueYield(40e6); // total assets 240 over 200 deposited

        assertApproxEqAbs(vault.maxWithdraw(depositor), 120e6, 1);
        assertApproxEqAbs(vault.maxWithdraw(d2), 120e6, 1);
    }
}
