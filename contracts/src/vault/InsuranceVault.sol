// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MockYieldVault} from "./MockYieldVault.sol";
import {IInsuranceVault} from "../interfaces/IInsuranceVault.sol";
import {Constants} from "../libraries/Constants.sol";

// Holds LP insurance premiums, routes idle capital to the yield vault,
// and pays validated claims. The hook is the only authorized caller of
// depositPremium() and payClaim().
contract InsuranceVault is IInsuranceVault, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    MockYieldVault public immutable yieldVault;
    IERC20         public immutable reserveToken;

    address public hook;

    uint256 public override totalPremiums;
    uint256 public override totalClaimsPaid;
    uint256 public override totalYieldEarned;
    uint256 public liquidReserve;

    // 20% of each deposit stays liquid for immediate payouts; 80% earns yield.
    uint256 private constant LIQUID_RATIO_BPS = 2000;
    uint256 private constant BPS              = 10_000;

    error OnlyHook();
    error InsufficientReserves();
    error UnsupportedToken();

    modifier onlyHook() {
        if (msg.sender != hook) revert OnlyHook();
        _;
    }

    constructor(address initialOwner, IERC20 _reserveToken, MockYieldVault _yieldVault)
        Ownable(initialOwner)
    {
        reserveToken = _reserveToken;
        yieldVault   = _yieldVault;
    }

    // Called once after hook deployment.
    function setHook(address _hook) external onlyOwner {
        hook = _hook;
    }

    // ── Premium handling ──────────────────────────────────────────────────

    // Hook transfers the premium in the same call that creates the policy.
    // Tokens must already be in this contract when called (hook pulled them first).
    function depositPremium(address token, uint256 amount) external override onlyHook {
        if (token != address(reserveToken)) revert UnsupportedToken();

        totalPremiums += amount;

        uint256 toLiquid = (amount * LIQUID_RATIO_BPS) / BPS;
        uint256 toYield  = amount - toLiquid;
        liquidReserve   += toLiquid;

        if (toYield > 0) {
            reserveToken.forceApprove(address(yieldVault), toYield);
            yieldVault.deposit(toYield, address(this));
        }

        uint256 balance = totalAssets();
        emit PremiumDeposited(msg.sender, amount, balance);
        emit VaultHealthUpdated(solvencyRatioBps(), balance);
    }

    // ── Claim payout ──────────────────────────────────────────────────────

    function payClaim(address recipient, address token, uint256 amount)
        external override onlyHook nonReentrant
    {
        if (token != address(reserveToken)) revert UnsupportedToken();
        if (amount > availableForClaims())  revert InsufficientReserves();

        // Draw from liquid first, then redeem from yield vault.
        if (amount <= liquidReserve) {
            liquidReserve -= amount;
        } else {
            uint256 fromYield = amount - liquidReserve;
            liquidReserve     = 0;
            yieldVault.withdraw(fromYield, address(this), address(this));
        }

        reserveToken.safeTransfer(recipient, amount);
        totalClaimsPaid += amount;

        uint256 balance = totalAssets();
        emit ClaimPaid(recipient, amount, balance);
        emit VaultHealthUpdated(solvencyRatioBps(), balance);
    }

    // ── Yield & rebalancing ───────────────────────────────────────────────

    // Credits mock yield by pulling tokens and depositing into the yield vault.
    // Called by the owner / DemoScenarioRunner to simulate interest accrual.
    function accrueYield(uint256 amount) external override onlyOwner {
        reserveToken.safeTransferFrom(msg.sender, address(this), amount);
        reserveToken.forceApprove(address(yieldVault), amount);
        yieldVault.deposit(amount, address(this));

        totalYieldEarned += amount;

        uint256 balance = totalAssets();
        emit YieldAccrued(amount, balance);
        emit VaultHealthUpdated(solvencyRatioBps(), balance);
    }

    // Rebalance liquid/yield split back toward the LIQUID_RATIO_BPS target.
    function rebalance() external override onlyOwner {
        uint256 total = totalAssets();
        if (total == 0) return;

        uint256 targetLiquid = (total * LIQUID_RATIO_BPS) / BPS;

        if (liquidReserve < targetLiquid) {
            uint256 needed   = targetLiquid - liquidReserve;
            uint256 canRedeem = yieldVault.maxWithdraw(address(this));
            uint256 toWithdraw = needed < canRedeem ? needed : canRedeem;
            if (toWithdraw > 0) {
                yieldVault.withdraw(toWithdraw, address(this), address(this));
                liquidReserve += toWithdraw;
                emit VaultRebalanced(0, toWithdraw);
            }
        } else if (liquidReserve > targetLiquid * 2) {
            uint256 excess = liquidReserve - targetLiquid;
            liquidReserve -= excess;
            reserveToken.forceApprove(address(yieldVault), excess);
            yieldVault.deposit(excess, address(this));
            emit VaultRebalanced(excess, 0);
        }
    }

    // ── Views ─────────────────────────────────────────────────────────────

    function totalAssets() public view override returns (uint256) {
        return liquidReserve + yieldVault.maxWithdraw(address(this));
    }

    function availableForClaims() public view override returns (uint256) {
        return totalAssets();
    }

    // Uses totalPremiums as the expected liability proxy. A freshly-funded vault
    // starts at 10_000 bps (100%). Falls as claims are paid.
    function solvencyRatioBps() public view override returns (uint256) {
        if (totalPremiums == 0) return BPS;
        uint256 assets = totalAssets();
        return (assets * BPS) / totalPremiums;
    }
}
