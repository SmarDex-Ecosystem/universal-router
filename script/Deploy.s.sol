// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { UniversalRouter } from "src/UniversalRouter/UniversalRouter.sol";

/**
 * @title DeployScript
 * @dev This script is a deploy script template that creates a new Contract instance
 */
contract Deploy is Script {
    function run() external returns (UniversalRouter UniversalRouter_) {
        // Broadcast transactions using the deployer address from the environment
        vm.startBroadcast(vm.envAddress("DEPLOYER_ADDRESS"));

        // Create a new Contract
        UniversalRouter_ = new UniversalRouter();

        // Stop using the deployer's private key
        vm.stopBroadcast();
    }
}
