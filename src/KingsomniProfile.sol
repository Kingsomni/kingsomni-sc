// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IKingsomniTreasury.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KingsomniProfile is Ownable {
    IKingsomniTreasury public treasury;

    struct PlayerStats {
        uint32 damageLevel;
        uint32 healthLevel;
        uint32 fireRateLevel;
        bool unlockFreeze;
        uint32 freezeLevel;
        bool unlockHeal;
        uint32 healLevel;
        bool unlockDamageBoost;
        uint32 damageBoostLevel;
    }

    mapping(address => PlayerStats) public profiles;

    // Base upgrade cost
    uint256 public baseUpgradeCost = 0.05 ether; // 0.05 STT
    uint256 public unlockSkillCost = 0.1 ether;  // 0.1 STT

    event StatUpgraded(address indexed player, uint8 statType, uint32 newLevel, uint256 cost);
    event SkillUnlocked(address indexed player, uint8 skillType, uint256 cost);

    constructor(address treasuryAddress) Ownable(msg.sender) {
        treasury = IKingsomniTreasury(treasuryAddress);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        treasury = IKingsomniTreasury(newTreasury);
    }

    function setCosts(uint256 _baseUpgradeCost, uint256 _unlockSkillCost) external onlyOwner {
        baseUpgradeCost = _baseUpgradeCost;
        unlockSkillCost = _unlockSkillCost;
    }

    /// @notice Upgrade stat level. 
    /// 0: damage, 1: health, 2: fireRate, 3: freeze, 4: heal, 5: damageBoost
    function upgradeStat(uint8 statType) external payable {
        PlayerStats storage stats = profiles[msg.sender];
        uint32 currentLevel;

        if (statType == 0) currentLevel = stats.damageLevel;
        else if (statType == 1) currentLevel = stats.healthLevel;
        else if (statType == 2) currentLevel = stats.fireRateLevel;
        else if (statType == 3) { require(stats.unlockFreeze, "Skill not unlocked"); currentLevel = stats.freezeLevel; }
        else if (statType == 4) { require(stats.unlockHeal, "Skill not unlocked"); currentLevel = stats.healLevel; }
        else if (statType == 5) { require(stats.unlockDamageBoost, "Skill not unlocked"); currentLevel = stats.damageBoostLevel; }
        else revert("Invalid stat type");

        uint256 cost = baseUpgradeCost * (currentLevel + 1);
        require(msg.value == cost, "Incorrect STT amount");

        // Forward funds to treasury
        treasury.deposit{value: msg.value}();

        // Increase level
        if (statType == 0) stats.damageLevel += 1;
        else if (statType == 1) stats.healthLevel += 1;
        else if (statType == 2) stats.fireRateLevel += 1;
        else if (statType == 3) stats.freezeLevel += 1;
        else if (statType == 4) stats.healLevel += 1;
        else if (statType == 5) stats.damageBoostLevel += 1;

        emit StatUpgraded(msg.sender, statType, currentLevel + 1, cost);
    }

    /// @notice Unlock a skill
    /// 3: freeze, 4: heal, 5: damageBoost
    function unlockSkill(uint8 skillType) external payable {
        require(msg.value == unlockSkillCost, "Incorrect STT amount");
        PlayerStats storage stats = profiles[msg.sender];

        if (skillType == 3) {
            require(!stats.unlockFreeze, "Already unlocked");
            stats.unlockFreeze = true;
        } else if (skillType == 4) {
            require(!stats.unlockHeal, "Already unlocked");
            stats.unlockHeal = true;
        } else if (skillType == 5) {
            require(!stats.unlockDamageBoost, "Already unlocked");
            stats.unlockDamageBoost = true;
        } else {
            revert("Invalid skill type");
        }

        treasury.deposit{value: msg.value}();
        emit SkillUnlocked(msg.sender, skillType, unlockSkillCost);
    }

    function getPlayerProfile(address player) external view returns (PlayerStats memory) {
        return profiles[player];
    }
}
