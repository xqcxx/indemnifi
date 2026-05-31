// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IndemnifiHook} from "../hook/IndemnifiHook.sol";
import {InsuranceVault} from "../vault/InsuranceVault.sol";
import {IIndemnifiHook} from "../interfaces/IIndemnifiHook.sol";
import {ILMath} from "../libraries/ILMath.sol";
import {PremiumMath} from "../libraries/PremiumMath.sol";
import {Constants} from "../libraries/Constants.sol";

// Helper contract for local Anvil and testnet demos.
// Simulates the full Alice (uninsured) vs Bob (insured) lifecycle and
// exposes the final comparison numbers to the frontend via getLastResult().
//
// The three preset price moves are fixed - same numbers every run.
// Caller must approve this contract to spend `token` before calling runScenario().
contract DemoScenarioRunner is Ownable {
    using SafeERC20 for IERC20;

    enum Scenario { CALM, VOLATILE, SHOCK }

    struct ScenarioConfig {
        uint160 entryPrice;    // sqrtPriceX96 - $2,000 ETH
        uint160 exitPrice;     // sqrtPriceX96 after market move
        uint256 notional;      // 10_000e18
        uint256 thresholdBps;  // 500 (5% deductible)
        uint256 maxPayout;     // 1_000e18
        uint256 seedYield;     // mock yield to accrue mid-scenario
    }

    struct RunResult {
        Scenario scenario;
        uint256  aliceIL;         // dollar IL, no protection
        uint256  aliceFinalLoss;  // same as aliceIL - no payout
        uint256  bobIL;
        uint256  bobPayout;
        uint256  bobPremium;
        uint256  bobFinalLoss;    // bobIL - bobPayout + bobPremium
        uint256  bobAdvantage;    // aliceFinalLoss - bobFinalLoss
        uint256  vaultBalance;
        uint256  vaultSolvencyBps;
        bool     coveragePaused;
    }

    IndemnifiHook  public immutable hook;
    InsuranceVault public immutable vault;
    IERC20         public immutable token;

    RunResult public lastResult;
    bool      public ran;

    // Deterministic sqrtPriceX96 values (ETH/USDC, 18+6 decimals).
    // These match the values in ScenarioRunner.t.sol.
    uint160 public constant PRICE_2000 = 3543191142285914327220224;
    uint160 public constant PRICE_2080 = 3716130220787573423341568;
    uint160 public constant PRICE_2800 = 5010828967500958937382912;
    uint160 public constant PRICE_4000 = 7086382284571828654440448;

    event ScenarioRan(Scenario indexed scenario, RunResult result);
    event StepComplete(uint8 step, string description);

    constructor(IndemnifiHook _hook, InsuranceVault _vault, IERC20 _token, address initialOwner)
        Ownable(initialOwner)
    {
        hook  = _hook;
        vault = _vault;
        token = _token;
    }

    function getScenarioConfig(Scenario s) public pure returns (ScenarioConfig memory cfg) {
        cfg.notional     = 10_000e18;
        cfg.thresholdBps = 500;
        cfg.maxPayout    = 1_000e18;
        cfg.seedYield    = 50e18;
        cfg.entryPrice   = PRICE_2000;
        if      (s == Scenario.CALM)     cfg.exitPrice = PRICE_2080;
        else if (s == Scenario.VOLATILE) cfg.exitPrice = PRICE_2800;
        else                             cfg.exitPrice = PRICE_4000;
    }

    // Runs the complete scenario in one transaction.
    // Emits StepComplete events so the frontend can animate the timeline.
    function runScenario(Scenario s) external onlyOwner {
        ScenarioConfig memory cfg = getScenarioConfig(s);

        emit StepComplete(1, "Entry price set");
        emit StepComplete(2, "Alice adds uninsured liquidity");
        emit StepComplete(3, "Bob adds insured liquidity");

        // Bob's premium at calm rate (this is a simulation; hook.createPolicy
        // would be called on a live pool, not here).
        uint256 bps     = Constants.CALM_PREMIUM_BPS;
        uint256 premium = PremiumMath.calculatePremium(cfg.notional, bps);

        // Seed vault with premium + existing reserves.
        uint256 vaultSeed = 8_500e18 + premium;
        token.safeTransferFrom(msg.sender, address(vault), vaultSeed);

        emit StepComplete(4, "Bob premium entered vault");

        // Accrue mock yield.
        token.forceApprove(address(vault), cfg.seedYield);
        token.safeTransferFrom(msg.sender, address(this), cfg.seedYield);
        token.forceApprove(address(vault), cfg.seedYield);
        vault.accrueYield(cfg.seedYield);

        emit StepComplete(5, "Vault earned mock yield");
        emit StepComplete(6, "Market moved");
        emit StepComplete(7, "Reactive detected risk state change");
        emit StepComplete(8, "Alice exits - absorbs full IL");
        emit StepComplete(9, "Bob exits - claim triggered by Reactive");

        // Compute IL and payout.
        uint256 ilBps   = ILMath.calculateILBps(cfg.entryPrice, cfg.exitPrice);
        uint256 ilAmount = ILMath.calculateILAmount(ilBps, cfg.notional);

        (,, uint256 payout) = ILMath.calculatePayout(
            ilAmount,
            cfg.thresholdBps,
            cfg.notional,
            cfg.maxPayout,
            vault.availableForClaims()
        );

        emit StepComplete(10, "Claim settled from vault");

        uint256 finalVault    = vault.totalAssets();
        uint256 solvencyBps   = vault.solvencyRatioBps();

        lastResult = RunResult({
            scenario:       s,
            aliceIL:        ilAmount,
            aliceFinalLoss: ilAmount,
            bobIL:          ilAmount,
            bobPayout:      payout,
            bobPremium:     premium,
            bobFinalLoss:   ilAmount > payout ? ilAmount - payout + premium : premium,
            bobAdvantage:   ilAmount > (ilAmount > payout ? ilAmount - payout + premium : premium)
                                ? ilAmount - (ilAmount > payout ? ilAmount - payout + premium : premium)
                                : 0,
            vaultBalance:    finalVault,
            vaultSolvencyBps: solvencyBps,
            coveragePaused:  solvencyBps < Constants.SOLVENCY_PAUSE_BPS
        });

        ran = true;

        emit StepComplete(11, "Final comparison ready");
        emit ScenarioRan(s, lastResult);
    }

    function getLastResult() external view returns (RunResult memory) {
        return lastResult;
    }
}
