// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Initialises the WETH/USDC pool on Unichain Sepolia at $2,000 ETH.
//
// Usage:
//   WETH_ADDRESS=0x... USDC_ADDRESS=0x... HOOK_ADDRESS=0x... \
//   forge script script/InitPool.s.sol \
//     --rpc-url $UNICHAIN_RPC_URL \
//     --private-key $PRIVATE_KEY \
//     --broadcast -vvv
contract InitPool is Script {
    using PoolIdLibrary for PoolKey;

    // sqrt(2000 * 10^12) * 2^96 — represents a $2,000 WETH/USDC price.
    // Computed off-chain; token order is WETH(18d) / USDC(6d).
    uint160 constant SQRT_PRICE_2000 = 3543191142285914327220224;

    function run() external {
        uint256 key         = vm.envUint("PRIVATE_KEY");
        address poolManager = vm.envOr("POOL_MANAGER_ADDRESS", address(0x7c13D90950F542B297179e09f3A36EaA917A40C1));
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address weth        = vm.envAddress("WETH_ADDRESS");
        address usdc        = vm.envAddress("USDC_ADDRESS");

        // PoolKey requires currency0 < currency1 (address order).
        (address token0, address token1) = weth < usdc ? (weth, usdc) : (usdc, weth);

        PoolKey memory poolKey = PoolKey({
            currency0:   Currency.wrap(token0),
            currency1:   Currency.wrap(token1),
            fee:         3000,
            tickSpacing: 60,
            hooks:       IHooks(hookAddress)
        });

        console2.log("Pool ID :", uint256(PoolId.unwrap(poolKey.toId())));

        vm.startBroadcast(key);
        IPoolManager(poolManager).initialize(poolKey, SQRT_PRICE_2000);
        vm.stopBroadcast();

        console2.log("=== POOL INITIALISED ===");
        console2.log("token0      :", token0);
        console2.log("token1      :", token1);
        console2.log("sqrtPriceX96:", SQRT_PRICE_2000);
    }
}
