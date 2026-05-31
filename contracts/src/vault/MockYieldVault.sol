// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// ERC4626 vault that simulates Aave/Morpho yield for demo purposes.
// Owner calls accrueYield() to credit synthetic interest — in production
// this is replaced by harvesting aToken rebases or Morpho shares.
//
// Frontend label: "Demo yield vault. Production target: Aave v3 / Morpho."
contract MockYieldVault is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    uint256 private _totalAssets;

    event YieldAccrued(uint256 amount, uint256 newTotalAssets);

    constructor(IERC20 asset_, address initialOwner)
        ERC4626(asset_)
        ERC20("Indemnifi Yield Shares", "idyV")
        Ownable(initialOwner)
    {}

    function totalAssets() public view override returns (uint256) {
        return _totalAssets;
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
        shares = _convertToShares(assets, Math.Rounding.Floor);
        _mint(receiver, shares);
        _totalAssets += assets;
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner_)
        public override returns (uint256 shares)
    {
        shares = _convertToShares(assets, Math.Rounding.Ceil);
        if (msg.sender != owner_) _spendAllowance(owner_, msg.sender, shares);
        _burn(owner_, shares);
        _totalAssets -= assets;
        IERC20(asset()).safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner_, assets, shares);
    }

    // Credit synthetic yield — tokens transferred from caller (owner or test runner).
    // In production this is replaced by Aave aToken rebase or Morpho harvest.
    function accrueYield(uint256 amount) external onlyOwner {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        _totalAssets += amount;
        emit YieldAccrued(amount, _totalAssets);
    }
}

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
