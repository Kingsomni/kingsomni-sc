# Kingsomni Smart Contracts ⚔️

**Kingsomni** is a high-performance decentralized tower defense game built on the **Somnia Network**. This repository contains the core on-chain logic, leveraging Somnia's unique **On-Chain Reactivity** to create a living, breathing game economy where player actions and treasury fluctuations trigger real-time gameplay changes.

---

## 🚀 The Somnia Edge: On-Chain Reactivity

Kingsomni pushes the boundaries of blockchain gaming by using Somnia's **Reactivity Precompile**. Unlike traditional dApps that require off-chain bots or manual intervention, Kingsomni's world state evolves automatically based on event-driven triggers.

### 1. Automated Global Boss Mode (Economic Hysteresis)
The `KingsomniEventHandler` monitors the `KingsomniTreasury` balance in real-time. 
- **Trigger ON**: When the treasury reaches **10 STT**, the Reactivity Handler automatically triggers `toggleGlobalBoss(true)` in the Game contract.
- **Trigger OFF**: If the balance falls below **7 STT**, it triggers `toggleGlobalBoss(false)`.
- **Result**: The game world becomes more dangerous (and rewarding) based on the actual health of the ecosystem, without any backend "cron jobs."

### 2. Real-time Bounty Synchronization
Every time a player upgrades their stats in `KingsomniProfile`, a `StatUpgraded` event is emitted. The Reactivity Handler intercepts this event and instantly calls `syncBounty()` in the `KingsomniGame` contract, redirecting 10% of the upgrade cost into the **Global Bounty Pool**.

---

## 📜 Contract Architecture

### 1. `KingsomniGame.sol` (Core Logic)
The central hub for game state and rewards.
- `claimSTTAndScore(...)`: Validates session data and distributes STT rewards from the treasury.
- `syncBounty(uint256)`: Increases the bounty pool based on economic activity.
- `toggleGlobalBoss(bool)`: Updates the global state (triggered via Reactivity).
- `bountyPool`: Tracks the accumulated STT rewards for the current top player.

### 2. `KingsomniLeaderboard.sol` (Anti-Cheat Security)
A high-integrity leaderboard system using **EIP-712 Typed Data Signatures**.
- `submitScore(...)`: Accepts score updates only if accompanied by a valid signature from the authorized Backend Signer. This prevents players from "spoofing" high scores.
- `getLeaderboardRecord(address)`: Returns comprehensive player stats (Total Score, Kills, Games Played, Best Score).
- `getPlayers(offset, limit)`: Efficient paginated access for frontend display.

### 3. `KingsomniProfile.sol` (Player Progression)
Manages persistent RPG-style character upgrades.
- `upgradeStat(uint8 statType)`: Upgrades Damage, Health, or Fire Rate. Fees are sent directly to the Treasury.
- `unlockSkill(uint8 skillType)`: Unlocks advanced abilities like **Freeze**, **Heal**, or **Damage Boost**.
- `getPlayerProfile(address)`: Fast view-function for character stats.

### 4. `KingsomniTreasury.sol` (The Vault)
A secure liquidity hub for the ecosystem.
- `deposit()`: Receives STT from upgrades and game fees.
- `claimSTT(address, uint256)`: Facilitates reward payouts (authorized for the Game contract).
- `payoutBounty(address, uint256)`: Distributes the Bounty Pool to champions.

### 5. `KingsomniEventHandler.sol` (Reactivity Handler)
The "brain" of the automated ecosystem, inheriting from `SomniaEventHandler`.
- `_onEvent(...)`: The internal callback that processes subscribed events from the Treasury and Profile contracts to drive game state changes.

---

## 🛠 Tech Stack & Tools
- **Language**: Solidity ^0.8.20
- **Framework**: Foundry (for development/testing)
- **Library**: OpenZeppelin (Access Control, ECDSA, EIP-712)
- **Reactivity SDK**: `@somnia-chain/reactivity` for subscription management.

---

## 🔧 Setup & Deployment

### Environment Configuration
Ensure your `.env` contains:
```bash
PRIVATE_KEY=your_private_key
RPC_URL=https://dream-rpc.somnia.network
TREASURY_ADDRESS=...
GAME_ADDRESS=...
PROFILE_ADDRESS=...
HANDLER_ADDRESS=...
```

### Managing Subscriptions
To activate the Reactivity features, you must subscribe the Handler to the Emitters:
1. **Setup Subscriptions**:
   ```bash
   cd scripts-subscribe-ts
   npm install
   node setup-subscription.mjs
   ```
2. **Verify Subscriptions**:
   ```bash
   node list-subscription-ids.mjs
   ```

---

## 🏆 Hackathon Highlights
- **Seamless Automation**: Using Somnia's Reactivity to replace centralized backend logic.
- **Fair Play**: EIP-712 signatures ensure on-chain leaderboard integrity.
- **Circular Economy**: Fees from upgrades directly fuel the Bounty Pool and the Global Boss mechanism.
