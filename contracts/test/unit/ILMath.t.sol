// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ILMath} from "../../src/libraries/ILMath.sol";

contract ILMathTest is Test {
    // These sqrtPriceX96 values represent ETH/USDC prices.
    // Computed from: sqrt(price * 10^(decDiff)) * 2^96
    // decDiff for WETH(18)/USDC(6) is 10^12.
    uint160 constant PRICE_2000 = 3543191142285914327220224;
    uint160 constant PRICE_2080 = 3716130220787573423341568; // +4%
    uint160 constant PRICE_2800 = 5010828967500958937382912; // +40%
    uint160 constant PRICE_4000 = 7086382284571828654440448; // +100%

    uint256 constant NOTIONAL = 10_000e18;

    function test_noMove_zeroIL() public pure {
        assertEq(ILMath.calculateILBps(PRICE_2000, PRICE_2000), 0);
    }

    function test_zeroEntry_zeroIL() public pure {
        assertEq(ILMath.calculateILBps(0, PRICE_2000), 0);
    }

    // PRICE_2080 = +10% price move → ~11 bps IL (well below any threshold)
    function test_calmMove_ilBelowOnePercent() public pure {
        uint256 il = ILMath.calculateILBps(PRICE_2000, PRICE_2080);
        assertLt(il, 50);
    }

    // PRICE_2800 = 2x price move ($2000→$4000) → ~572 bps IL (5.72%)
    function test_volatileMove_ilAbove500Bps() public pure {
        uint256 il = ILMath.calculateILBps(PRICE_2000, PRICE_2800);
        assertGt(il, 500);
        assertLt(il, 700);
    }

    // PRICE_4000 = 4x price move ($2000→$8000) → ~2000 bps IL (20%)
    function test_shockMove_ilAbove1000Bps() public pure {
        uint256 il = ILMath.calculateILBps(PRICE_2000, PRICE_4000);
        assertGt(il, 1000);
        assertLt(il, 3000);
    }

    function test_doublePrice_ilApprox572Bps() public pure {
        // 2x price move: IL = 1 - 2√2/3 ≈ 5.72% = 572 bps
        // Using PRICE_2800 which represents 2x
        uint256 il = ILMath.calculateILBps(PRICE_2000, PRICE_2800);
        assertApproxEqAbs(il, 572, 30);
    }

    function test_symmetry_priceUpVsDown() public pure {
        // IL from entry→exit equals IL from entry→(entry^2/exit) by symmetry.
        uint256 ilUp = ILMath.calculateILBps(PRICE_2000, PRICE_2800);
        uint256 invPrice = (uint256(PRICE_2000) * uint256(PRICE_2000)) / uint256(PRICE_2800);
        // invPrice fits in uint160 because entry^2/exit < entry when exit > entry
        // forge-lint: disable-next-line(unsafe-typecast)
        uint160 downPrice = uint160(invPrice);
        uint256 ilDown = ILMath.calculateILBps(PRICE_2000, downPrice);
        assertApproxEqAbs(ilUp, ilDown, 50);
    }

    function test_calculateILAmount() public pure {
        uint256 amount = ILMath.calculateILAmount(900, NOTIONAL);
        assertEq(amount, 900e18);
    }

    function test_payout_belowDeductible_zero() public pure {
        // IL = $200, threshold = 5% ($500) — no payout
        (uint256 ded, uint256 covered, uint256 payout) =
            ILMath.calculatePayout(200e18, 500, NOTIONAL, 1_000e18, 8_500e18);
        assertEq(ded,     500e18);
        assertEq(covered, 0);
        assertEq(payout,  0);
    }

    function test_payout_aboveDeductible() public pure {
        // IL = $900, threshold = 5% ($500), covered = $400, cap $1000, vault $8500
        (uint256 ded, uint256 covered, uint256 payout) =
            ILMath.calculatePayout(900e18, 500, NOTIONAL, 1_000e18, 8_500e18);
        assertEq(ded,     500e18);
        assertEq(covered, 400e18);
        assertEq(payout,  400e18);
    }

    function test_payout_cappedByMaxPayout() public pure {
        // covered = $1500 but maxPayout = $1000
        (,, uint256 payout) =
            ILMath.calculatePayout(2_000e18, 500, NOTIONAL, 1_000e18, 8_500e18);
        assertEq(payout, 1_000e18);
    }

    function test_payout_cappedByVaultBalance() public pure {
        // vault only has $200
        (,, uint256 payout) =
            ILMath.calculatePayout(2_000e18, 500, NOTIONAL, 1_000e18, 200e18);
        assertEq(payout, 200e18);
    }
}
