// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";

import { IUsdnProtocol } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";
import { IWusdn } from "@smardex-usdn-contracts-1/src/interfaces/Usdn/IWusdn.sol";

import { UniversalRouter } from "../src/UniversalRouter.sol";
import { RouterParameters } from "../src/base/RouterImmutables.sol";
import { ISmardexFactory } from "../src/interfaces/smardex/ISmardexFactory.sol";

contract Deploy is Script {
    address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address constant SMARDEX_FACTORY = 0xB878DC600550367e14220d4916Ff678fB284214F;
    bytes32 constant PAIR_INIT_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;
    bytes32 constant POOL_INIT_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

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
                smardexFactory: ISmardexFactory(vm.envOr("SMARDEX_FACTORY", SMARDEX_FACTORY))
            })
        );

        vm.stopBroadcast();
    }
}
