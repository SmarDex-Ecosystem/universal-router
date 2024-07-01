// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { WETH, SDEX } from "usdn-contracts/test/utils/Constants.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { ISmardexSwapRouterErrors } from "../../src/interfaces/smardex/ISmardexSwapRouterErrors.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

/**
 * @custom:feature Test smardex swap exact in commands
 * @custom:background A initiated universal router
 */
contract TestForkExecuteSmardexSwapExactIn is UniversalRouterBaseFixture, ISmardexSwapRouterErrors {
    uint256 constant BASE_AMOUNT = 1 ether;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);

        deal(WETH, address(this), BASE_AMOUNT * 1e3);
        deal(SDEX, address(this), BASE_AMOUNT * 1e3);
        deal(WBTC, address(this), BASE_AMOUNT * 1e3);
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command using the router balance
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some sdex
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should be executed
     * @custom:and The weth user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactInBalance() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, Constants.CONTRACT_BALANCE, 0, abi.encodePacked(SDEX, WETH), false);

        sdex.transfer(address(router), BASE_AMOUNT);
        uint256 balanceWethBefore = IERC20(WETH).balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(IERC20(WETH).balanceOf(address(this)), balanceWethBefore, "wrong weth balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command using the router
     * balance with the address zero recipient
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some sdex
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should be executed
     * @custom:and The weth router balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactInBalanceAddressZero() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(0), BASE_AMOUNT, 0, abi.encodePacked(SDEX, WETH), false);

        sdex.transfer(address(router), BASE_AMOUNT);
        uint256 balanceWethBefore = IERC20(WETH).balanceOf(address(router));

        router.execute(commands, inputs);

        assertGt(IERC20(WETH).balanceOf(address(router)), balanceWethBefore, "wrong weth balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command using the router balance by multi hops
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some wbtc
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should be executed
     * @custom:and The sdex user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactInBalanceMulti() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] =
            abi.encode(Constants.MSG_SENDER, Constants.CONTRACT_BALANCE, 0, abi.encodePacked(WBTC, WETH, SDEX), false);

        IERC20(WBTC).transfer(address(router), 1e10);
        uint256 balanceSdexBefore = IERC20(SDEX).balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(IERC20(SDEX).balanceOf(address(this)), balanceSdexBefore, "wrong sdex balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command using permit2
     * @custom:given The initiated universal router
     * @custom:and The user should be funded with some sdex
     * @custom:and The permit2 contract should be approved
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should be executed
     * @custom:and The weth user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactInPermit2() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, 0, abi.encodePacked(SDEX, WETH), true);

        IERC20(SDEX).approve(address(permit2), type(uint256).max);
        permit2.approve(SDEX, address(router), type(uint160).max, type(uint48).max);
        uint256 balanceWethBefore = IERC20(WETH).balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(IERC20(WETH).balanceOf(address(this)), balanceWethBefore, "wrong weth balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command using permit2 by multi hops
     * @custom:given The initiated universal router
     * @custom:and The user should be funded with some wbtc
     * @custom:and The permit2 contract should be approved
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should be executed
     * @custom:and The sdex user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactInPermit2Multi() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, 0, abi.encodePacked(WBTC, WETH, SDEX), true);

        IERC20(WBTC).approve(address(permit2), type(uint256).max);
        permit2.approve(WBTC, address(router), type(uint160).max, type(uint48).max);
        uint256 balanceSdexBefore = IERC20(SDEX).balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(IERC20(SDEX).balanceOf(address(this)), balanceSdexBefore, "wrong sdex balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_IN` command with too little token received
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some sdex
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_IN` command
     * @custom:then The `SMARDEX_SWAP_EXACT_IN` command should revert with `TooLittleReceived`
     */
    function test_RevertWhen_ForkExecuteSmardexSwapExactInTooLittleReceived() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_IN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            Constants.MSG_SENDER, Constants.CONTRACT_BALANCE, type(uint256).max, abi.encodePacked(SDEX, WETH), false
        );

        sdex.transfer(address(router), BASE_AMOUNT);

        vm.expectRevert(TooLittleReceived.selector);
        router.execute(commands, inputs);
    }
}
