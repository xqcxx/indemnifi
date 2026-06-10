// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FaucetToken} from "../src/mocks/FaucetToken.sol";
import {MockYieldVault} from "../src/vault/MockYieldVault.sol";
import {InsuranceVault} from "../src/vault/InsuranceVault.sol";
import {IndemnifiHook} from "../src/hook/IndemnifiHook.sol";
import {DemoScenarioRunner} from "../src/demo/DemoScenarioRunner.sol";

// One-shot Unichain Sepolia deployment: tokens (+faucet), vaults, hook
// (CREATE2-mined), pool init, vault seed, and demo runner. Prints a ready
// .env.local block at the end.
contract DeployTestnet is Script {
    using PoolIdLibrary for PoolKey;

    address constant POOL_MANAGER = 0x7c13D90950F542B297179e09f3A36EaA917A40C1;
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    uint160 constant SQRT_PRICE_2000 = 3543191142285914327220224;
    uint24 constant FEE = 3000;
    int24 constant TICK_SPACING = 60;

    struct Deployment {
        FaucetToken usdc;
        FaucetToken weth;
        MockYieldVault yieldVault;
        InsuranceVault vault;
        IndemnifiHook hook;
        DemoScenarioRunner runner;
        bytes32 poolId;
    }

    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(key);

        console2.log("Deployer:", deployer);
        console2.log("Chain   :", block.chainid);

        vm.startBroadcast(key);
        Deployment memory d = _deploy(deployer);
        vm.stopBroadcast();

        _report(d);
    }

    function _deploy(address deployer) internal returns (Deployment memory d) {
        d.usdc = new FaucetToken("Indemnifi USDC", "iUSDC", 6, 10_000e6);
        d.weth = new FaucetToken("Indemnifi WETH", "iWETH", 18, 5e18);

        // currency0 (lower address) is the premium/claim token.
        address premium = address(d.weth) < address(d.usdc) ? address(d.weth) : address(d.usdc);

        d.yieldVault = new MockYieldVault(IERC20(premium), deployer);
        d.vault = new InsuranceVault(deployer, IERC20(premium), d.yieldVault);

        d.hook = _deployHook(deployer, d.vault);
        d.vault.setHook(address(d.hook));

        d.poolId = _initPool(address(d.weth), address(d.usdc), address(d.hook));

        // Seed vault backing through the accounted entry point.
        FaucetToken(premium).faucet();
        uint256 seed = FaucetToken(premium).balanceOf(deployer);
        IERC20(premium).approve(address(d.vault), seed);
        d.vault.accrueYield(seed);

        d.runner = new DemoScenarioRunner(d.hook, d.vault, IERC20(premium), deployer);
    }

    function _deployHook(address deployer, InsuranceVault vault)
        internal returns (IndemnifiHook hook)
    {
        bytes memory creationCode = abi.encodePacked(
            type(IndemnifiHook).creationCode,
            abi.encode(IPoolManager(POOL_MANAGER), vault, deployer)
        );
        (address hookAddr, bytes32 salt) = _mine(
            uint160(Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG),
            creationCode
        );
        hook = new IndemnifiHook{salt: salt}(IPoolManager(POOL_MANAGER), vault, deployer);
        require(address(hook) == hookAddr, "hook address mismatch");
    }

    function _initPool(address weth, address usdc, address hook) internal returns (bytes32) {
        (address t0, address t1) = weth < usdc ? (weth, usdc) : (usdc, weth);
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(t0),
            currency1: Currency.wrap(t1),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(hook)
        });
        IPoolManager(POOL_MANAGER).initialize(poolKey, SQRT_PRICE_2000);
        return PoolId.unwrap(poolKey.toId());
    }

    function _report(Deployment memory d) internal pure {
        console2.log("");
        console2.log("=== DEPLOYED (Unichain Sepolia) ===");
        console2.log("USDC          :", address(d.usdc));
        console2.log("WETH          :", address(d.weth));
        console2.log("YieldVault    :", address(d.yieldVault));
        console2.log("InsuranceVault:", address(d.vault));
        console2.log("Hook          :", address(d.hook));
        console2.log("ScenarioRunner:", address(d.runner));
        console2.log("PoolId        :", uint256(d.poolId));
        console2.log("");
        console2.log("--- frontend/.env.local ---");
        console2.log("NEXT_PUBLIC_CHAIN_ID=1301");
        console2.log("NEXT_PUBLIC_HOOK_ADDRESS=", address(d.hook));
        console2.log("NEXT_PUBLIC_VAULT_ADDRESS=", address(d.vault));
        console2.log("NEXT_PUBLIC_YIELD_VAULT_ADDRESS=", address(d.yieldVault));
        console2.log("NEXT_PUBLIC_SCENARIO_RUNNER_ADDRESS=", address(d.runner));
        console2.log("NEXT_PUBLIC_WETH_ADDRESS=", address(d.weth));
        console2.log("NEXT_PUBLIC_USDC_ADDRESS=", address(d.usdc));
        console2.log("NEXT_PUBLIC_POOL_FEE=3000");
        console2.log("NEXT_PUBLIC_POOL_TICK_SPACING=60");
    }

    // Lower 14 bits of the address must equal exactly the declared flags.
    uint160 constant ALL_HOOK_MASK = uint160((1 << 14) - 1);

    function _mine(uint160 flags, bytes memory creationCode)
        internal pure returns (address hookAddr, bytes32 salt)
    {
        bytes32 initHash = keccak256(creationCode);
        for (uint256 i = 0; i < 500_000; i++) {
            salt = bytes32(i);
            hookAddr = address(uint160(uint256(keccak256(
                abi.encodePacked(bytes1(0xff), CREATE2_DEPLOYER, salt, initHash)
            ))));
            if (uint160(hookAddr) & ALL_HOOK_MASK == flags) return (hookAddr, salt);
        }
        revert("salt not found");
    }
}
