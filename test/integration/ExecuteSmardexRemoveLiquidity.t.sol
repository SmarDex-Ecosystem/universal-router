// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WETH, WSTETH } from "@smardex-usdn-contracts-1/test/utils/Constants.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { ISmardexPair } from "../../src/interfaces/smardex/ISmardexPair.sol";
import { ISmardexRouter } from "../../src/interfaces/smardex/ISmardexRouter.sol";
import { ISmardexRouterErrors } from "../../src/interfaces/smardex/ISmardexRouterErrors.sol";
import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature The `SMARDEX_REMOVE_LIQUIDITY` command of the Universal Router
 * @custom:background A deployed universal router
 */
contract TestForkUniversalRouterSmardexRemoveLiquidity is UniversalRouterBaseFixture {
    uint256 constant BASE_AMOUNT = 1000 ether;

    ISmardexRouter.RemoveLiquidityParams internal _removeParams = ISmardexRouter.RemoveLiquidityParams({
        tokenA: WETH, tokenB: WSTETH, liquidity: 0, amountAMin: 0, amountBMin: 0
    });

    function setUp() external {
        _setUp(DEFAULT_PARAMS);
    }

    /**
     * @custom:scenario Remove liquidity with a exceeded deadline
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called
     * @custom:then The `SMARDEX_REMOVE_LIQUIDITY` command should revert with `DeadlineExceeded`
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityDeadlineExceeded() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, 0);

        vm.expectRevert(ISmardexRouterErrors.DeadlineExceeded.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Remove liquidity using the router balance
     * @custom:given A created liquidity pair
     * @custom:and The router is funded with some liquidity tokens
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called
     * @custom:then The `WSTETH` and `WETH` balances of the user should be increased
     */
    function test_executeSmardexRemoveLiquidityRouterBalance() public {
        _addWstethWethLiquidity();

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
     * @custom:scenario Remove liquidity using permit2
     * @custom:given A created liquidity pair
     * @custom:and The permit2 contract is allowed to spend the LP tokens
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called
     * @custom:then The `WSTETH` and `WETH` balances of the user should be increased
     */
    function test_executeSmardexRemoveLiquidityRouterPermit2() public {
        _addWstethWethLiquidity();

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
     * @custom:scenario Remove liquidity of two identical addresses
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called with two identical addresses
     * @custom:then The `SMARDEX_REMOVE_LIQUIDITY` command should revert with {InvalidAddress}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityIdenticalAddresses() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        _removeParams.tokenA = WETH;
        _removeParams.tokenB = WETH;

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.InvalidTokenAddress.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Remove liquidity with one of the addresses equal to zero
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called with a zero address
     * @custom:then The `SMARDEX_REMOVE_LIQUIDITY` command should revert with {InvalidAddress}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityZeroAddress() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        _removeParams.tokenA = address(0);
        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);
        vm.expectRevert(ISmardexRouterErrors.InvalidTokenAddress.selector);
        router.execute(commands, inputs);

        _removeParams.tokenA = WSTETH;
        _removeParams.tokenB = address(0);
        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);
        vm.expectRevert(ISmardexRouterErrors.InvalidTokenAddress.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Try to remove liquidity from a non-existent pair
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called
     * @custom:then The `SMARDEX_REMOVE_LIQUIDITY` command should revert with {InvalidPair}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityNoPair() public {
        assertEq(smardexFactory.getPair(address(1), address(2)), address(0), "No pair should exist");

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        _removeParams.tokenA = address(1);
        _removeParams.tokenB = address(2);

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.InvalidPair.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Remove liquidity exceeds slippage tolerance
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called
     * @custom:then The `SMARDEX_REMOVE_LIQUIDITY` command should revert with {InsufficientAmountA}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityInsufficientAmountA() public {
        _addWstethWethLiquidity();

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));
        _removeParams.liquidity = pair.balanceOf(address(this));
        _removeParams.amountAMin = type(uint256).max;

        pair.transfer(address(router), _removeParams.liquidity);

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.InsufficientAmountA.selector);
        router.execute(commands, inputs);

        _removeParams.amountAMin = 0;
        _removeParams.amountBMin = type(uint256).max;
        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.InsufficientAmountB.selector);
        router.execute(commands, inputs);
    }

    function _addWstethWethLiquidity() internal {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        ISmardexRouter.AddLiquidityParams memory addLiquidityParams = ISmardexRouter.AddLiquidityParams({
            tokenA: WSTETH,
            tokenB: WETH,
            amountADesired: BASE_AMOUNT,
            amountBDesired: BASE_AMOUNT,
            amountAMin: 0,
            amountBMin: 0,
            fictiveReserveB: 0,
            fictiveReserveAMin: 0,
            fictiveReserveAMax: 0
        });

        deal(WSTETH, address(router), BASE_AMOUNT);
        deal(WETH, address(router), BASE_AMOUNT);

        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, false, type(uint256).max);
        router.execute(commands, inputs);
    }
}
