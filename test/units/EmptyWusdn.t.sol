// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";

import { IWusdn } from "@smardex-usdn-contracts-1/src/interfaces/Usdn/IWusdn.sol";
import { IUsdnProtocol } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";

import { MockUsdnProtocol } from "./utils/MockUsdnProtocol.sol";
import { MockWstEth } from "./utils/MockWstEth.sol";

import { UniversalRouter } from "../../src/UniversalRouter.sol";
import { Dispatcher } from "../../src/base/Dispatcher.sol";
import { RouterParameters } from "../../src/base/RouterImmutables.sol";
import { ISmardexFactory } from "../../src/interfaces/smardex/ISmardexFactory.sol";
import { Commands } from "../../src/libraries/Commands.sol";

/// @custom:feature Test wrap and unwrap commands of the `execute` function with an empty wusdn
contract TestEmptyWusdn is Test {
    UniversalRouter internal router;

    function setUp() external {
        MockUsdnProtocol mockProtocol = new MockUsdnProtocol();
        MockWstEth mockWstEth = new MockWstEth();

        RouterParameters memory params = RouterParameters({
            permit2: address(0),
            weth9: address(0),
            v2Factory: address(0),
            v3Factory: address(0),
            pairInitCodeHash: "",
            poolInitCodeHash: "",
            usdnProtocol: IUsdnProtocol(address(mockProtocol)),
            wstEth: address(mockWstEth),
            wusdn: IWusdn(address(0)),
            smardexFactory: ISmardexFactory(address(0)),
            ensoV2Router: address(0)
        });

        router = new UniversalRouter(params);
    }

    /**
     * @custom:scenario Test the `WRAP_WUSDN` command using the router with an empty wusdn
     * @custom:when The `execute` function is called for `WRAP_USDN` command
     * @custom:then The transaction must revert with `NoWusdn`
     */
    function test_RevertWhen_ForkExecuteWrapUsdnNoWusdn() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.WRAP_USDN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(0, address(0));

        vm.expectRevert(Dispatcher.NoWusdn.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the `UNWRAP_WUSDN` command using the router with an empty wusdn
     * @custom:when The `execute` function is called for `UNWRAP_WUSDN` command
     * @custom:then The transaction must revert with `NoWusdn`
     */
    function test_RevertWhen_ForkExecuteUnwrapUsdnNoWusdn() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.UNWRAP_WUSDN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(0, address(0));

        vm.expectRevert(Dispatcher.NoWusdn.selector);
        router.execute(commands, inputs);
    }
}
