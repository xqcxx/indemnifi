// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockYieldVault} from "../src/vault/MockYieldVault.sol";
import {InsuranceVault} from "../src/vault/InsuranceVault.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

// Deploys the shared infrastructure on Unichain Sepolia.
// Run this first, then run DeployHook.s.sol with the vault address.
//
// Usage:
//   forge script script/DeployAll.s.sol \
//     --rpc-url $UNICHAIN_RPC_URL \
//     --private-key $PRIVATE_KEY \
//     --broadcast --verify -vvv
contract DeployAll is Script {
    function run() external {
        uint256 key     = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(key);

        console2.log("Deployer :", deployer);
        console2.log("Chain ID :", block.chainid);

        vm.startBroadcast(key);

        // Mock reserve token (USDC with 6 decimals).
        MockERC20 usdc = new MockERC20("Mock USDC", "mUSDC", 6);
        usdc.mint(deployer, 10_000_000e6);
        console2.log("mUSDC    :", address(usdc));

        // Mock WETH (for the pool pair).
        MockERC20 weth = new MockERC20("Wrapped Ether", "WETH", 18);
        weth.mint(deployer, 1_000e18);
        console2.log("WETH     :", address(weth));

        // Yield vault backed by USDC.
        MockYieldVault yieldVault = new MockYieldVault(IERC20(address(usdc)), deployer);
        console2.log("YieldVault:", address(yieldVault));

        // Insurance vault.
        InsuranceVault insuranceVault = new InsuranceVault(deployer, IERC20(address(usdc)), yieldVault);
        console2.log("InsuranceVault:", address(insuranceVault));

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== STEP 1 COMPLETE - deploy hook next ===");
        console2.log("POOL_MANAGER_ADDRESS=", address(0x7c13D90950F542B297179e09f3A36EaA917A40C1));
        console2.log("VAULT_ADDRESS       =", address(insuranceVault));
        console2.log("YIELD_VAULT_ADDRESS =", address(yieldVault));
        console2.log("USDC_ADDRESS        =", address(usdc));
        console2.log("WETH_ADDRESS        =", address(weth));
    }
}
