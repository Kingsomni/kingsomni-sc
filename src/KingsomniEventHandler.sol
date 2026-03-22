// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SomniaEventHandler} from "@somnia-chain/reactivity-contracts/contracts/SomniaEventHandler.sol";

interface IEventGameHook {
    function toggleGlobalBoss(bool active) external;
}

contract KingsomniEventHandler is SomniaEventHandler {
    IEventGameHook public immutable game;

    constructor(address _game, address, address) {
        game = IEventGameHook(_game);
    }

    function _onEvent(address, bytes32[] calldata eventTopics, bytes calldata) internal override {
        if (eventTopics.length > 0) {
            game.toggleGlobalBoss(true);
        }
    }
}
