// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { Contract } from "src/Contract.sol";

/**
 * @title DeployScript
 * @dev This script is a deploy script template that creates a new Contract instance
 */
contract Deploy is Script {
    function run() external returns (Contract Contract_) {
        // Broadcast transactions using the deployer address from the environment
        vm.startBroadcast(vm.envAddress("DEPLOYER_ADDRESS"));

        // Create a new Contract
        Contract_ = new Contract();

        // Stop using the deployer's private key
        vm.stopBroadcast();
    }
}
