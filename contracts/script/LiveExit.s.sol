// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Adds then removes liquidity passing a policyId in hookData, so the hook emits
// PolicyExitRequested. The Reactive RSC reacts and calls settleClaim back.
contract LiveExit is Script {
    address constant POOL_MANAGER = 0x7c13D90950F542B297179e09f3A36EaA917A40C1;

    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        address weth = vm.envAddress("WETH_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address hook = vm.envAddress("HOOK_ADDRESS");
        uint256 policyId = vm.envUint("POLICY_ID");

        (address t0, address t1) = weth < usdc ? (weth, usdc) : (usdc, weth);
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(t0),
            currency1: Currency.wrap(t1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });

        vm.startBroadcast(key);

        PoolModifyLiquidityTest lpRouter = new PoolModifyLiquidityTest(IPoolManager(POOL_MANAGER));
        IERC20(t0).approve(address(lpRouter), type(uint256).max);
        IERC20(t1).approve(address(lpRouter), type(uint256).max);

        lpRouter.modifyLiquidity(
            poolKey,
            IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: 0}),
            ""
        );
        // Remove, passing the policyId so afterRemoveLiquidity emits the exit.
        lpRouter.modifyLiquidity(
            poolKey,
            IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: 0}),
            abi.encode(policyId)
        );

        vm.stopBroadcast();
        console2.log("PolicyExitRequested emitted for policy", policyId);
    }
}
