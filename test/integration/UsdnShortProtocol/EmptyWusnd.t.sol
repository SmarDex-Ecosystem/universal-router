// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { UniversalRouterUsdnShortProtocolBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../../src/libraries/Commands.sol";
import { Dispatcher } from "../../../src/base/Dispatcher.sol";

/**
 * @custom:feature Test wrap and unwrap commands of the `execute` function with an empty wusdn
 * @custom:background An initiated universal router
 */
contract TestForkUsdnShortEmptyWusdn is UniversalRouterUsdnShortProtocolBaseFixture {
    function setUp() external {
        _setUp();
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
