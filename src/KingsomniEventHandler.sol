// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SomniaEventHandler } from "@somnia-chain/reactivity-contracts/contracts/SomniaEventHandler.sol";
import "./KingsomniGame.sol";

/**
 * @title KingsomniEventHandler
 * @notice "The Brain" - Reacts autonomously to economic events on Somnia Chain.
 */
contract KingsomniEventHandler is SomniaEventHandler {
    KingsomniGame public game;
    address public profileAddress;
    address public treasuryAddress;

    // Event signatures for filtering
    bytes32 private constant STAT_UPGRADED_SIG = keccak256("StatUpgraded(address,uint8,uint32,uint256)");
    bytes32 private constant SKILL_UNLOCKED_SIG = keccak256("SkillUnlocked(address,uint8,uint256)");
    bytes32 private constant DEPOSITED_SIG = keccak256("Deposited(address,uint256)");

    constructor(address _game, address _profile, address _treasury) {
        game = KingsomniGame(_game);
        profileAddress = _profile;
        treasuryAddress = _treasury;
    }

    /**
     * @dev Somnia Reactivity Engine invokes this function when subscribed events are emitted.
     */
    function _onEvent(
        address emitter,
        bytes32[] calldata eventTopics,
        bytes calldata data
    ) internal override {
        // --- REACTION 1: BOUNTY ON THE KING (CIRCULAR ECONOMY) ---
        // Triggered by upgrades in KingsomniProfile
        if (emitter == profileAddress) {
            if (eventTopics[0] == STAT_UPGRADED_SIG) {
                // Decode: statType (uint8), newLevel (uint32), cost (uint256)
                // player address is in eventTopics[1] (indexed)
                (, , uint256 cost) = abi.decode(data, (uint8, uint32, uint256));
                
                // Tell Game to sync 10% of this cost to the Bounty Pool
                game.syncBounty(cost);
            } 
            else if (eventTopics[0] == SKILL_UNLOCKED_SIG) {
                // Decode: skillType (uint8), cost (uint256)
                (, uint256 cost) = abi.decode(data, (uint8, uint256));
                
                // Skills also contribute to the Bounty
                game.syncBounty(cost);
            }
        }

        // --- REACTION 2: DYNAMIC WORLD STATE (GLOBAL BOSS) ---
        // Triggered by deposits/upgrades reaching the Treasury
        if (emitter == treasuryAddress && eventTopics[0] == DEPOSITED_SIG) {
            // Check real-time balance of Treasury on-chain
            uint256 currentBalance = treasuryAddress.balance;
            
            // Threshold for Global Boss: 20 STT (Adjustable)
            if (currentBalance >= 20 ether) {
                // Activate Global Boss across all game sessions autonomously
                game.toggleGlobalBoss(true);
            } else if (currentBalance < 10 ether) {
                // Deactivate if balance drops (e.g., after many claims)
                game.toggleGlobalBoss(false);
            }
        }
    }
}
