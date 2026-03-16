// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IKingsomniTreasury.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract KingsomniGame is Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    IKingsomniTreasury public treasury;
    address public backendSigner;

    struct LeaderboardRecord {
        uint256 totalScore;
        uint256 totalKills;
        uint256 gamesPlayed;
    }

    mapping(address => LeaderboardRecord) public leaderboards;
    mapping(uint256 => bool) public usedNonces;

    event ScoreSubmitted(address indexed player, uint256 scoreDelta, uint256 sttReward);
    event SignerUpdated(address newSigner);

    constructor(address _treasury, address _backendSigner) Ownable(msg.sender) {
        treasury = IKingsomniTreasury(_treasury);
        backendSigner = _backendSigner;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        treasury = IKingsomniTreasury(newTreasury);
    }

    function setBackendSigner(address newSigner) external onlyOwner {
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
    ) external onlyOwner {
        LeaderboardRecord storage record = leaderboards[player];
        record.totalScore += scoreAmount;
        record.gamesPlayed += transactionAmount;
        emit ScoreSubmitted(player, scoreAmount, 0);
    }
}
