// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SomniaEventHandler} from "@somnia-chain/reactivity-contracts/contracts/SomniaEventHandler.sol";

/**
 * @title IEventGameHook
 * @notice Minimal game hook interface used by the Somnia reactivity event handler.
 * @author Kingsomni Team
 * @dev Keeps the event handler decoupled from full game contract implementation details.
 */
interface IEventGameHook {
    /**
     * @notice Sets global boss active state in game contract.
     * @param active New boss state.
     */
    function toggleGlobalBoss(bool active) external;
    /**
     * @notice Reads current global boss state.
     * @return Current boss activity flag.
     */
    function globalBossActive() external view returns (bool);
    /**
     * @notice Adds value-derived contribution to bounty pool.
     * @param upgradeCost Upgrade payment amount in wei.
     */
    function syncBounty(uint256 upgradeCost) external;
}

/**
 * @title KingsomniEventHandler
 * @notice Somnia Reactivity handler that converts emitted events into game-state updates.
 * @author Kingsomni Team
 * @dev Listens to treasury and profile events to:
 *      1) toggle global boss mode with hysteresis thresholds
 *      2) sync upgrade-based bounty growth into the game contract
 */
contract KingsomniEventHandler is SomniaEventHandler {
    bytes32 private constant DEPOSITED_TOPIC = keccak256("Deposited(address,uint256)");
    bytes32 private constant CLAIMED_TOPIC = keccak256("Claimed(address,uint256)");
    bytes32 private constant STAT_UPGRADED_TOPIC = keccak256("StatUpgraded(address,uint8,uint32,uint256)");
    uint256 private constant STAT_UPGRADED_DATA_LENGTH = 96;
    uint256 public constant BOSS_ON_THRESHOLD = 10 ether;
    uint256 public constant BOSS_OFF_THRESHOLD = 7 ether;

    IEventGameHook public immutable game;
    address public immutable profile;
    address public immutable treasury;

    error ZeroAddress();

    /**
     * @notice Creates reactivity handler with linked contract addresses.
     * @param _game Game contract address implementing `IEventGameHook`.
     * @param _profile Profile contract emitting upgrade events.
     * @param _treasury Treasury contract emitting deposit/claim events.
     */
    constructor(address _game, address _profile, address _treasury) {
        if (_game == address(0) || _profile == address(0) || _treasury == address(0)) {
            revert ZeroAddress();
        }
        game = IEventGameHook(_game);
        profile = _profile;
        treasury = _treasury;
    }

    /**
     * @notice Handles Somnia Reactivity callbacks for subscribed events.
     * @dev Reacts to:
     *      - treasury `Deposited` / `Claimed` events for boss toggle hysteresis
     *      - profile `StatUpgraded` events for bounty pool synchronization
     * @param emitter Address of event-emitting contract.
     * @param eventTopics Event topic array where index 0 is signature hash.
     * @param eventData ABI-encoded non-indexed event payload.
     */
    function _onEvent(address emitter, bytes32[] calldata eventTopics, bytes calldata eventData) internal override {
        if (eventTopics.length == 0) return;

        bytes32 topic0 = eventTopics[0];

        // Feature 4: treasury economy updates global boss state.
        if (emitter == treasury && (topic0 == DEPOSITED_TOPIC || topic0 == CLAIMED_TOPIC)) {
            bool isActive = game.globalBossActive();
            uint256 treasuryBalance = treasury.balance;

            // Hysteresis to avoid rapid toggling near the threshold.
            if (!isActive && treasuryBalance >= BOSS_ON_THRESHOLD) {
                game.toggleGlobalBoss(true);
            } else if (isActive && treasuryBalance <= BOSS_OFF_THRESHOLD) {
                game.toggleGlobalBoss(false);
            }
            return;
        }

        // Feature 5: profile upgrades increase bounty pool through game.syncBounty(cost).
        if (emitter == profile && topic0 == STAT_UPGRADED_TOPIC) {
            // Non-indexed payload: (uint8 statType, uint32 newLevel, uint256 cost)
            if (eventData.length != STAT_UPGRADED_DATA_LENGTH) return;
            (,, uint256 cost) = abi.decode(eventData, (uint8, uint32, uint256));
            if (cost > 0) {
                game.syncBounty(cost);
            }
            return;
        }
    }
}
