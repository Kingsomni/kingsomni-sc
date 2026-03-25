// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IKingsomniTreasury.sol";

/**
 * @title KingsomniGame
 * @notice Core game contract for score aggregation, STT claims, and bounty logic.
 * @author Kingsomni Team
 * @dev This version is optimized for lightweight deployment on Somnia testnet.
 *      It tracks cumulative leaderboard data and routes reward transfers via treasury.
 */
contract KingsomniGame {
    bytes32 public constant REACTIVITY_ROLE = keccak256("REACTIVITY_ROLE");

    IKingsomniTreasury public treasury;
    address public backendSigner;

    bool public globalBossActive;
    uint256 public bountyPool;
    address public currentLeader;
    uint256 public highestScore;

    struct LeaderboardRecord {
        uint256 totalScore;
        uint256 totalKills;
        uint256 gamesPlayed;
    }

    mapping(address => LeaderboardRecord) public leaderboards;

    event ScoreSubmitted(address indexed player, uint256 scoreDelta, uint256 sttReward);
    event BountyClaimed(address indexed winner, uint256 amount);
    event GlobalBossToggled(bool active);

    /**
     * @notice Creates game module with treasury and backend signer references.
     * @dev Third constructor argument is intentionally unused to preserve script compatibility.
     * @param _treasury Treasury contract address.
     * @param _backendSigner Backend signer address used by off-chain stack.
     */
    constructor(address _treasury, address _backendSigner, address) {
        treasury = IKingsomniTreasury(_treasury);
        backendSigner = _backendSigner;
    }

    /**
     * @notice Placeholder role-grant function kept for deploy-flow compatibility.
     * @dev No state changes are performed in this lightweight contract.
     */
    function grantRole(bytes32, address) external {}

    /**
     * @notice Adds a percentage of upgrade value into the bounty pool.
     * @param upgradeCost Upgrade payment amount in wei.
     */
    function syncBounty(uint256 upgradeCost) external {
        bountyPool += (upgradeCost * 10) / 100;
    }

    /**
     * @notice Toggles global boss state.
     * @param _active New global boss state.
     */
    function toggleGlobalBoss(bool _active) external {
        globalBossActive = _active;
        emit GlobalBossToggled(_active);
    }

    /**
     * @notice Updates treasury contract pointer.
     * @param newTreasury New treasury address.
     */
    function setTreasury(address newTreasury) external {
        treasury = IKingsomniTreasury(newTreasury);
    }

    /**
     * @notice Updates backend signer pointer used by surrounding app stack.
     * @param newSigner New backend signer address.
     */
    function setBackendSigner(address newSigner) external {
        backendSigner = newSigner;
    }

    /**
     * @notice Applies session score stats and optionally claims STT reward.
     * @dev Also handles top-score leader tracking and bounty payout transfer.
     * @param scoreDelta Score increment for caller.
     * @param killsDelta Kill increment for caller.
     * @param sttReward Reward amount in wei to claim from treasury.
     */
    function claimSTTAndScore(uint256 scoreDelta, uint256 killsDelta, uint256 sttReward, uint256, bytes calldata)
        external
    {
        LeaderboardRecord storage record = leaderboards[msg.sender];
        record.totalScore += scoreDelta;
        record.totalKills += killsDelta;
        record.gamesPlayed += 1;

        if (record.totalScore > highestScore) {
            if (bountyPool > 0 && currentLeader != address(0) && msg.sender != currentLeader) {
                uint256 reward = bountyPool;
                bountyPool = 0;
                treasury.payoutBounty(msg.sender, reward);
                emit BountyClaimed(msg.sender, reward);
            }
            highestScore = record.totalScore;
            currentLeader = msg.sender;
        }

        if (sttReward > 0) {
            treasury.claimSTT(msg.sender, sttReward);
        }

        emit ScoreSubmitted(msg.sender, scoreDelta, sttReward);
    }

    /**
     * @notice Admin-style helper to update player leaderboard totals.
     * @dev Keeps compatibility with legacy integrations that push aggregated values.
     * @param player Target player address.
     * @param scoreAmount Score increment in wei-style integer units.
     * @param transactionAmount Games-played increment.
     */
    function updatePlayerData(address player, uint256 scoreAmount, uint256 transactionAmount) external {
        LeaderboardRecord storage record = leaderboards[player];
        record.totalScore += scoreAmount;
        record.gamesPlayed += transactionAmount;

        if (record.totalScore > highestScore) {
            highestScore = record.totalScore;
            currentLeader = player;
        }

        emit ScoreSubmitted(player, scoreAmount, 0);
    }
}
