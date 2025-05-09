// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { ISmardexRouter } from "../../src/interfaces/smardex/ISmardexRouter.sol";
import { ISmardexRouterErrors } from "../../src/interfaces/smardex/ISmardexRouterErrors.sol";
import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Test smardex swap exact out command
 * @custom:background A initiated universal router
 */
contract TestForkExecuteSmardexSwapExactOut is UniversalRouterBaseFixture, ISmardexRouterErrors {
    uint256 constant BASE_AMOUNT = 1 ether;

    ISmardexRouter.AddLiquidityParams internal liqParams;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);

        deal(address(token0), address(this), BASE_AMOUNT * 2);
        deal(address(token1), address(this), BASE_AMOUNT * 2);
        deal(address(token2), address(this), BASE_AMOUNT * 2);

        deal(address(token0), address(router), BASE_AMOUNT * 1e2 * 2);
        deal(address(token1), address(router), BASE_AMOUNT * 1e2 * 2);
        deal(address(token2), address(router), BASE_AMOUNT * 1e2 * 2);

        liqParams.amountADesired = BASE_AMOUNT * 1e2;
        liqParams.amountBDesired = BASE_AMOUNT * 1e2;

        bytes memory commands = abi.encodePacked(
            uint8(Commands.SMARDEX_ADD_LIQUIDITY),
            uint8(Commands.SMARDEX_ADD_LIQUIDITY),
            uint8(Commands.SMARDEX_ADD_LIQUIDITY)
        );
        bytes[] memory inputs = new bytes[](3);

        liqParams.tokenA = address(token0);
        liqParams.tokenB = address(token1);
        inputs[0] = abi.encode(liqParams, address(this), false, type(uint256).max);

        liqParams.tokenA = address(token1);
        liqParams.tokenB = address(token2);
        inputs[1] = abi.encode(liqParams, address(this), false, type(uint256).max);

        liqParams.tokenA = address(token0);
        liqParams.tokenB = address(token2);
        inputs[2] = abi.encode(liqParams, address(this), false, type(uint256).max);

        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command using the router balance
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `token0`
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The `SMARDEX_SWAP_EXACT_OUT` command should be executed
     * @custom:and The `token1` user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactOutBalance() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] =
            abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, type(uint256).max, abi.encodePacked(token0, token1), false);

        token0.transfer(address(router), BASE_AMOUNT * 2);
        uint256 balanceToken1Before = token1.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(token1.balanceOf(address(this)), balanceToken1Before, "wrong token1 balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command using the router balance by multi hops
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `token0`
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The `SMARDEX_SWAP_EXACT_OUT` command should be executed
     * @custom:and The user `token2` balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactOutBalanceMulti() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            Constants.MSG_SENDER, BASE_AMOUNT, type(uint256).max, abi.encodePacked(token0, token1, token2), false
        );

        token0.transfer(address(router), BASE_AMOUNT * 2);
        uint256 balanceToken2Before = token2.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(token2.balanceOf(address(this)), balanceToken2Before, "wrong token2 balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command using permit2
     * @custom:given The initiated universal router
     * @custom:and The user should be funded with some `token0`
     * @custom:and The permit2 contract should be approved
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The `SMARDEX_SWAP_EXACT_OUT` command should be executed
     * @custom:and The user `token1` balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactOutPermit2() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] =
            abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, type(uint256).max, abi.encodePacked(token0, token1), true);

        token0.approve(address(permit2), type(uint256).max);
        permit2.approve(address(token0), address(router), type(uint160).max, type(uint48).max);
        uint256 balanceToken1Before = token1.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(token1.balanceOf(address(this)), balanceToken1Before, "wrong token1 balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command using permit2 by multi hops
     * @custom:given The initiated universal router
     * @custom:and The user should be funded with some `token0`
     * @custom:and The permit2 contract should be approved
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The `SMARDEX_SWAP_EXACT_OUT` command should be executed
     * @custom:and The user `token2` balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactOutPermit2Multi() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            Constants.MSG_SENDER, BASE_AMOUNT, type(uint256).max, abi.encodePacked(token0, token1, token2), true
        );

        token0.approve(address(permit2), type(uint256).max);
        permit2.approve(address(token0), address(router), type(uint160).max, type(uint48).max);
        uint256 balanceToken2Before = token2.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(token2.balanceOf(address(this)), balanceToken2Before, "wrong token2 balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command with too much token sent
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `token0`
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The command should revert with `excessiveInputAmount`
     */
    function test_RevertWhen_ForkExecuteSmardexSwapExactOutExcessiveInputAmount() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, 1, abi.encodePacked(token0, token1), false);

        token0.transfer(address(router), BASE_AMOUNT * 2);

        vm.expectRevert(ExcessiveInputAmount.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command with an invalid recipient
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `token0`
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The command should revert with `invalidRecipient`
     */
    function test_RevertWhen_ForkExecuteSmardexSwapExactOutInvalidRecipient() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(0), BASE_AMOUNT, BASE_AMOUNT, abi.encodePacked(token0, token1), false);

        token0.transfer(address(router), BASE_AMOUNT);

        vm.expectRevert(InvalidRecipient.selector);
        router.execute(commands, inputs);
    }
}
