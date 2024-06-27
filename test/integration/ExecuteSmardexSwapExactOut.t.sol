// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { WETH, SDEX } from "usdn-contracts/test/utils/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { ISmardexSwapRouterErrors } from "../../src/interfaces/smardex/ISmardexSwapRouterErrors.sol";

/**
 * @custom:feature Test smardex swap exact out command
 * @custom:background A initiated universal router
 */
contract TestForkExecuteSmardexSwapExactOut is UniversalRouterBaseFixture, ISmardexSwapRouterErrors {
    uint256 constant BASE_AMOUNT = 1 ether;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);

        deal(WETH, address(this), BASE_AMOUNT * 1e3);
        deal(SDEX, address(this), BASE_AMOUNT * 1e3);
        deal(WBTC, address(this), BASE_AMOUNT * 1e3);
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command using the router balance
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some weth
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The `SMARDEX_SWAP_EXACT_OUT` command should be executed
     * @custom:and The sdex user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactOutBalance() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, BASE_AMOUNT, abi.encodePacked(WETH, SDEX), false);

        IERC20(WETH).transfer(address(router), BASE_AMOUNT);
        uint256 balanceSdexBefore = sdex.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(sdex.balanceOf(address(this)), balanceSdexBefore, "wrong sdex balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command using the router balance by multi hops
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some wbtc
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The `SMARDEX_SWAP_EXACT_OUT` command should be executed
     * @custom:and The weth sdex balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactOutBalanceMulti() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] =
            abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, BASE_AMOUNT, abi.encodePacked(WBTC, WETH, SDEX), false);

        IERC20(WBTC).transfer(address(router), BASE_AMOUNT);
        uint256 balanceSdexBefore = sdex.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(sdex.balanceOf(address(this)), balanceSdexBefore, "wrong sdex balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command using permit2
     * @custom:given The initiated universal router
     * @custom:and The user should be funded with some weth
     * @custom:and The permit2 contract should be approved
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The `SMARDEX_SWAP_EXACT_OUT` command should be executed
     * @custom:and The sdex user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactOutPermit2() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, BASE_AMOUNT, abi.encodePacked(WETH, SDEX), true);

        IERC20(WETH).approve(address(permit2), type(uint256).max);
        permit2.approve(WETH, address(router), type(uint160).max, type(uint48).max);
        uint256 balanceSdexBefore = sdex.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(sdex.balanceOf(address(this)), balanceSdexBefore, "wrong sdex balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command using permit2 by multi hops
     * @custom:given The initiated universal router
     * @custom:and The user should be funded with some wbtc
     * @custom:and The permit2 contract should be approved
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The `SMARDEX_SWAP_EXACT_OUT` command should be executed
     * @custom:and The sdex user balance should be increased
     */
    function test_ForkExecuteSmardexSwapExactOutPermit2Multi() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, BASE_AMOUNT, abi.encodePacked(WBTC, WETH, SDEX), true);

        IERC20(WBTC).approve(address(permit2), type(uint256).max);
        permit2.approve(WBTC, address(router), type(uint160).max, type(uint48).max);
        uint256 balanceSdexBefore = IERC20(SDEX).balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(sdex.balanceOf(address(this)), balanceSdexBefore, "wrong sdex balance");
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command with too much token sent
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some weth
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The command should revert with `excessiveInputAmount`
     */
    function test_RevertWhen_ForkExecuteSmardexSwapExactOutExcessiveInputAmount() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, BASE_AMOUNT, 1, abi.encodePacked(WETH, SDEX), false);

        IERC20(WETH).transfer(address(router), BASE_AMOUNT);

        vm.expectRevert(ExcessiveInputAmount.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the `SMARDEX_SWAP_EXACT_OUT` command with an invalid recipient
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some weth
     * @custom:when The `execute` function is called for `SMARDEX_SWAP_EXACT_OUT` command
     * @custom:then The command should revert with `invalidRecipient`
     */
    function test_RevertWhen_ForkExecuteSmardexSwapExactOutInvalidRecipient() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(0), BASE_AMOUNT, BASE_AMOUNT, abi.encodePacked(WETH, SDEX), false);

        IERC20(WETH).transfer(address(router), BASE_AMOUNT);

        vm.expectRevert(InvalidRecipient.selector);
        router.execute(commands, inputs);
    }
}
