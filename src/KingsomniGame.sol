// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IKingsomniTreasury.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract KingsomniGame is AccessControl {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    bytes32 public constant REACTIVITY_ROLE = keccak256("REACTIVITY_ROLE");

    IKingsomniTreasury public treasury;
    address public backendSigner;

    // Reactivity State
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
    mapping(uint256 => bool) public usedNonces;

    event ScoreSubmitted(address indexed player, uint256 scoreDelta, uint256 sttReward);
    event BountyClaimed(address indexed winner, uint256 amount);
    event GlobalBossToggled(bool active);
    event BountySynced(uint256 addedAmount, uint256 totalPool);
    event SignerUpdated(address newSigner);

    constructor(address _treasury, address _backendSigner, address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        treasury = IKingsomniTreasury(_treasury);
        backendSigner = _backendSigner;
    }

    /// @notice Sync bounty pool (triggered by Reactivity from KingsomniProfile events)
    function syncBounty(uint256 upgradeCost) external onlyRole(REACTIVITY_ROLE) {
        uint256 contribution = (upgradeCost * 10) / 100;
        bountyPool += contribution;
        emit BountySynced(contribution, bountyPool);
    }

    /// @notice Toggle global boss (triggered by Reactivity from Treasury balance)
    function toggleGlobalBoss(bool _active) external onlyRole(REACTIVITY_ROLE) {
        globalBossActive = _active;
        emit GlobalBossToggled(_active);
    }

    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = IKingsomniTreasury(newTreasury);
    }

    function setBackendSigner(address newSigner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        backendSigner = newSigner;
        emit SignerUpdated(newSigner);
    }

    /// @notice Update player data and claim STT drop directly
    function claimSTTAndScore(
        uint256 scoreDelta,
        uint256 killsDelta,
        uint256 sttReward,
        uint256 nonce,
        bytes memory signature
    ) external {
        require(!usedNonces[nonce], "Nonce already used");
        usedNonces[nonce] = true;

        // Message to sign: msg.sender, scoreDelta, killsDelta, sttReward, nonce, address(this)
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                msg.sender,
                scoreDelta,
                killsDelta,
                sttReward,
                nonce,
                address(this)
            )
        );
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        
        address recoveredSigner = ethSignedMessageHash.recover(signature);
        require(recoveredSigner == backendSigner, "Invalid signature");

        // Update score
        LeaderboardRecord storage record = leaderboards[msg.sender];
        record.totalScore += scoreDelta;
        record.totalKills += killsDelta;
        record.gamesPlayed += 1;

        // --- Bounty Logic (Reactivity Check) ---
        if (record.totalScore > highestScore) {
            // New Leader!
            if (bountyPool > 0 && currentLeader != address(0) && msg.sender != currentLeader) {
                uint256 reward = bountyPool;
                bountyPool = 0;
                treasury.payoutBounty(msg.sender, reward);
                emit BountyClaimed(msg.sender, reward);
            }
            highestScore = record.totalScore;
            currentLeader = msg.sender;
        }

        // Reward STT if any
        if (sttReward > 0) {
            treasury.claimSTT(msg.sender, sttReward);
        }

        emit ScoreSubmitted(msg.sender, scoreDelta, sttReward);
    }

    // Existing minimal Leaderboard function for backward compatibility
    function updatePlayerData(
        address player,
        uint256 scoreAmount,
        uint256 transactionAmount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
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
