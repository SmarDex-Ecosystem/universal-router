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
        _setUp(DEFAULT_PARAMS);

        deal(address(wstETH), address(this), BASE_AMOUNT);
        stETH = IStETH(address(router.STETH()));
    }

    /**
     * @custom:scenario Test the `WRAP_STETH` command using the router balance and send to user
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `stETH`
     * @custom:when The `execute` function is called for `WRAP_STETH` command with MSG_SENDER
     * @custom:then The `WRAP_STETH` command should be executed
     * @custom:and The `wsteth` user balance should be increased
     */
    function test_executeWrapStETH() external {
        wstETH.unwrap(BASE_AMOUNT);
        stETH.transferShares(address(router), stETH.sharesOf(address(this)));

        bytes memory commands = abi.encodePacked(uint8(Commands.WRAP_STETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.CONTRACT_BALANCE, Constants.MSG_SENDER);
        router.execute(commands, inputs);

        assertApproxEqAbs(
            wstETH.balanceOf(address(this)),
            stETH.getPooledEthByShares(stETH.getSharesByPooledEth(BASE_AMOUNT)),
            1,
            "wrong wstETH balance(user)"
        );
        assertEq(wstETH.balanceOf(address(router)), 0, "wrong wstETH balance(router)");
        assertApproxEqAbs(stETH.sharesOf(address(router)), 0, 1, "wrong stETH balance(router)");
    }

    /**
     * @custom:scenario Test the `WRAP_STETH` command using a partial router balance and send to user
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `stETH`
     * @custom:when The `execute` function is called for `WRAP_STETH` command with MSG_SENDER
     * @custom:then The `WRAP_STETH` command should be executed
     * @custom:and The `wsteth` user balance should be increased
     * @custom:and The `stETH` router balance should not be empty
     */
    function test_executePartialWrapStETH() external {
        wstETH.unwrap(BASE_AMOUNT);
        uint256 shareAmount = stETH.sharesOf(address(this));
        stETH.transferShares(address(router), shareAmount);
        uint256 stETHBefore = stETH.balanceOf(address(router));
        bytes memory commands = abi.encodePacked(uint8(Commands.WRAP_STETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(stETHBefore / 2, Constants.MSG_SENDER);
        router.execute(commands, inputs);

        assertEq(
            wstETH.balanceOf(address(this)), stETH.getSharesByPooledEth(stETHBefore / 2), "wrong wstETH balance(user)"
        );
        assertApproxEqAbs(stETH.sharesOf(address(router)), shareAmount / 2, 2, "wrong stETH balance(router)");
    }

    /**
     * @custom:scenario Test the `WRAP_STETH` command using the router balance and stay in router
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `stETH`
     * @custom:when The `execute` function is called for `WRAP_STETH` command with ADDRESS_THIS
     * @custom:then The `WRAP_STETH` command should be executed
     * @custom:and The `wsteth` router balance should be increased
     */
    function test_executeWrapStETHForRouter() external {
        wstETH.unwrap(BASE_AMOUNT);
        stETH.transferShares(address(router), stETH.sharesOf(address(this)));

        bytes memory commands = abi.encodePacked(uint8(Commands.WRAP_STETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.CONTRACT_BALANCE, Constants.ADDRESS_THIS);
        router.execute(commands, inputs);

        assertApproxEqAbs(
            wstETH.balanceOf(address(router)),
            stETH.getPooledEthByShares(stETH.getSharesByPooledEth(BASE_AMOUNT)),
            1,
            "wrong wstETH balance(router)"
        );
        assertApproxEqAbs(stETH.sharesOf(address(router)), 0, 1, "wrong stETH balance(router)");
        assertEq(wstETH.balanceOf(address(this)), 0, "wrong wstETH balance(user)");
    }

    /**
     * @custom:scenario Test the `UNWRAP_WSTETH` command using the router balance
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `wstETH`
     * @custom:when The `execute` function is called for `UNWRAP_WSTETH` command
     * @custom:then The `UNWRAP_WSTETH` command should be executed
     * @custom:and The `stETH` user balance should be increased
     */
    function test_executeUnwrapStETH() external {
        wstETH.transfer(address(router), BASE_AMOUNT);
        uint256 sharesOfStETHBefore = stETH.sharesOf(address(this));

        bytes memory commands = abi.encodePacked(uint8(Commands.UNWRAP_WSTETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.CONTRACT_BALANCE, Constants.MSG_SENDER);
        router.execute(commands, inputs);

        assertEq(
            stETH.sharesOf(address(this)),
            sharesOfStETHBefore + stETH.getSharesByPooledEth(stETH.getPooledEthByShares(BASE_AMOUNT)),
            "wrong stETH balance(user)"
        );
        assertEq(stETH.sharesOf(address(router)), 0, "wrong stETH balance(router)");
        assertEq(wstETH.balanceOf(address(router)), 0, "wrong wstETH balance(router)");
    }

    /**
     * @custom:scenario Test the `UNWRAP_WSTETH` command using a partial router balance
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `wstETH`
     * @custom:when The `execute` function is called for `UNWRAP_WSTETH` command
     * @custom:then The `UNWRAP_WSTETH` command should be executed
     * @custom:and The `stETH` user balance should be increased
     * @custom:and The `wstETH` router balance should not be empty
     */
    function test_executePartialUnwrapWstETH() external {
        wstETH.transfer(address(router), BASE_AMOUNT);
        uint256 sharesOfStETHBefore = stETH.sharesOf(address(this));

        bytes memory commands = abi.encodePacked(uint8(Commands.UNWRAP_WSTETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(BASE_AMOUNT / 2, Constants.MSG_SENDER);
        router.execute(commands, inputs);

        assertEq(
            stETH.sharesOf(address(this)),
            sharesOfStETHBefore + stETH.getSharesByPooledEth(stETH.getPooledEthByShares(BASE_AMOUNT / 2)),
            "wrong stETH balance(user)"
        );
        assertEq(wstETH.balanceOf(address(router)), BASE_AMOUNT / 2, "wrong wstETH balance(router)");
    }

    /**
     * @custom:scenario Test the `UNWRAP_WSTETH` command using the router balance
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `wstETH`
     * @custom:when The `execute` function is called for `UNWRAP_WSTETH` command
     * @custom:then The `UNWRAP_WSTETH` command should be executed
     * @custom:and The `stETH` router balance should be increased
     */
    function test_executeUnwrapStETHForRouter() external {
        wstETH.transfer(address(router), BASE_AMOUNT);
        uint256 sharesOfStETHBefore = stETH.sharesOf(address(this));

        bytes memory commands = abi.encodePacked(uint8(Commands.UNWRAP_WSTETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.CONTRACT_BALANCE, Constants.ADDRESS_THIS);
        router.execute(commands, inputs);

        assertEq(
            stETH.sharesOf(address(router)),
            sharesOfStETHBefore + stETH.getSharesByPooledEth(stETH.getPooledEthByShares(BASE_AMOUNT)),
            "wrong stETH balance(router)"
        );
        assertEq(stETH.sharesOf(address(this)), 0, "wrong stETH balance(user)");
        assertEq(wstETH.balanceOf(address(this)), 0, "wrong wstETH balance(user)");
    }
}
