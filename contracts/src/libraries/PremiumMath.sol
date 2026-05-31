// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Constants} from "./Constants.sol";

library PremiumMath {
    uint256 private constant BPS = 10_000;

    // Maps a uint8 risk tier (0=CALM, 1=VOLATILE, 2=SHOCK) to premium bps.
    function premiumBpsForTier(uint8 tier) internal pure returns (uint256) {
        if (tier == 1) return Constants.VOLATILE_PREMIUM_BPS;
        if (tier == 2) return Constants.SHOCK_PREMIUM_BPS;
        return Constants.CALM_PREMIUM_BPS;
    }

    function calculatePremium(uint256 notional, uint256 premiumBps)
        internal pure returns (uint256)
    {
        return (notional * premiumBps) / BPS;
    }
}
