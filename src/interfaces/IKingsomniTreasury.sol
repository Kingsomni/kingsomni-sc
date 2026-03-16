// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IKingsomniTreasury {
    function deposit() external payable;
    function claimSTT(address to, uint256 amount) external;
    function payoutBounty(address to, uint256 amount) external;
}
