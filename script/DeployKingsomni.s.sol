// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/KingsomniTreasury.sol";
import "../src/KingsomniProfile.sol";
import "../src/KingsomniGame.sol";

contract DeployKingsomni is Script {
    function run() external {
        // Read private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address backendSigner = vm.envAddress("BACKEND_SIGNER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Treasury
        // Deployer will be the default admin
        KingsomniTreasury treasury = new KingsomniTreasury(vm.addr(deployerPrivateKey));
        console.log("KingsomniTreasury deployed at:", address(treasury));

        // 2. Deploy Profile
        KingsomniProfile profile = new KingsomniProfile(address(treasury));
        console.log("KingsomniProfile deployed at:", address(profile));

        // 3. Deploy Game
        KingsomniGame game = new KingsomniGame(address(treasury), backendSigner);
        console.log("KingsomniGame deployed at:", address(game));

        // 4. Grant CLAIM_ROLE to Game contract so it can withdraw STT for players
        treasury.grantRole(treasury.CLAIM_ROLE(), address(game));
        console.log("Granted CLAIM_ROLE to Game contract");

        vm.stopBroadcast();
    }
}
