// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IKingsomniTreasury
 * @notice Treasury interface used by profile and game modules.
 * @author Kingsomni Team
 * @dev Exposes only the minimal payable and payout methods required by integrations.
 */
interface IKingsomniTreasury {
    /**
     * @notice Deposits native token into treasury pool.
     */
    function deposit() external payable;
    /**
     * @notice Transfers claim reward from treasury to recipient.
     * @param to Recipient address.
     * @param amount Reward amount in wei.
     */
    function claimSTT(address to, uint256 amount) external;
    /**
     * @notice Transfers bounty payout from treasury to recipient.
     * @param to Recipient address.
     * @param amount Bounty amount in wei.
     */
    function payoutBounty(address to, uint256 amount) external;
}
