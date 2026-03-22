// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IKingsomniTreasury.sol";

contract KingsomniProfile {
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

    uint256 public baseUpgradeCost = 0.05 ether;
    uint256 public unlockSkillCost = 0.1 ether;

    event StatUpgraded(address indexed player, uint8 statType, uint32 newLevel, uint256 cost);
    event SkillUnlocked(address indexed player, uint8 skillType, uint256 cost);

    constructor(address treasuryAddress) {
        treasury = IKingsomniTreasury(treasuryAddress);
    }

    function upgradeStat(uint8 statType) external payable {
        if (msg.value < baseUpgradeCost) return;
        treasury.deposit{value: msg.value}();

        PlayerStats storage stats = profiles[msg.sender];
        uint32 newLevel = 1;

        if (statType == 0) {
            newLevel = ++stats.damageLevel;
        } else if (statType == 1) {
            newLevel = ++stats.healthLevel;
        } else if (statType == 2) {
            newLevel = ++stats.fireRateLevel;
        } else if (statType == 3) {
            stats.unlockFreeze = true;
            newLevel = ++stats.freezeLevel;
        } else if (statType == 4) {
            stats.unlockHeal = true;
            newLevel = ++stats.healLevel;
        } else if (statType == 5) {
            stats.unlockDamageBoost = true;
            newLevel = ++stats.damageBoostLevel;
        } else {
            return;
        }

        emit StatUpgraded(msg.sender, statType, newLevel, msg.value);
    }

    function unlockSkill(uint8 skillType) external payable {
        if (msg.value < unlockSkillCost) return;
        treasury.deposit{value: msg.value}();

        PlayerStats storage stats = profiles[msg.sender];
        if (skillType == 3) {
            stats.unlockFreeze = true;
        } else if (skillType == 4) {
            stats.unlockHeal = true;
        } else if (skillType == 5) {
            stats.unlockDamageBoost = true;
        } else {
            return;
        }

        emit SkillUnlocked(msg.sender, skillType, msg.value);
    }

    function getPlayerProfile(address player) external view returns (PlayerStats memory) {
        return profiles[player];
    }
}
