// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";

import { IWusdn } from "@smardex-usdn-contracts-1/src/interfaces/Usdn/IWusdn.sol";
import { IUsdnProtocol } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";

import { UniversalRouter } from "../src/UniversalRouter.sol";
import { RouterParameters } from "../src/base/RouterImmutables.sol";
import { ISmardexFactory } from "../src/interfaces/smardex/ISmardexFactory.sol";

contract Deploy is Script {
    address constant WSTETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant V2_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address constant V3_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address constant SMARDEX_FACTORY = 0xdd4536dD9636564D891c919416880a3e250f975A;
    bytes32 constant PAIR_INIT_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;
    bytes32 constant POOL_INIT_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    address constant ODOS_SOR_ROUTER = 0x19cEeAd7105607Cd444F5ad10dd51356436095a1;

    function run(address wusdnTokenAddress, address usdnProtocolAddress)
        external
        returns (UniversalRouter universalRouter_)
    {
        vm.startBroadcast();

        universalRouter_ = new UniversalRouter(
            RouterParameters({
                permit2: vm.envOr("PERMIT2", PERMIT2),
                weth9: vm.envOr("WETH", WETH),
                v2Factory: vm.envOr("UNISWAP_V2_FACTORY", V2_FACTORY),
                v3Factory: vm.envOr("UNISWAP_V3_FACTORY", V3_FACTORY),
                pairInitCodeHash: vm.envOr("UNISWAP_PAIR_INIT_HASH", PAIR_INIT_HASH),
                poolInitCodeHash: vm.envOr("UNISWAP_POOL_INIT_HASH", POOL_INIT_HASH),
                usdnProtocol: IUsdnProtocol(usdnProtocolAddress),
                wstEth: vm.envOr("WSTETH", WSTETH),
                wusdn: IWusdn(wusdnTokenAddress),
                smardexFactory: ISmardexFactory(vm.envOr("SMARDEX_FACTORY", SMARDEX_FACTORY)),
                odosSorRouter: vm.envOr("ODOS_SOR_ROUTER", ODOS_SOR_ROUTER)
            })
        );

        vm.stopBroadcast();
    }
}
