// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

import {IndemnifiHook} from "../src/hook/IndemnifiHook.sol";
import {InsuranceVault} from "../src/vault/InsuranceVault.sol";

// Deploys IndemnifiHook via CREATE2 with a mined salt so the deployed
// address encodes the required hook permission bits.
//
// Usage:
//   POOL_MANAGER_ADDRESS=0x7c13... \
//   VAULT_ADDRESS=0x... \
//   forge script script/DeployHook.s.sol \
//     --rpc-url $UNICHAIN_RPC_URL \
//     --private-key $PRIVATE_KEY \
//     --broadcast --verify -vvv
contract DeployHook is Script {
    // Forge deterministic CREATE2 deployer.
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        uint256 key          = vm.envUint("PRIVATE_KEY");
        address deployer     = vm.addr(key);
        address poolManager  = vm.envAddress("POOL_MANAGER_ADDRESS");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        uint160 flags = uint160(
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
            Hooks.AFTER_SWAP_FLAG
        );

        console2.log("Mining hook address for flags:", uint256(flags));

        bytes memory creationCode = abi.encodePacked(
            type(IndemnifiHook).creationCode,
            abi.encode(IPoolManager(poolManager), InsuranceVault(vaultAddress), deployer)
        );

        (address hookAddress, bytes32 salt) = _mine(flags, creationCode);
        console2.log("Hook address:", hookAddress);
        console2.log("Salt        :", uint256(salt));

        vm.startBroadcast(key);

        IndemnifiHook hook = new IndemnifiHook{salt: salt}(
            IPoolManager(poolManager),
            InsuranceVault(vaultAddress),
            deployer
        );

        require(address(hook) == hookAddress, "address mismatch");

        InsuranceVault(vaultAddress).setHook(address(hook));

        console2.log("");
        console2.log("=== HOOK DEPLOYED ===");
        console2.log("IndemnifiHook:", address(hook));
        console2.log("Hook authorised on InsuranceVault");
        console2.log("Next: deploy ReactiveRiskMonitor on Reactive Lasna");
        console2.log("  HOOK_ADDRESS=", address(hook));

        vm.stopBroadcast();
    }

    // Brute-force a CREATE2 salt whose resulting address has the required flags
    // in the lowest 20 bytes (standard v4 hook address mining).
    uint160 constant ALL_HOOK_MASK = uint160((1 << 14) - 1);

    function _mine(uint160 flags, bytes memory creationCode)
        internal pure returns (address hookAddr, bytes32 salt)
    {
        bytes32 initHash = keccak256(creationCode);
        for (uint256 i = 0; i < 500_000; i++) {
            salt    = bytes32(i);
            hookAddr = address(uint160(uint256(keccak256(abi.encodePacked(
                bytes1(0xff),
                CREATE2_DEPLOYER,
                salt,
                initHash
            )))));
            if (uint160(hookAddr) & ALL_HOOK_MASK == flags) return (hookAddr, salt);
        }
        revert("salt not found");
    }
}
