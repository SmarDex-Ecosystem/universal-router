// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { IStETH } from "../../src/interfaces/lido/IStETH.sol";
import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Test commands lido wrap stETH and unwrap wsteth
 * @custom:background A initiated universal router
 */
contract TestForkUniversalRouterExecuteLido is UniversalRouterBaseFixture {
    uint256 constant BASE_AMOUNT = 1000 ether;
    IStETH stETH;

    function setUp() external {
        SetUpParams memory params = DEFAULT_PARAMS;
        params.forkBlock = 22_417_713;
        _setUp(params);

        deal(address(wstETH), address(this), BASE_AMOUNT);
    }

    function test_forkOdosSwap() external {
        wstETH.transfer(address(router), 1 ether);

        bytes memory data =
            hex"83bd37f900017f39c581f595b53c5cb19bd0b3f8da6c935e2ca00001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2080de0b6b3a76400000810ab38f02fa1770000c49b000176edF8C155A1e0D9B2aD11B04d9671CBC25fEE99000000017FA9385bE102ac3EAc297483Dd6233D62b3e1496000000000402020300070101010293d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2ff000000000000000000000000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca0c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000";
        bytes memory commands = abi.encodePacked(uint8(Commands.ODOS));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, 1 ether, data);

        router.execute(commands, inputs);
    }

    function test_easf() external {
        wstETH.transfer(address(router), 1 ether);

        bytes memory data =
            hex"83bd37f900017f39c581f595b53c5cb19bd0b3f8da6c935e2ca00001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2080de0b6b3a76400000810ab38f02fa1770000c49b000176edF8C155A1e0D9B2aD11B04d9671CBC25fEE99000000017FA9385bE102ac3EAc297483Dd6233D62b3e1496000000000402020300070101010293d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2ff000000000000000000000000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca0c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000";
        bytes memory commands = abi.encodePacked(uint8(Commands.ODOS));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, 1 ether, data);

        router.execute(commands, inputs);
    }
}
