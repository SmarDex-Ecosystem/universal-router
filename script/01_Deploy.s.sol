// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";

import { IUsdnProtocol } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";
import { IWusdn } from "@smardex-usdn-contracts-1/src/interfaces/Usdn/IWusdn.sol";

import { UniversalRouter } from "../src/UniversalRouter.sol";
import { RouterParameters } from "../src/base/RouterImmutables.sol";
import { ISmardexFactory } from "../src/interfaces/smardex/ISmardexFactory.sol";

contract Deploy is Script {
    enum ChainId {
        Mainnet,
        Sepolia,
        Fork
    }

    address constant WSTETH_MAINNET = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WETH_SEPOLIA = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address constant V2_FACTORY_MAINNET = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant V2_FACTORY_SEPOLIA = address(0); // not supported on sepolia
    address constant V3_FACTORY_MAINNET = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address constant V3_FACTORY_SEPOLIA = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;
    address constant SMARDEX_FACTORY_MAINNET = 0xB878DC600550367e14220d4916Ff678fB284214F;
    address constant SMARDEX_FACTORY_SEPOLIA = address(0); // not supported on sepolia
    address constant WUSDN_ADDRESS = 0x99999999999999Cc837C997B882957daFdCb1Af9;
    address constant USDN_PROTOCOL_ADDRESS = 0x656cB8C6d154Aad29d8771384089be5B5141f01a;
    bytes32 constant PAIR_INIT_HASH_MAINNET = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;
    bytes32 constant PAIR_INIT_HASH_SEPOLIA = 0; // not supported on sepolia
    bytes32 constant POOL_INIT_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    address _deployerAddress;
    ChainId _chainId;

    function run() external returns (UniversalRouter UniversalRouter_) {
        if (block.chainid == 1 || block.chainid == 983_659_430_532) {
            _chainId = ChainId.Mainnet;
        } else if (block.chainid == 11_155_111) {
            _chainId = ChainId.Sepolia;
        } else {
            _chainId = ChainId.Fork;
        }

        (address wstEthAddress, address wusdnTokenAddress, address usdnProtocolAddress) = _handleEnvVariables();

        vm.startBroadcast(_deployerAddress);

        UniversalRouter_ = _deployRouter(wstEthAddress, wusdnTokenAddress, usdnProtocolAddress);

        vm.stopBroadcast();
    }

    function _deployRouter(address wstEthAddress, address wusdnTokenAddress, address usdnProtocolAddress)
        internal
        returns (UniversalRouter router_)
    {
        router_ = new UniversalRouter(
            RouterParameters({
                permit2: vm.envOr("PERMIT2", PERMIT2),
                weth9: vm.envOr("WETH", WETH_MAINNET),
                v2Factory: vm.envOr("UNISWAP_V2_FACTORY", V2_FACTORY_MAINNET),
                v3Factory: vm.envOr("UNISWAP_V3_FACTORY", V3_FACTORY_MAINNET),
                pairInitCodeHash: vm.envOr("UNISWAP_PAIR_INIT_HASH", PAIR_INIT_HASH_MAINNET),
                poolInitCodeHash: vm.envOr("UNISWAP_POOL_INIT_HASH", POOL_INIT_HASH),
                usdnProtocol: IUsdnProtocol(usdnProtocolAddress),
                wstEth: wstEthAddress,
                wusdn: IWusdn(wusdnTokenAddress),
                smardexFactory: ISmardexFactory(vm.envOr("SMARDEX_FACTORY", SMARDEX_FACTORY_MAINNET))
            })
        );
    }

    /**
     * @notice Handle the environment variables
     */
    function _handleEnvVariables()
        internal
        returns (address wstEthAddress_, address wusdnTokenAddress_, address usdnProtocolAddress_)
    {
        try vm.envAddress("DEPLOYER_ADDRESS") {
            _deployerAddress = vm.envAddress("DEPLOYER_ADDRESS");
        } catch {
            revert("DEPLOYER_ADDRESS is required");
        }

        if (_chainId == ChainId.Sepolia) {
            wstEthAddress_ = vm.envOr("WSTETH_ADDRESS", address(0));
            if (wstEthAddress_ == address(0)) {
                wstEthAddress_ = vm.parseAddress(vm.prompt("Please enter the wstETH token address"));
            }
            vm.setEnv("WETH", vm.toString(WETH_SEPOLIA));
            vm.setEnv("UNISWAP_V2_FACTORY", vm.toString(V2_FACTORY_SEPOLIA));
            vm.setEnv("UNISWAP_V3_FACTORY", vm.toString(V3_FACTORY_SEPOLIA));
            vm.setEnv("UNISWAP_PAIR_INIT_HASH", vm.toString(PAIR_INIT_HASH_SEPOLIA));
            vm.setEnv("SMARDEX_FACTORY", vm.toString(SMARDEX_FACTORY_SEPOLIA));

            wusdnTokenAddress_ = vm.envOr("WUSDN_ADDRESS", address(0));
            if (wusdnTokenAddress_ == address(0)) {
                wusdnTokenAddress_ = vm.parseAddress(vm.prompt("Please enter the WUSDN token address"));
            }

            usdnProtocolAddress_ = vm.envOr("USDN_PROTOCOL_ADDRESS", address(0));
            if (usdnProtocolAddress_ == address(0)) {
                usdnProtocolAddress_ = vm.parseAddress(vm.prompt("Please enter the USDN protocol address"));
            }
        } else {
            wstEthAddress_ = WSTETH_MAINNET;
            wusdnTokenAddress_ = WUSDN_ADDRESS;
            usdnProtocolAddress_ = USDN_PROTOCOL_ADDRESS;
        }

        string memory etherscanApiKey = vm.envOr("ETHERSCAN_API_KEY", string("XXXXXXXXXXXXXXXXX"));
        vm.setEnv("ETHERSCAN_API_KEY", etherscanApiKey);
    }
}
