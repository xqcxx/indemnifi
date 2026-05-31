// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IReactive {
    // Emitted in constructor to register event subscriptions with Reactive Network.
    // topic1/2/3 = 0 means wildcard.
    event Subscribe(
        uint256 indexed chainId,
        address indexed contractAddress,
        uint256 indexed topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3
    );

    // Emitted to trigger a callback transaction on the destination chain.
    event Callback(
        uint256 indexed chainId,
        address indexed contractAddress,
        uint256 indexed gas,
        bytes payload
    );
}
