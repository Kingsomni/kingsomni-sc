// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IKingsomniTreasury.sol";

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

    constructor(address _treasury, address _backendSigner, address) {
        treasury = IKingsomniTreasury(_treasury);
        backendSigner = _backendSigner;
    }

    function grantRole(bytes32, address) external {}

    function syncBounty(uint256 upgradeCost) external {
        bountyPool += (upgradeCost * 10) / 100;
    }

    function toggleGlobalBoss(bool _active) external {
        globalBossActive = _active;
        emit GlobalBossToggled(_active);
    }

    function setTreasury(address newTreasury) external {
        treasury = IKingsomniTreasury(newTreasury);
    }

    function setBackendSigner(address newSigner) external {
        backendSigner = newSigner;
    }

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
