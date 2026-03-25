// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IKingsomniTreasury.sol";

/**
 * @title KingsomniProfile
 * @notice Player progression contract for upgrades and skill unlocks.
 * @author Kingsomni Team
 * @dev Upgrade and unlock payments are forwarded to KingsomniTreasury.
 *      Profile data is kept minimal so game state can be read quickly by FE and BE.
 */
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

    /**
     * @notice Creates profile module connected to treasury.
     * @param treasuryAddress Treasury contract address receiving upgrade fees.
     */
    constructor(address treasuryAddress) {
        treasury = IKingsomniTreasury(treasuryAddress);
    }

    /**
     * @notice Upgrades player stat or skill level using STT payment.
     * @dev `statType` mapping:
     *      0=Damage, 1=Health, 2=FireRate, 3=Freeze, 4=Heal, 5=DamageBoost.
     *      Invalid types or insufficient payment return silently in this lightweight version.
     * @param statType Encoded stat/skill identifier to upgrade.
     */
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

    /**
     * @notice Unlocks a skill branch using STT payment.
     * @dev `skillType` mapping:
     *      3=Freeze, 4=Heal, 5=DamageBoost.
     *      Invalid types or insufficient payment return silently.
     * @param skillType Encoded skill identifier to unlock.
     */
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

    /**
     * @notice Returns full on-chain profile state for a player.
     * @param player Player wallet address.
     * @return Current stored profile struct.
     */
    function getPlayerProfile(address player) external view returns (PlayerStats memory) {
        return profiles[player];
    }
}
