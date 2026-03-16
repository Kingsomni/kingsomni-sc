// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract KingsomniTreasury is AccessControl {
    bytes32 public constant CLAIM_ROLE = keccak256("CLAIM_ROLE");

    event Deposited(address indexed sender, uint256 amount);
    event Claimed(address indexed to, uint256 amount);

    constructor(address defaultAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    /// @notice Receive native STT to fund the reward pool
    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Manually deposit STT
    function deposit() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Withdraw STT to user, only callable by CLAIM_ROLE (Game Contract)
    function claimSTT(address to, uint256 amount) external onlyRole(CLAIM_ROLE) {
        require(address(this).balance >= amount, "Treasury: Insufficient funds");
        (bool success, ) = to.call{value: amount}("");
        require(success, "Treasury: Transfer failed");
        emit Claimed(to, amount);
    }

    /// @notice Admin rescue function
    function rescueFunds(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(this).balance >= amount, "Treasury: Insufficient funds");
        (bool success, ) = to.call{value: amount}("");
        require(success, "Treasury: Rescue failed");
    }
}
