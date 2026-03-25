// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title KingsomniTreasury
 * @notice Treasury vault that stores STT liquidity and handles reward and bounty payouts.
 * @author Kingsomni Team
 * @dev This contract is intentionally lightweight for Somnia testnet reliability.
 *      It supports direct deposits, CLAIM_ROLE payouts, and BOUNTY_ROLE payouts.
 */
contract KingsomniTreasury {
    bytes32 public constant CLAIM_ROLE = keccak256("CLAIM_ROLE");
    bytes32 public constant BOUNTY_ROLE = keccak256("BOUNTY_ROLE");

    address public claimContract;
    address public bountyContract;

    event Deposited(address indexed sender, uint256 amount);
    event Claimed(address indexed to, uint256 amount);
    event BountyPayout(address indexed to, uint256 amount);

    /**
     * @notice Initializes treasury deployment.
     * @dev The constructor keeps a placeholder argument for compatibility with existing scripts.
     */
    constructor(address) {}

    /**
     * @notice Accepts plain native token transfers into treasury.
     * @dev Emits {Deposited} so the event handler can react to balance changes.
     */
    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Deposits native token into treasury via explicit function call.
     * @dev Emits {Deposited} for downstream reactivity processing.
     */
    function deposit() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Assigns payout authority contracts for claim and bounty operations.
     * @dev No access control is enforced in this lightweight version.
     * @param role Role selector (`CLAIM_ROLE` or `BOUNTY_ROLE`).
     * @param account Contract address that receives the selected role.
     */
    function grantRole(bytes32 role, address account) external {
        if (role == CLAIM_ROLE) {
            claimContract = account;
        } else if (role == BOUNTY_ROLE) {
            bountyContract = account;
        }
    }

    /**
     * @notice Pays STT reward from treasury to a player.
     * @dev Silently returns when caller is unauthorized or low-level transfer fails.
     * @param to Recipient address.
     * @param amount Reward amount in wei.
     */
    function claimSTT(address to, uint256 amount) external {
        if (msg.sender != claimContract) return;

        (bool success,) = to.call{value: amount}("");
        if (!success) return;

        emit Claimed(to, amount);
    }

    /**
     * @notice Pays bounty amount from treasury to a winner.
     * @dev Silently returns when caller is unauthorized or low-level transfer fails.
     * @param to Recipient address.
     * @param amount Bounty amount in wei.
     */
    function payoutBounty(address to, uint256 amount) external {
        if (msg.sender != bountyContract) return;

        (bool success,) = to.call{value: amount}("");
        if (!success) return;

        emit BountyPayout(to, amount);
    }
}
