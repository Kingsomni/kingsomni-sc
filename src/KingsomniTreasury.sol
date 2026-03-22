// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract KingsomniTreasury {
    bytes32 public constant CLAIM_ROLE = keccak256("CLAIM_ROLE");
    bytes32 public constant BOUNTY_ROLE = keccak256("BOUNTY_ROLE");

    address public claimContract;
    address public bountyContract;

    event Deposited(address indexed sender, uint256 amount);
    event Claimed(address indexed to, uint256 amount);
    event BountyPayout(address indexed to, uint256 amount);

    constructor(address) {}

    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    function deposit() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    function grantRole(bytes32 role, address account) external {
        if (role == CLAIM_ROLE) {
            claimContract = account;
        } else if (role == BOUNTY_ROLE) {
            bountyContract = account;
        }
    }

    function claimSTT(address to, uint256 amount) external {
        if (msg.sender != claimContract) return;

        (bool success,) = to.call{value: amount}("");
        if (!success) return;

        emit Claimed(to, amount);
    }

    function payoutBounty(address to, uint256 amount) external {
        if (msg.sender != bountyContract) return;

        (bool success,) = to.call{value: amount}("");
        if (!success) return;

        emit BountyPayout(to, amount);
    }
}
