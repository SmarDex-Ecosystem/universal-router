// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";

import { Wusdn } from "usdn-contracts/src/Usdn/Wusdn.sol";
import { IUsdn } from "usdn-contracts/src/interfaces/Usdn/IUsdn.sol";
import { IUsdnProtocol } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";

import { UniversalRouter } from "../src/UniversalRouter.sol";
import { RouterParameters } from "../src/base/RouterImmutables.sol";
import { ISmardexFactory } from "../src/interfaces/smardex/ISmardexFactory.sol";

/**
 * @title DeployScript
 * @dev This script is a deploy script template that creates a new Contract instance
 */
contract DeployRouter is Script {
    function run() external returns (UniversalRouter UniversalRouter_, Wusdn Wusdn_) {
        // Broadcast transactions using the deployer address from the environment
        vm.startBroadcast(vm.envAddress("DEPLOYER_ADDRESS"));
        Wusdn_ = new Wusdn(IUsdn(vm.envAddress("USDN")));

        // Create a new Contract
        UniversalRouter_ = new UniversalRouter(
            RouterParameters({
                permit2: vm.envAddress("PERMIT2"),
                weth9: vm.envAddress("WETH"),
                v2Factory: vm.envAddress("UNISWAP_V2_FACTORY"),
                v3Factory: vm.envAddress("UNISWAP_V3_FACTORY"),
                pairInitCodeHash: vm.envBytes32("UNISWAP_PAIR_INIT_HASH"),
                poolInitCodeHash: vm.envBytes32("UNISWAP_POOL_INIT_HASH"),
                usdnProtocol: IUsdnProtocol(vm.envAddress("USDN_PROTOCOL")),
                wstEth: vm.envAddress("WSTETH_ADDRESS"),
                wusdn: Wusdn_,
                smardexFactory: ISmardexFactory(vm.envAddress("SMARDEX_FACTORY"))
            })
        );

        // Stop using the deployer's private key
        vm.stopBroadcast();
    }
}
