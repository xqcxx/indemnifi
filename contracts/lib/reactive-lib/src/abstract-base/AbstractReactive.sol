// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IReactive} from "../interfaces/IReactive.sol";

// Base for RSCs deployed on Reactive Lasna testnet.
// react() is only callable by the Reactive system address (0x...fffFfF).
abstract contract AbstractReactive is IReactive {
    address internal constant REACTIVE_SYSTEM = 0x0000000000000000000000000000000000fffFfF;

    modifier vmOnly() {
        require(msg.sender == REACTIVE_SYSTEM, "not reactive system");
        _;
    }

    function react(
        uint256 chainId,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes calldata data,
        uint64  blockNumber,
        uint256 opCode
    ) external virtual;
}
