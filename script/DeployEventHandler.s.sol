// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/KingsomniEventHandler.sol";

contract DeployEventHandler is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address game = vm.envAddress("GAME_CONTRACT_ADDRESS");
        address profile = vm.envAddress("PROFILE_CONTRACT_ADDRESS");
        address treasury = vm.envAddress("TREASURY_CONTRACT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        KingsomniEventHandler handler = new KingsomniEventHandler(game, profile, treasury);

        vm.stopBroadcast();

        console.log("-----------------------------------------");
        console.log("EVENT HANDLER DEPLOYED");
        console.log("Handler:", address(handler));
        console.log("Game:", game);
        console.log("Profile:", profile);
        console.log("Treasury:", treasury);
        console.log("-----------------------------------------");
    }
}

