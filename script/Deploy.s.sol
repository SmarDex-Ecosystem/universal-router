// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { IUsdnProtocol } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";

import { Script } from "forge-std/Script.sol";
import { UniversalRouter } from "src/UniversalRouter.sol";
import { RouterParameters } from "src/base/RouterImmutables.sol";
import { ISmardexFactory } from "src/interfaces/smardex/ISmardexFactory.sol";

/**
 * @title DeployScript
 * @dev This script is a deploy script template that creates a new Contract instance
 */
contract Deploy is Script {
    function run() external returns (UniversalRouter UniversalRouter_) {
        // Broadcast transactions using the deployer address from the environment
        vm.startBroadcast(vm.envAddress("DEPLOYER_ADDRESS"));

        // Create a new Contract
        UniversalRouter_ = new UniversalRouter(
            RouterParameters({
                permit2: address(0),
                weth9: address(0),
                v2Factory: address(0),
                v3Factory: address(0),
                pairInitCodeHash: 0x0,
                poolInitCodeHash: 0x0,
                usdnProtocol: IUsdnProtocol(address(0)),
                wstEth: address(0),
                smardexFactory: ISmardexFactory(address(0))
            })
        );

        // Stop using the deployer's private key
        vm.stopBroadcast();
    }
}
