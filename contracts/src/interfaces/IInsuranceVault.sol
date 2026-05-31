// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IInsuranceVault {
    event PremiumDeposited(address indexed from, uint256 amount, uint256 newBalance);
    event ClaimPaid(address indexed to, uint256 amount, uint256 balanceAfter);
    event YieldAccrued(uint256 amount, uint256 newBalance);
    event VaultRebalanced(uint256 movedToYield, uint256 movedToLiquid);
    event VaultHealthUpdated(uint256 solvencyBps, uint256 totalAssets);

    function depositPremium(address token, uint256 amount) external;
    function payClaim(address recipient, address token, uint256 amount) external;
    function accrueYield(uint256 amount) external;
    function rebalance() external;

    function solvencyRatioBps() external view returns (uint256);
    function availableForClaims() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function totalPremiums() external view returns (uint256);
    function totalClaimsPaid() external view returns (uint256);
    function totalYieldEarned() external view returns (uint256);
}
