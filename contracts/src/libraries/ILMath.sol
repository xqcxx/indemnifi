// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Impermanent loss calculations using Uniswap v4 sqrtPriceX96 values.
//
// Standard constant-product IL formula:
//   r = (exitSqrt / entrySqrt)^2        <- price ratio
//   il_fraction = 1 - 2*sqrt(r)/(1+r)  <- always >= 0
//   il_bps = il_fraction * 10_000
//
// We compute using sqrtPrices directly — dividing sqrtPrices gives sqrt(r),
// so 2*sqrtRatio/(1+sqrtRatio^2) is the hold-value fraction in LP form.
library ILMath {
    uint256 private constant WAD = 1e18;
    uint256 private constant BPS = 10_000;

    function calculateILBps(uint160 sqrtEntryX96, uint160 sqrtExitX96)
        internal pure returns (uint256 ilBps)
    {
        if (sqrtEntryX96 == 0 || sqrtExitX96 == sqrtEntryX96) return 0;

        // sqrtRatio = exitSqrt / entrySqrt in WAD
        uint256 sqrtRatioWad = (uint256(sqrtExitX96) * WAD) / uint256(sqrtEntryX96);

        // holdFraction = 2*sqrtRatio / (1 + sqrtRatio^2) in WAD
        uint256 numerator   = 2 * sqrtRatioWad;
        uint256 denominator = WAD + (sqrtRatioWad * sqrtRatioWad) / WAD;
        uint256 holdWad     = (numerator * WAD) / denominator;

        if (holdWad >= WAD) return 0;
        ilBps = ((WAD - holdWad) * BPS) / WAD;
    }

    function calculateILAmount(uint256 ilBps, uint256 notional)
        internal pure returns (uint256)
    {
        return (notional * ilBps) / BPS;
    }

    // Returns the three components of a claim calculation.
    // deductible = first-loss slice LP absorbs regardless
    // coveredIl  = the amount insurance covers before caps
    // payout     = final payout after policy cap and vault availability
    function calculatePayout(
        uint256 ilAmount,
        uint256 thresholdBps,
        uint256 notional,
        uint256 maxPayout,
        uint256 vaultAvailable
    ) internal pure returns (uint256 deductible, uint256 coveredIl, uint256 payout) {
        deductible = (notional * thresholdBps) / BPS;
        if (ilAmount <= deductible) return (deductible, 0, 0);

        coveredIl = ilAmount - deductible;
        payout    = coveredIl;
        if (payout > maxPayout)      payout = maxPayout;
        if (payout > vaultAvailable) payout = vaultAvailable;
    }
}
