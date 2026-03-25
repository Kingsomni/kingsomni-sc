// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title KingsomniLeaderboard
 * @notice Dedicated signed-submission leaderboard for Kingsomni sessions.
 * @author Kingsomni Team
 * @dev Players submit scores on-chain, but payload validity is enforced using
 *      EIP-712 signatures from a backend signer to improve anti-cheat guarantees.
 */
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

    /**
     * @notice Deploys leaderboard with owner and backend signer.
     * @param initialOwner Address assigned as contract owner.
     * @param initialBackendSigner Address authorized to sign score submissions.
     */
    constructor(address initialOwner, address initialBackendSigner) Ownable() EIP712("KingsomniLeaderboard", "1") {
        if (initialOwner == address(0) || initialBackendSigner == address(0)) revert ZeroAddress();
        if (initialOwner != owner()) {
            _transferOwnership(initialOwner);
        }
        backendSigner = initialBackendSigner;
    }

    /**
     * @notice Updates backend signer used for EIP-712 score verification.
     * @param newSigner New signer address.
     */
    function setBackendSigner(address newSigner) external onlyOwner {
        if (newSigner == address(0)) revert ZeroAddress();
        address previousSigner = backendSigner;
        backendSigner = newSigner;
        emit BackendSignerUpdated(previousSigner, newSigner);
    }

    /**
     * @notice Submits a score update signed by backend verifier.
     * @dev Prevents replay via `matchId`, checks signer, and updates cumulative stats.
     * @param request Signed payload containing score and metadata.
     * @param signature EIP-712 backend signature over `request`.
     */
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

    /**
     * @notice Reads cumulative leaderboard values for a player.
     * @param player Player wallet address.
     * @return totalScore Total accumulated score.
     * @return totalKills Total accumulated kills.
     * @return gamesPlayed Total number of submitted sessions.
     */
    function leaderboards(address player)
        external
        view
        returns (uint256 totalScore, uint256 totalKills, uint256 gamesPlayed)
    {
        LeaderboardRecord storage record = _leaderboards[player];
        return (record.totalScore, record.totalKills, record.gamesPlayed);
    }

    /**
     * @notice Returns full leaderboard record including best single score.
     * @param player Player wallet address.
     * @return Player leaderboard struct.
     */
    function getLeaderboardRecord(address player) external view returns (LeaderboardRecord memory) {
        return _leaderboards[player];
    }

    /**
     * @notice Returns total registered player count.
     * @return Number of players stored in leaderboard index.
     */
    function getPlayersCount() external view returns (uint256) {
        return _players.length;
    }

    /**
     * @notice Returns a paginated list of registered player addresses.
     * @param offset Start index in player array.
     * @param limit Maximum number of players to return.
     * @return playersPage Slice of player addresses.
     */
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

    /**
     * @notice Checks whether a wallet is already tracked in players index.
     * @param player Player wallet address.
     * @return True when player has submitted at least one valid score.
     */
    function isRegisteredPlayer(address player) external view returns (bool) {
        return _isRegisteredPlayer[player];
    }

    /**
     * @notice Returns the exact EIP-712 digest used for score signature verification.
     * @param request Score submission payload.
     * @return EIP-712 typed data digest.
     */
    function hashSubmitScore(SubmitScoreRequest calldata request) external view returns (bytes32) {
        return _hashTypedDataV4(_buildStructHash(request));
    }

    /**
     * @notice Builds struct hash for `SubmitScoreRequest`.
     * @param request Score submission payload.
     * @return keccak256 hash of typed struct encoding.
     */
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

    /**
     * @notice Registers player into pagination index if first valid submission.
     * @param player Player wallet address.
     */
    function _registerPlayerIfNeeded(address player) private {
        if (_isRegisteredPlayer[player]) return;
        _isRegisteredPlayer[player] = true;
        _players.push(player);
        emit PlayerRegistered(player);
    }
}
