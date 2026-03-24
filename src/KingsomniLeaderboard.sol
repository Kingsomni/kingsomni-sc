// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract KingsomniLeaderboard is Ownable, EIP712 {
    using ECDSA for bytes32;

    struct LeaderboardRecord {
        uint256 totalScore;
        uint256 totalKills;
        uint256 gamesPlayed;
        uint256 bestSingleScore;
    }

    struct SubmitScoreRequest {
        address player;
        uint256 scoreDelta;
        uint256 killsDelta;
        bytes32 matchId;
        uint256 deadline;
    }

    bytes32 public constant SUBMIT_TYPEHASH =
        keccak256("SubmitScore(address player,uint256 scoreDelta,uint256 killsDelta,bytes32 matchId,uint256 deadline)");

    address public backendSigner;
    uint256 public highestScore;
    address public currentLeader;

    mapping(address => LeaderboardRecord) private _leaderboards;
    mapping(address => bool) private _isRegisteredPlayer;
    address[] private _players;
    mapping(bytes32 => bool) public usedMatchIds;

    event ScoreSubmitted(address indexed player, uint256 scoreDelta, uint256 killsDelta, bytes32 indexed matchId);
    event PlayerRegistered(address indexed player);
    event BackendSignerUpdated(address indexed previousSigner, address indexed newSigner);

    error InvalidSigner();
    error InvalidPlayer();
    error EmptySubmission();
    error SignatureExpired();
    error MatchAlreadySubmitted();
    error ZeroAddress();

    constructor(address initialOwner, address initialBackendSigner) Ownable() EIP712("KingsomniLeaderboard", "1") {
        if (initialOwner == address(0) || initialBackendSigner == address(0)) revert ZeroAddress();
        if (initialOwner != owner()) {
            _transferOwnership(initialOwner);
        }
        backendSigner = initialBackendSigner;
    }

    function setBackendSigner(address newSigner) external onlyOwner {
        if (newSigner == address(0)) revert ZeroAddress();
        address previousSigner = backendSigner;
        backendSigner = newSigner;
        emit BackendSignerUpdated(previousSigner, newSigner);
    }

    function submitScore(SubmitScoreRequest calldata request, bytes calldata signature) external {
        if (request.player != msg.sender) revert InvalidPlayer();
        if (request.scoreDelta == 0 && request.killsDelta == 0) revert EmptySubmission();
        if (block.timestamp > request.deadline) revert SignatureExpired();
        if (usedMatchIds[request.matchId]) revert MatchAlreadySubmitted();

        bytes32 digest = _hashTypedDataV4(_buildStructHash(request));
        address recoveredSigner = ECDSA.recover(digest, signature);
        if (recoveredSigner != backendSigner) revert InvalidSigner();

        usedMatchIds[request.matchId] = true;
        _registerPlayerIfNeeded(msg.sender);

        LeaderboardRecord storage record = _leaderboards[msg.sender];
        record.totalScore += request.scoreDelta;
        record.totalKills += request.killsDelta;
        record.gamesPlayed += 1;

        if (request.scoreDelta > record.bestSingleScore) {
            record.bestSingleScore = request.scoreDelta;
        }

        if (record.totalScore > highestScore) {
            highestScore = record.totalScore;
            currentLeader = msg.sender;
        }

        emit ScoreSubmitted(msg.sender, request.scoreDelta, request.killsDelta, request.matchId);
    }

    function leaderboards(address player)
        external
        view
        returns (uint256 totalScore, uint256 totalKills, uint256 gamesPlayed)
    {
        LeaderboardRecord storage record = _leaderboards[player];
        return (record.totalScore, record.totalKills, record.gamesPlayed);
    }

    function getLeaderboardRecord(address player) external view returns (LeaderboardRecord memory) {
        return _leaderboards[player];
    }

    function getPlayersCount() external view returns (uint256) {
        return _players.length;
    }

    function getPlayers(uint256 offset, uint256 limit) external view returns (address[] memory playersPage) {
        uint256 totalPlayers = _players.length;
        if (offset >= totalPlayers || limit == 0) {
            return new address[](0);
        }

        uint256 end = offset + limit;
        if (end > totalPlayers) {
            end = totalPlayers;
        }

        uint256 size = end - offset;
        playersPage = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            playersPage[i] = _players[offset + i];
        }
    }

    function isRegisteredPlayer(address player) external view returns (bool) {
        return _isRegisteredPlayer[player];
    }

    function hashSubmitScore(SubmitScoreRequest calldata request) external view returns (bytes32) {
        return _hashTypedDataV4(_buildStructHash(request));
    }

    function _buildStructHash(SubmitScoreRequest calldata request) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                SUBMIT_TYPEHASH,
                request.player,
                request.scoreDelta,
                request.killsDelta,
                request.matchId,
                request.deadline
            )
        );
    }

    function _registerPlayerIfNeeded(address player) private {
        if (_isRegisteredPlayer[player]) return;
        _isRegisteredPlayer[player] = true;
        _players.push(player);
        emit PlayerRegistered(player);
    }
}
