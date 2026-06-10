// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IndemnifiHook} from "../src/hook/IndemnifiHook.sol";
import {Constants} from "../src/libraries/Constants.sol";

// Authorizes the Reactive callback proxy on the hook. Run on Unichain Sepolia
// after deploying the RSC on Lasna. Override the proxy with CALLBACK_PROXY env.
contract SetCallbackProxy is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        address hook = vm.envAddress("HOOK_ADDRESS");
        address proxy = vm.envOr("CALLBACK_PROXY", Constants.CALLBACK_PROXY_ADDRESS);

        vm.startBroadcast(key);
        IndemnifiHook(hook).setCallbackProxy(proxy);
        vm.stopBroadcast();

        console2.log("callbackProxy set on", hook);
        console2.log("proxy =", proxy);
    }
}
