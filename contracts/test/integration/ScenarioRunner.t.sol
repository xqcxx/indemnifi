// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {ILMath} from "../../src/libraries/ILMath.sol";
import {PremiumMath} from "../../src/libraries/PremiumMath.sol";
import {Constants} from "../../src/libraries/Constants.sol";

// Validates the exact scenario numbers used in the demo.
// These are pure-math tests — no fork needed.
//
// The numbers here must match what DemoScenarioRunner.sol computes
// and what the frontend displays.
contract ScenarioRunnerTest is Test {
    uint160 constant PRICE_2000 = 3543191142285914327220224;
    uint160 constant PRICE_2080 = 3716130220787573423341568;
    uint160 constant PRICE_2800 = 5010828967500958937382912;
    uint160 constant PRICE_4000 = 7086382284571828654440448;

    uint256 constant NOTIONAL       = 10_000e18;
    uint256 constant THRESHOLD_BPS  = 500;   // 5%
    uint256 constant MAX_PAYOUT     = 1_000e18;
    uint256 constant VAULT_AVAILABLE = 8_500e18;

    function test_calmScenario_noPayoutExpected() public pure {
        uint256 ilBps    = ILMath.calculateILBps(PRICE_2000, PRICE_2080);
        uint256 ilAmount = ILMath.calculateILAmount(ilBps, NOTIONAL);
        (,, uint256 payout) = ILMath.calculatePayout(ilAmount, THRESHOLD_BPS, NOTIONAL, MAX_PAYOUT, VAULT_AVAILABLE);

        console2.log("CALM ilBps   :", ilBps);
        console2.log("CALM ilAmount:", ilAmount / 1e18, "USD");
        console2.log("CALM payout  :", payout / 1e18, "USD");

        assertEq(payout, 0, "calm: no payout");
        assertLt(ilBps,  100, "calm: IL < 1%");
    }

    function test_volatileScenario_payoutAboveDeductible() public pure {
        uint256 ilBps    = ILMath.calculateILBps(PRICE_2000, PRICE_2800);
        uint256 ilAmount = ILMath.calculateILAmount(ilBps, NOTIONAL);
        (uint256 ded, uint256 covered, uint256 payout) =
            ILMath.calculatePayout(ilAmount, THRESHOLD_BPS, NOTIONAL, MAX_PAYOUT, VAULT_AVAILABLE);

        console2.log("VOLATILE ilBps   :", ilBps);
        console2.log("VOLATILE ilAmount:", ilAmount / 1e18, "USD");
        console2.log("VOLATILE deduct  :", ded / 1e18, "USD");
        console2.log("VOLATILE covered :", covered / 1e18, "USD");
        console2.log("VOLATILE payout  :", payout / 1e18, "USD");

        assertGt(payout, 0, "volatile: payout expected");
        assertGe(ilBps, THRESHOLD_BPS, "volatile: IL > threshold");
        assertLe(payout, MAX_PAYOUT, "volatile: capped by policy");
    }

    function test_shockScenario_payoutCappedByPolicy() public pure {
        uint256 ilBps    = ILMath.calculateILBps(PRICE_2000, PRICE_4000);
        uint256 ilAmount = ILMath.calculateILAmount(ilBps, NOTIONAL);
        (,, uint256 payout) =
            ILMath.calculatePayout(ilAmount, THRESHOLD_BPS, NOTIONAL, MAX_PAYOUT, VAULT_AVAILABLE);

        console2.log("SHOCK ilBps   :", ilBps);
        console2.log("SHOCK ilAmount:", ilAmount / 1e18, "USD");
        console2.log("SHOCK payout  :", payout / 1e18, "USD");

        assertGt(payout, 0, "shock: payout expected");
        assertLe(payout, MAX_PAYOUT, "shock: capped at maxPayout");
    }

    // Uses PRICE_4000 (4x move, ~20% IL) where payout > premium so Bob nets ahead of Alice.
    function test_aliceBobComparison_bobBetter_shock() public pure {
        uint256 premium = PremiumMath.calculatePremium(NOTIONAL, Constants.CALM_PREMIUM_BPS);

        uint256 ilBps    = ILMath.calculateILBps(PRICE_2000, PRICE_4000);
        uint256 ilAmount = ILMath.calculateILAmount(ilBps, NOTIONAL);
        (,, uint256 payout) =
            ILMath.calculatePayout(ilAmount, THRESHOLD_BPS, NOTIONAL, MAX_PAYOUT, VAULT_AVAILABLE);

        uint256 aliceLoss = ilAmount;
        uint256 bobLoss   = ilAmount > payout ? ilAmount - payout + premium : premium;

        console2.log("Alice loss (shock):", aliceLoss / 1e18, "USD");
        console2.log("Bob loss   (shock):", bobLoss   / 1e18, "USD");
        console2.log("Advantage         :", aliceLoss > bobLoss ? (aliceLoss - bobLoss) / 1e18 : 0, "USD");

        // At 20% IL with 5% deductible, covered = 15%, capped at maxPayout ($1000)
        // Bob's net = 20% IL - $1000 payout + $150 premium = still > Alice only if payout makes up the diff
        // This assertion verifies payout is non-zero and covers meaningful IL
        assertGt(payout, premium, "shock payout should exceed premium paid");
    }

    function test_premiumConstants_matchDocumentedValues() public pure {
        assertEq(Constants.CALM_PREMIUM_BPS,     150);
        assertEq(Constants.VOLATILE_PREMIUM_BPS, 300);
        assertEq(Constants.SHOCK_PREMIUM_BPS,    700);
    }

    function test_calmPremium_on10kNotional_is150() public pure {
        uint256 p = PremiumMath.calculatePremium(NOTIONAL, Constants.CALM_PREMIUM_BPS);
        assertEq(p, 150e18);
    }

    function test_shockPremium_on10kNotional_is700() public pure {
        uint256 p = PremiumMath.calculatePremium(NOTIONAL, Constants.SHOCK_PREMIUM_BPS);
        assertEq(p, 700e18);
    }
}
