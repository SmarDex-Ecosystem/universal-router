// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { USER_1 } from "./utils/Constants.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { IUniversalRouter } from "../../src/interfaces/IUniversalRouter.sol";

/**
 * @custom:feature Test commands TRANSFER_FROM
 * @custom:background A initiated universal router
 */
contract TestForkUniversalRouterExecuteTransferFrom is UniversalRouterBaseFixture {
    uint256 constant BASE_AMOUNT = 1000 ether;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);
        deal(address(wstETH), address(this), BASE_AMOUNT);
        deal(address(wstETH), USER_1, BASE_AMOUNT);
    }

    /**
     * @custom:scenario Test the `TRANSFER_FROM` command
     * @custom:given The initiated universal router
     * @custom:and The router should be approved with the correct ERC20 amount
     * @custom:when The `execute` function is called for `TRANSFER_FROM` command
     * @custom:then The `TRANSFER_FROM` command should be executed
     * @custom:and The `wsteth` user balance should be decreased
     * @custom:and The `wsteth` receiver balance should be increased
     */
    function test_executeTransferFrom() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.TRANSFER_FROM));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(wstETH), address(router), BASE_AMOUNT);

        wstETH.approve(address(router), BASE_AMOUNT);

        router.execute(commands, inputs);

        assertEq(wstETH.balanceOf(address(this)), 0, "wsteth balance should be zero");
        assertEq(wstETH.balanceOf(address(router)), BASE_AMOUNT, "wsteth balance should be different");
    }

    /**
     * @custom:scenario Test the `TRANSFER_FROM` command from a different user
     * @custom:given The initiated universal router
     * @custom:and The router should be approved with the correct ERC20 amount
     * @custom:when The `execute` function is called for `TRANSFER_FROM` command
     * @custom:then The `TRANSFER_FROM` command should be reverted
     */
    function test_RevertWhen_executeTransferFromDifferentUser() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.TRANSFER_FROM));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(wstETH), address(router), BASE_AMOUNT);

        wstETH.approve(address(router), BASE_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniversalRouter.ExecutionFailed.selector,
                0,
                abi.encodeWithSignature("Error(string)", "ERC20: transfer amount exceeds allowance")
            )
        );

        vm.prank(USER_1);
        router.execute(commands, inputs);
    }
}
