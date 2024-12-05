// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WETH, WSTETH } from "usdn-contracts/test/utils/Constants.sol";

import { TestForkUniversalRouterSmardexAddLiquidity } from "./ExecuteSmardexAddLiquidity.t.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { ISmardexRouter } from "../../src/interfaces/smardex/ISmardexRouter.sol";
import { ISmardexRouterErrors } from "../../src/interfaces/smardex/ISmardexRouterErrors.sol";
import { ISmardexPair } from "../../src/interfaces/smardex/ISmardexPair.sol";

/**
 * @custom:feature Test router commands for smardex remove liquidity
 * @custom:background A initiated universal router
 */
contract TestForkUniversalRouterSmardexRemoveLiquidity is TestForkUniversalRouterSmardexAddLiquidity {
    ISmardexRouter.RemoveLiquidityParams internal _removeParams = ISmardexRouter.RemoveLiquidityParams({
        tokenA: WETH,
        tokenB: WSTETH,
        liquidity: 0,
        amountAMin: 0,
        amountBMin: 0
    });

    /**
     * @custom:scenario Test the {SMARDEX_REMOVE_LIQUIDITY} command with a exceeded deadline
     * @custom:when The {execute} function is called for {SMARDEX_REMOVE_LIQUIDITY}
     * @custom:then The {SMARDEX_REMOVE_LIQUIDITY} command should revert with {DeadlineExceeded}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityDeadlineExceeded() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, 0);

        vm.expectRevert(ISmardexRouterErrors.DeadlineExceeded.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the {SMARDEX_REMOVE_LIQUIDITY} command using the router balance
     * @custom:given A created liquidity pair with token already minted
     * @custom:and The router is funded with some liquidity tokens
     * @custom:when The {execute} function is called for {SMARDEX_REMOVE_LIQUIDITY}
     * @custom:then The {SMARDEX_REMOVE_LIQUIDITY} command should be executed
     * @custom:and The `WSTETH` balance of the user should be increased
     * @custom:and The `WETH` balance of the user should be increased
     */
    function test_executeSmardexRemoveLiquidityRouterBalance() public {
        test_executeSmardexAddLiquidityRouterBalance();

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));
        _removeParams.liquidity = pair.balanceOf(address(this));

        pair.transfer(address(router), _removeParams.liquidity);

        uint256 wstethBalanceBefore = IERC20(WSTETH).balanceOf(address(this));
        uint256 wethBalanceBefore = IERC20(WETH).balanceOf(address(this));

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);
        router.execute(commands, inputs);

        assertGt(
            IERC20(WSTETH).balanceOf(address(this)),
            wstethBalanceBefore,
            "The `WSTETH` user balance should be increased"
        );
        assertGt(
            IERC20(WETH).balanceOf(address(this)), wethBalanceBefore, "The `WETH` user balance should be increased"
        );
    }

    /**
     * @custom:scenario Test the {SMARDEX_REMOVE_LIQUIDITY} command using permit2
     * @custom:given A created liquidity pair with token already minted
     * @custom:and The permit2 contract is allowed to spend the liquidity token by the user
     * @custom:when The {execute} function is called for {SMARDEX_REMOVE_LIQUIDITY}
     * @custom:then The {SMARDEX_REMOVE_LIQUIDITY} command should be executed
     * @custom:and The `WSTETH` balance of the user should be increased
     * @custom:and The `WETH` balance of the user should be increased
     */
    function test_executeSmardexRemoveLiquidityRouterPermit2() public {
        test_executeSmardexAddLiquidityRouterBalance();

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));
        _removeParams.liquidity = pair.balanceOf(address(this));

        pair.approve(address(permit2), type(uint256).max);
        permit2.approve(address(pair), address(router), type(uint160).max, type(uint48).max);

        uint256 wstethBalanceBefore = IERC20(WSTETH).balanceOf(address(this));
        uint256 wethBalanceBefore = IERC20(WETH).balanceOf(address(this));

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, true, type(uint256).max);
        router.execute(commands, inputs);

        assertGt(
            IERC20(WSTETH).balanceOf(address(this)),
            wstethBalanceBefore,
            "The `WSTETH` user balance should be increased"
        );
        assertGt(
            IERC20(WETH).balanceOf(address(this)), wethBalanceBefore, "The `WETH` user balance should be increased"
        );
    }

    /**
     * @custom:scenario Test the {SMARDEX_REMOVE_LIQUIDITY} with identical addresses
     * @custom:when The {execute} function is called for {SMARDEX_REMOVE_LIQUIDITY} with identical addresses
     * @custom:then The {SMARDEX_REMOVE_LIQUIDITY} command should revert with {InvalidAddress}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityIdenticalAddresses() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        _removeParams.tokenA = address(0);
        _removeParams.tokenB = address(0);

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.InvalidAddress.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the {SMARDEX_REMOVE_LIQUIDITY} with tokenA or tokenB address equal the zero address
     * @custom:when The {execute} function is called for {SMARDEX_REMOVE_LIQUIDITY} with a tokenA equal zero address
     * @custom:then The {SMARDEX_REMOVE_LIQUIDITY} command should revert with {InvalidAddress}
     * @custom:when The {execute} function is called for {SMARDEX_REMOVE_LIQUIDITY} with a tokenB equal zero address
     * @custom:then The {SMARDEX_REMOVE_LIQUIDITY} command should revert with {InvalidAddress}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityZeroAddress() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        _removeParams.tokenA = address(0);
        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);
        vm.expectRevert(ISmardexRouterErrors.InvalidAddress.selector);
        router.execute(commands, inputs);

        _removeParams.tokenA = WSTETH;
        _removeParams.tokenB = address(0);
        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);
        vm.expectRevert(ISmardexRouterErrors.InvalidAddress.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the {SMARDEX_REMOVE_LIQUIDITY} with nonexistent pair
     * @custom:when The {execute} function is called for {SMARDEX_REMOVE_LIQUIDITY}
     * @custom:then The {SMARDEX_REMOVE_LIQUIDITY} command should revert with {InvalidPair}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityNoPair() public {
        address one = address(1);
        address two = address(2);

        assertEq(smardexFactory.getPair(one, two), address(0), "Should be nonexistent pair");

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        _removeParams.tokenA = one;
        _removeParams.tokenB = two;

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.InvalidPair.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the {SMARDEX_REMOVE_LIQUIDITY} with insufficient amount A
     * @custom:when The {execute} function is called for {SMARDEX_REMOVE_LIQUIDITY}
     * @custom:then The {SMARDEX_REMOVE_LIQUIDITY} command should revert with {InsufficientAmountA}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityInsufficientAmountA() public {
        test_executeSmardexAddLiquidityRouterBalance();

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));
        _removeParams.liquidity = pair.balanceOf(address(this));
        _removeParams.amountAMin = type(uint256).max;

        pair.transfer(address(router), _removeParams.liquidity);

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.InsufficientAmountA.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the {SMARDEX_REMOVE_LIQUIDITY} with insufficient amount B
     * @custom:when The {execute} function is called for {SMARDEX_REMOVE_LIQUIDITY}
     * @custom:then The {SMARDEX_REMOVE_LIQUIDITY} command should revert with {InsufficientAmountB}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityInsufficientAmountB() public {
        test_executeSmardexAddLiquidityRouterBalance();

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));
        _removeParams.liquidity = pair.balanceOf(address(this));
        _removeParams.amountBMin = type(uint256).max;

        pair.transfer(address(router), _removeParams.liquidity);

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.InsufficientAmountB.selector);
        router.execute(commands, inputs);
    }
}
