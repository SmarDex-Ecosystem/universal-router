// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { ISmardexRouter } from "../../src/interfaces/smardex/ISmardexRouter.sol";
import { ISmardexRouterErrors } from "../../src/interfaces/smardex/ISmardexRouterErrors.sol";
import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Test smardex swap exact in commands
 * @custom:background A initiated universal router
 */
contract TestForkExecuteSmardexSwapExactIn is UniversalRouterBaseFixture, ISmardexRouterErrors {
    uint256 constant BASE_AMOUNT = 1 ether;

    ISmardexRouter.AddLiquidityParams internal liqParams;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);

        deal(address(token0), address(this), BASE_AMOUNT);
        deal(address(token1), address(this), BASE_AMOUNT);
        deal(address(token2), address(this), BASE_AMOUNT);

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
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command using the router balance
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `token0`
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should be executed
     * @custom:and The `token1` user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactInBalance() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));
        token0.transfer(address(router), BASE_AMOUNT);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] =
            abi.encode(Constants.MSG_SENDER, Constants.CONTRACT_BALANCE, 0, abi.encodePacked(token0, token1), false);

        uint256 balanceToken1Before = token1.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(token1.balanceOf(address(this)), balanceToken1Before, "wrong token1 balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command using the router
     * balance with the address zero recipient
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `token0`
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should be executed
     * @custom:and The `token1` router balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactInBalanceAddressZero() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));
        token0.transfer(address(router), BASE_AMOUNT);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(0), Constants.CONTRACT_BALANCE, 0, abi.encodePacked(token0, token1), false);

        uint256 balanceToken1Before = token1.balanceOf(address(router));

        router.execute(commands, inputs);

        assertGt(token1.balanceOf(address(router)), balanceToken1Before, "wrong token1 balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command using the router balance by multi hops
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `token0`
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should be executed
     * @custom:and The `token2` user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactInBalanceMulti() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));
        token0.transfer(address(router), BASE_AMOUNT);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            Constants.MSG_SENDER, Constants.CONTRACT_BALANCE, 0, abi.encodePacked(token0, token1, token2), false
        );

        uint256 balanceToken2Before = token2.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(token2.balanceOf(address(this)), balanceToken2Before, "wrong token2 balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command using permit2
     * @custom:given The initiated universal router
     * @custom:and The user should be funded with some `token0`
     * @custom:and The permit2 contract should be approved
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should be executed
     * @custom:and The `token1` user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactInPermit2() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, 0, abi.encodePacked(token0, token1), true);

        token0.approve(address(permit2), type(uint256).max);
        permit2.approve(address(token0), address(router), type(uint160).max, type(uint48).max);
        uint256 balanceToken1Before = token1.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(token1.balanceOf(address(this)), balanceToken1Before, "wrong token2 balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command using permit2 by multi hops
     * @custom:given The initiated universal router
     * @custom:and The user should be funded with some `token0`
     * @custom:and The permit2 contract should be approved
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should be executed
     * @custom:and The `token2` user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactInPermit2Multi() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, 0, abi.encodePacked(token0, token1, token2), true);

        token0.approve(address(permit2), type(uint256).max);
        permit2.approve(address(token0), address(router), type(uint160).max, type(uint48).max);
        uint256 balanceToken2Before = token2.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(token2.balanceOf(address(this)), balanceToken2Before, "wrong token2 balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command with too little token received
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `token0`
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should revert with `TooLittleReceived`
     */
    function test_RevertWhen_ForkExecuteSmardexSwapExactInTooLittleReceived() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));
        token0.transfer(address(router), BASE_AMOUNT);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            Constants.MSG_SENDER, Constants.CONTRACT_BALANCE, type(uint256).max, abi.encodePacked(token0, token1), false
        );

        vm.expectRevert(TooLittleReceived.selector);
        router.execute(commands, inputs);
    }
}
