// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Testnet ERC20 with a public faucet. Production swaps this for canonical assets.
contract FaucetToken is ERC20 {
    uint8 private immutable _decimals;
    uint256 public immutable faucetAmount;
    uint256 public constant CLAIM_COOLDOWN = 8 hours;

    mapping(address => uint256) public lastClaim;

    error CooldownActive(uint256 readyAt);

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 faucetAmount_)
        ERC20(name_, symbol_)
    {
        _decimals = decimals_;
        faucetAmount = faucetAmount_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    // Claim test tokens. Rate-limited per address.
    function faucet() external {
        uint256 ready = lastClaim[msg.sender] + CLAIM_COOLDOWN;
        if (lastClaim[msg.sender] != 0 && block.timestamp < ready) revert CooldownActive(ready);
        lastClaim[msg.sender] = block.timestamp;
        _mint(msg.sender, faucetAmount);
    }

    function claimableAt(address user) external view returns (uint256) {
        if (lastClaim[user] == 0) return 0;
        return lastClaim[user] + CLAIM_COOLDOWN;
    }
}
