// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { UniversalRouterBaseFixture } from "../integration/utils/Fixtures.sol";
import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Sweep ETH or token to an address
 * @custom:background An initiated universal router
 * @custom:and The router has some ETH and token
 */
contract TestForkUniversalRouterSweep is UniversalRouterBaseFixture {
    error InsufficientETH();
    error InsufficientToken();

    function setUp() public {
        _setUp(DEFAULT_PARAMS);
        deal(address(wstETH), address(router), 1 ether);
        deal(address(router), 1 ether);
    }

    /**
     * @custom:action Sweep ETH to an address
     * @custom:given The router has ETH
     * @custom:when The `execute` function is called for `SWEEP` command
     * @custom:then The `SWEEP` command should transfer all ETH to the address
     */
    function test_SweepETH() public {
        uint256 balanceRouterBefore = address(router).balance;
        uint256 balanceBefore = address(this).balance;
        bytes memory commands = abi.encodePacked(uint8(Commands.SWEEP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(this), balanceRouterBefore, 0);

        router.execute(commands, inputs);

        assertEq(address(this).balance, balanceBefore + balanceRouterBefore);
    }

    /**
     * @custom:action Sweep token to an address
     * @custom:given The router has tokens
     * @custom:when The `execute` function is called for `SWEEP` command
     * @custom:then The `SWEEP` command should transfer all tokens   to the address
     */
    function test_SweepToken() public {
        uint256 balanceRouterBefore = wstETH.balanceOf(address(router));
        bytes memory commands = abi.encodePacked(uint8(Commands.SWEEP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(wstETH, address(this), balanceRouterBefore, 0);

        router.execute(commands, inputs);

        assertEq(wstETH.balanceOf(address(this)), balanceRouterBefore);
    }

    /**
     * @custom:action Revert when sweep ETH an amount higher than the router balance
     * @custom:given The router does not have enough ETH
     * @custom:when The `execute` function is called for `SWEEP` command
     * @custom:then The `SWEEP` command should revert with `InsufficientETH`
     */
    function test_RevertWhen_EnoughtETHForSweep() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SWEEP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(this), address(router).balance + 1, 0);

        vm.expectRevert(InsufficientETH.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:action Revert when sweep token an amount higher than the router balance
     * @custom:given The router does not have enough tokens
     * @custom:when The `execute` function is called for `SWEEP` command
     * @custom:then The `SWEEP` command should revert with `InsufficientToken`
     */
    function test_RevertWhen_EnoughtTokenForSweep() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SWEEP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(wstETH, address(this), wstETH.balanceOf(address(router)) + 1, 0);

        vm.expectRevert(InsufficientToken.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:action Sweep doesn't activate when ETh is lower than minimum token gas efficiency
     * @custom:given The gas price is greater than the router balance, so is not profitable to transfer ETH
     * @custom:when The `execute` function is called for `SWEEP` command
     * @custom:then The `SWEEP` command should pass without transfer ETH
     */
    function test_ETHLowerThanMinTokenGasEfficiency() public {
        uint256 balanceRouterBefore = address(router).balance;
        uint256 balanceBefore = address(this).balance;
        bytes memory commands = abi.encodePacked(uint8(Commands.SWEEP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(this), 0, balanceRouterBefore + 1);

        router.execute(commands, inputs);

        assertEq(address(this).balance, balanceBefore);
        assertEq(address(router).balance, balanceRouterBefore);
    }

    /**
     * @custom:action Sweep doesn't activate when token is lower than minimum token gas efficiency
     * @custom:given The gas price is greater than the router balance, so is not profitable to transfer token
     * @custom:when The `execute` function is called for `SWEEP` command
     * @custom:then The `SWEEP` command should pass without transfer token
     */
    function test_TokenLowerThanMinTokenGasEfficiency() public {
        uint256 balanceRouterBefore = wstETH.balanceOf(address(router));
        bytes memory commands = abi.encodePacked(uint8(Commands.SWEEP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(wstETH, address(this), 0, balanceRouterBefore + 1);

        router.execute(commands, inputs);

        assertEq(wstETH.balanceOf(address(this)), 0);
        assertEq(wstETH.balanceOf(address(router)), balanceRouterBefore);
    }

    receive() external payable { }
}
