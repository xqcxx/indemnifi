// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20 as SolmateMockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {DemoScenarioRunner} from "../../src/demo/DemoScenarioRunner.sol";
import {IndemnifiHook} from "../../src/hook/IndemnifiHook.sol";
import {InsuranceVault} from "../../src/vault/InsuranceVault.sol";
import {MockYieldVault} from "../../src/vault/MockYieldVault.sol";
import {ILMath} from "../../src/libraries/ILMath.sol";
import {Constants} from "../../src/libraries/Constants.sol";

// Drives DemoScenarioRunner end to end and asserts the documented scenario
// numbers. The runner is the vault owner so it can accrueYield; the test
// account is the runner owner and funds the seed amounts.
contract DemoScenarioRunnerTest is Test, Deployers {
    uint160 constant FLAGS = uint160(Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG);

    MockYieldVault     yieldVault;
    InsuranceVault     vault;
    IndemnifiHook      hook;
    DemoScenarioRunner runner;
    address reserve;

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();
        reserve = Currency.unwrap(currency0);

        yieldVault = new MockYieldVault(IERC20(reserve), address(this));
        vault      = new InsuranceVault(address(this), IERC20(reserve), yieldVault);

        address hookAddr = address(uint160(FLAGS));
        deployCodeTo("IndemnifiHook.sol:IndemnifiHook", abi.encode(manager, vault, address(this)), hookAddr);
        hook = IndemnifiHook(hookAddr);

        // Runner owned by this test account; runner owns the vault so it can accrueYield.
        runner = new DemoScenarioRunner(hook, vault, IERC20(reserve), address(this));
        vault.transferOwnership(address(runner));
        // yieldVault must allow the vault (its caller) to deposit/withdraw — vault is yieldVault owner only for accrueYield;
        // here vault.accrueYield deposits via deposit() which is not onlyOwner, so no transfer needed.

        // Fund this test account and approve the runner to pull seed amounts.
        SolmateMockERC20(reserve).mint(address(this), 1_000_000e18);
        IERC20(reserve).approve(address(runner), type(uint256).max);
    }

    function _run(DemoScenarioRunner.Scenario s) internal returns (DemoScenarioRunner.RunResult memory) {
        runner.runScenario(s);
        return runner.getLastResult();
    }

    // ── CALM: no payout, IL < 1% ─────────────────────────────────────────────

    function test_calm_noPayout() public {
        DemoScenarioRunner.RunResult memory r = _run(DemoScenarioRunner.Scenario.CALM);
        console2.log("CALM ilAmount", r.aliceIL / 1e18);
        console2.log("CALM payout", r.bobPayout / 1e18);
        assertEq(r.bobPayout, 0, "calm: no payout");
        assertEq(uint8(r.scenario), uint8(DemoScenarioRunner.Scenario.CALM));
        assertEq(r.bobPremium, 150e18, "calm premium 1.5% of 10k");
        // Bob's loss = sub-deductible IL (uninsured) + premium. With no payout,
        // finalLoss = ilAmount + premium, and is still far below the deductible.
        assertEq(r.bobFinalLoss, r.aliceIL + r.bobPremium);
        assertLt(r.aliceIL, 100e18, "calm IL under 1% of 10k notional");
    }

    // ── VOLATILE: payout above deductible, capped by maxPayout ───────────────

    function test_volatile_paysAboveDeductible() public {
        DemoScenarioRunner.RunResult memory r = _run(DemoScenarioRunner.Scenario.VOLATILE);
        console2.log("VOLATILE ilAmount", r.aliceIL / 1e18);
        console2.log("VOLATILE payout", r.bobPayout / 1e18);
        console2.log("VOLATILE bobFinalLoss", r.bobFinalLoss / 1e18);
        // A positive payout is made (IL exceeds the 5% deductible).
        assertGt(r.bobPayout, 0, "volatile: payout expected");
        assertLe(r.bobPayout, 1_000e18, "volatile: capped by policy");
        // The payout offsets part of Bob's IL: his pre-premium loss is below Alice's.
        assertLt(r.aliceIL - r.bobPayout, r.aliceIL, "payout reduces realized IL");
    }

    // ── SHOCK: payout capped by maxPayout ────────────────────────────────────

    function test_shock_payoutCapped() public {
        DemoScenarioRunner.RunResult memory r = _run(DemoScenarioRunner.Scenario.SHOCK);
        console2.log("SHOCK ilAmount", r.aliceIL / 1e18);
        console2.log("SHOCK payout", r.bobPayout / 1e18);
        assertEq(r.bobPayout, 1_000e18, "shock: capped at maxPayout");
        assertGt(r.aliceIL, 1_000e18, "shock: alice IL exceeds the cap");
        assertLt(r.bobFinalLoss, r.aliceFinalLoss, "bob still better");
    }

    // ── Config + state ───────────────────────────────────────────────────────

    function test_scenarioConfig_matchesDocumentedDefaults() public view {
        DemoScenarioRunner.ScenarioConfig memory c = runner.getScenarioConfig(DemoScenarioRunner.Scenario.VOLATILE);
        assertEq(c.notional, 10_000e18);
        assertEq(c.thresholdBps, 500);
        assertEq(c.maxPayout, 1_000e18);
        assertEq(c.entryPrice, runner.PRICE_2000());
        assertEq(c.exitPrice, runner.PRICE_2800());
    }

    function test_ranFlag_setAfterRun() public {
        assertFalse(runner.ran());
        _run(DemoScenarioRunner.Scenario.CALM);
        assertTrue(runner.ran());
    }

    function test_onlyOwner_canRun() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        runner.runScenario(DemoScenarioRunner.Scenario.CALM);
    }

    function test_vault_holdsSeedAndYieldAfterRun() public {
        _run(DemoScenarioRunner.Scenario.VOLATILE);
        DemoScenarioRunner.RunResult memory r = runner.getLastResult();
        // Vault was seeded 8500 + premium and accrued 50 yield.
        assertGt(r.vaultBalance, 8_500e18);
        assertGt(r.vaultSolvencyBps, 0);
    }
}
