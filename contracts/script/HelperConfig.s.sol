// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../src/libraries/Constants.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address poolManager;
        address callbackProxy;
        uint256 chainId;
    }

    // Unichain Sepolia PoolManager — deployed by Uniswap.
    address public constant UNICHAIN_POOL_MANAGER = 0x7c13D90950F542B297179e09f3A36EaA917A40C1;

    function getConfig() external view returns (NetworkConfig memory) {
        if (block.chainid == Constants.UNICHAIN_CHAIN_ID) {
            return NetworkConfig({
                poolManager:   UNICHAIN_POOL_MANAGER,
                callbackProxy: Constants.CALLBACK_PROXY_ADDRESS,
                chainId:       Constants.UNICHAIN_CHAIN_ID
            });
        }
        // Anvil fallback — caller overrides via env.
        return NetworkConfig({
            poolManager:   vm.envOr("POOL_MANAGER_ADDRESS", address(0)),
            callbackProxy: address(0),
            chainId:       block.chainid
        });
    }
}
