// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ReactiveRiskMonitor} from "../src/reactive/ReactiveRiskMonitor.sol";

// Deploys ReactiveRiskMonitor on Reactive Lasna (chain 5318007).
// Must send ETH to fund subscription gas.
//
// Usage:
//   HOOK_ADDRESS=0x... \
//   VAULT_ADDRESS=0x... \
//   forge script script/DeployReactive.s.sol \
//     --rpc-url $REACTIVE_RPC_URL \
//     --private-key $PRIVATE_KEY \
//     --broadcast -vvv
//
// After deployment, call:
//   IndemnifiHook.setCallbackProxy(<monitor address>)  — on Unichain Sepolia
contract DeployReactive is Script {
    function run() external {
        uint256 key          = vm.envUint("PRIVATE_KEY");
        address hookAddress  = vm.envAddress("HOOK_ADDRESS");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        vm.startBroadcast(key);

        ReactiveRiskMonitor monitor = new ReactiveRiskMonitor{value: 0.1 ether}(
            hookAddress,
            vaultAddress
        );

        console2.log("=== REACTIVE LASNA DEPLOYMENT ===");
        console2.log("ReactiveRiskMonitor:", address(monitor));
        console2.log("Subscribed hook    :", hookAddress);
        console2.log("Subscribed vault   :", vaultAddress);
        console2.log("");
        console2.log("Now authorise the Reactive callback proxy on the hook:");
        console2.log("  IndemnifiHook.setCallbackProxy(CALLBACK_PROXY_ADDRESS)");
        console2.log("  where CALLBACK_PROXY_ADDRESS = 0x9299e9826b4FDEeBdD686Cd08b521664c4A66434");

        vm.stopBroadcast();
    }
}
