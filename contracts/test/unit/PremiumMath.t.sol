// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PremiumMath} from "../../src/libraries/PremiumMath.sol";
import {Constants} from "../../src/libraries/Constants.sol";

contract PremiumMathTest is Test {
    uint256 constant NOTIONAL = 10_000e18;

    function test_calmTierBps() public pure {
        assertEq(PremiumMath.premiumBpsForTier(0), Constants.CALM_PREMIUM_BPS);
    }

    function test_volatileTierBps() public pure {
        assertEq(PremiumMath.premiumBpsForTier(1), Constants.VOLATILE_PREMIUM_BPS);
    }

    function test_shockTierBps() public pure {
        assertEq(PremiumMath.premiumBpsForTier(2), Constants.SHOCK_PREMIUM_BPS);
    }

    function test_calculatePremium_calm() public pure {
        uint256 p = PremiumMath.calculatePremium(NOTIONAL, Constants.CALM_PREMIUM_BPS);
        assertEq(p, 150e18); // 1.5% of 10k
    }

    function test_calculatePremium_volatile() public pure {
        uint256 p = PremiumMath.calculatePremium(NOTIONAL, Constants.VOLATILE_PREMIUM_BPS);
        assertEq(p, 300e18);
    }

    function test_calculatePremium_shock() public pure {
        uint256 p = PremiumMath.calculatePremium(NOTIONAL, Constants.SHOCK_PREMIUM_BPS);
        assertEq(p, 700e18);
    }

    function test_calculatePremium_scalesLinearly() public pure {
        uint256 p1 = PremiumMath.calculatePremium(NOTIONAL, 200);
        uint256 p2 = PremiumMath.calculatePremium(NOTIONAL * 2, 200);
        assertEq(p2, p1 * 2);
    }
}
