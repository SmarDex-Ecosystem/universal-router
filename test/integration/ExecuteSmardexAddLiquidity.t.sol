// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WETH, WSTETH } from "usdn-contracts/test/utils/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { PoolHelpers } from "../../src/libraries/smardex/PoolHelpers.sol";
import { ISmardexRouter } from "../../src/interfaces/smardex/ISmardexRouter.sol";
import { ISmardexRouterErrors } from "../../src/interfaces/smardex/ISmardexRouterErrors.sol";
import { ISmardexPair } from "../../src/interfaces/smardex/ISmardexPair.sol";

/**
 * @custom:feature The `SMARDEX_ADD_LIQUIDITY` command of the Universal Router
 * @custom:background A deployed universal router
 */
contract TestForkUniversalRouterSmardexAddLiquidity is UniversalRouterBaseFixture {
    uint256 constant BASE_AMOUNT = 1000 ether;

    ISmardexRouter.AddLiquidityParams internal addLiquidityParams;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);

        deal(WSTETH, address(this), BASE_AMOUNT);
        deal(WETH, address(this), BASE_AMOUNT);

        addLiquidityParams = ISmardexRouter.AddLiquidityParams({
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
    }

    /**
     * @custom:scenario Add liquidity with an exceeded deadline
     * @custom:when The `SMARDEX_ADD_LIQUIDITY` command is called with an exceeded deadline
     * @custom:then The call should revert with a `DeadlineExceeded` error
     */
    function test_RevertWhen_executeSmardexAddLiquidityDeadlineExceeded() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, false, 0);
        vm.expectRevert(ISmardexRouterErrors.DeadlineExceeded.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Add liquidity to a non-existing pair using the router balance
     * @custom:given The router is funded with some `WSTETH` and `WETH`
     * @custom:and The `WSTETH`/`WETH` pair does not exist on Smardex
     * @custom:when The `SMARDEX_ADD_LIQUIDITY` command is called
     * @custom:then The liquidity pair should be created
     * @custom:and The LP tokens balance of the user should be greater than 0
     */
    function test_executeSmardexAddLiquidityRouterBalance() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));
        assertEq(address(pair), address(0), "The pair should not exist yet");

        IERC20(WSTETH).transfer(address(router), BASE_AMOUNT);
        IERC20(WETH).transfer(address(router), BASE_AMOUNT);

        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, false, type(uint256).max);
        router.execute(commands, inputs);

        pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));

        assertTrue(address(pair) != address(0), "The smardex pair should be created");
        assertGt(pair.balanceOf(address(this)), 0, "The smardex liquidity balance should be positive");
    }

    /**
     * @custom:scenario Add liquidity to a non-existing pair using Permit2
     * @custom:given The permit2 contract allows the spending of the user's `WSTETH` and `WETH` tokens
     * @custom:and The `WSTETH`/`WETH` pair does not exist on Smardex
     * @custom:when The `SMARDEX_ADD_LIQUIDITY` command is executed
     * @custom:then The liquidity pair should be created
     * @custom:and The LP tokens balance of the user should be greater than 0
     */
    function test_executeSmardexAddLiquidityPermit2() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));
        assertEq(address(pair), address(0), "The pair should not exist yet");

        IERC20(WSTETH).approve(address(permit2), type(uint256).max);
        IERC20(WETH).approve(address(permit2), type(uint256).max);
        permit2.approve(WSTETH, address(router), type(uint160).max, type(uint48).max);
        permit2.approve(WETH, address(router), type(uint160).max, type(uint48).max);

        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, true, type(uint256).max);
        router.execute(commands, inputs);

        pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));

        assertTrue(address(pair) != address(0), "The smardex pair should be created");
        assertGt(pair.balanceOf(address(this)), 0, "The smardex liquidity balance should be positive");
    }

    /**
     * @custom:scenario Add liquidity with a price impact pushing the price too high
     * @custom:given An existing liquidity pair with LP tokens already minted
     * @custom:when The `SMARDEX_ADD_LIQUIDITY` command is executed
     * @custom:then The reserves in the pair would be in the following state:
     * `reserveAFic * params.fictiveReserveB > params.fictiveReserveAMax * reserveB`
     * @custom:and The call should revert with a `PriceTooHigh` error
     */
    function test_RevertWhen_executeSmardexAddLiquidityPriceTooHigh() public {
        test_executeSmardexAddLiquidityRouterBalance();
        addLiquidityParams.fictiveReserveB = 1;

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, true, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.PriceTooHigh.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Add liquidity with a price impact pushing the price too low
     * @custom:given An existing liquidity pair with LP tokens already minted
     * @custom:when The `SMARDEX_ADD_LIQUIDITY` command is executed
     * @custom:then The reserves in the pair would be in the following state:
     * `reserveAFic * params.fictiveReserveB > params.fictiveReserveAMax * reserveB`
     * @custom:and The call should revert with a `PriceTooLow` error
     */
    function test_RevertWhen_executeSmardexAddLiquidityPriceTooLow() public {
        test_executeSmardexAddLiquidityRouterBalance();
        addLiquidityParams.fictiveReserveAMin = 1;

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, true, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.PriceTooLow.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Add liquidity with an output amount lower than the requested minimum amount
     * @custom:given A created liquidity pair with token already minted
     * @custom:when The SMARDEX_ADD_LIQUIDITY command is executed with `amountBOptimal < amountBMin`
     * @custom:then The call should revert with an `InsufficientAmountB`
     */
    function test_RevertWhen_executeSmardexAddLiquidityInsufficientAmountB() public {
        test_executeSmardexAddLiquidityRouterBalance();
        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));
        (uint256 reserveA, uint256 reserveB,,) = PoolHelpers.getAllReserves(pair, WSTETH);
        addLiquidityParams.amountADesired = 1;
        uint256 amountBOptimal = PoolHelpers.quote(addLiquidityParams.amountADesired, reserveA, reserveB);
        addLiquidityParams.amountBDesired = amountBOptimal;
        addLiquidityParams.amountBMin = amountBOptimal + 1;

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, true, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.InsufficientAmountB.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Add liquidity with an input amount higher than the requested minimum amount
     * @custom:given A created liquidity pair with LP tokens already minted
     * @custom:when The `SMARDEX_ADD_LIQUIDITY` command is executed with `amountAOptimal < amountAMin`
     * @custom:then The call should revert with `InsufficientAmountA`
     */
    function test_RevertWhen_executeSmardexAddLiquidityInsufficientAmountA() public {
        test_executeSmardexAddLiquidityRouterBalance();
        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));
        (uint256 reserveA, uint256 reserveB,,) = PoolHelpers.getAllReserves(pair, WSTETH);
        addLiquidityParams.amountADesired = 2;
        uint256 amountBOptimal = PoolHelpers.quote(addLiquidityParams.amountADesired, reserveA, reserveB);
        addLiquidityParams.amountBDesired = amountBOptimal - 1;
        uint256 amountAOptimal = PoolHelpers.quote(addLiquidityParams.amountBDesired, reserveB, reserveA);
        addLiquidityParams.amountAMin = amountAOptimal + 1;

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, true, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.InsufficientAmountA.selector);
        router.execute(commands, inputs);
    }
}
