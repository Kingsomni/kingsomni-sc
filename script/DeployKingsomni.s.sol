// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/KingsomniTreasury.sol";
import "../src/KingsomniProfile.sol";
import "../src/KingsomniGame.sol";
import "../src/KingsomniEventHandler.sol";
import "../src/KingsomniLeaderboard.sol";

contract DeployKingsomni is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address backendSigner = vm.envOr("BACKEND_SIGNER_ADDRESS", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        // --- PHASE 1: DEPLOYMENT ---

        // 1. Deploy Treasury (Bank/Pool)
        KingsomniTreasury treasury = new KingsomniTreasury(deployerAddress);
        console.log("KingsomniTreasury deployed at:", address(treasury));

        // 2. Deploy Profile (Stats & Skills)
        KingsomniProfile profile = new KingsomniProfile(address(treasury));
        console.log("KingsomniProfile deployed at:", address(profile));

        // 3. Deploy Game (Leaderboard & Claims)
        // Pass deployerAddress as the initial admin
        KingsomniGame game = new KingsomniGame(address(treasury), backendSigner, deployerAddress);
        console.log("KingsomniGame deployed at:", address(game));

        // 4. Deploy EventHandler (The Reactivity Brain)
        KingsomniEventHandler handler = new KingsomniEventHandler(address(game), address(profile), address(treasury));
        console.log("KingsomniEventHandler deployed at:", address(handler));

        // 5. Deploy dedicated leaderboard (signed submission model)
        KingsomniLeaderboard leaderboard = new KingsomniLeaderboard(deployerAddress, backendSigner);
        console.log("KingsomniLeaderboard deployed at:", address(leaderboard));

        // --- PHASE 2: ROLE CONFIGURATION ---

        // A. Treasury Roles
        // Grant CLAIM_ROLE to Game contract (to pay rewards to players)
        treasury.grantRole(treasury.CLAIM_ROLE(), address(game));
        // Grant BOUNTY_ROLE to Game contract (to pay bounty rewards)
        treasury.grantRole(treasury.BOUNTY_ROLE(), address(game));
        console.log("Configured Treasury roles for Game contract");

        // B. Game Roles
        // Grant REACTIVITY_ROLE to EventHandler (to sync bounty & boss state)
        game.grantRole(game.REACTIVITY_ROLE(), address(handler));
        console.log("Granted REACTIVITY_ROLE to EventHandler");

        // --- PHASE 3: SUBSCRIPTION FUNDING (Optional Tip) ---
        // Note: You still need to manually create the subscription via Somnia SDK
        // using a wallet with at least 32 SOM balance.

        vm.stopBroadcast();

        console.log("-----------------------------------------");
        console.log("DEPLOYMENT COMPLETE");
        console.log("Treasury:", address(treasury));
        console.log("Profile:", address(profile));
        console.log("Game:", address(game));
        console.log("EventHandler:", address(handler));
        console.log("Leaderboard:", address(leaderboard));
        console.log("BackendSigner:", backendSigner);
        console.log("-----------------------------------------");
    }
}
