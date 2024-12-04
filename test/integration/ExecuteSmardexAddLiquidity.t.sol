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
 * @custom:feature Test router commands for smardex add liquidity
 * @custom:background A initiated universal router
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
     * @custom:scenario Test the {SMARDEX_ADD_LIQUIDITY} command using the router balance
     * @custom:given The router should be funded with some `WSTETH` and `WETH`
     * @custom:when The {execute} function is called for {SMARDEX_ADD_LIQUIDITY}
     * @custom:then The {SMARDEX_ADD_LIQUIDITY} command should be executed
     * @custom:and The smardex liquidity pair should be created
     * @custom:and The smardex liquidity balance of the user should be positive
     */
    function test_executeSmardexAddLiquidityRouterBalance() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        IERC20(WSTETH).transfer(address(router), BASE_AMOUNT);
        IERC20(WETH).transfer(address(router), BASE_AMOUNT);

        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, false);
        router.execute(commands, inputs);

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));

        assertTrue(address(pair) != address(0), "The smardex pair should be created");
        assertGt(pair.balanceOf(address(this)), 0, "The smardex liquidity balance should be positive");
    }

    /**
     * @custom:scenario Test the {SMARDEX_ADD_LIQUIDITY} command using permit2
     * @custom:given The permit2 contract is allowed to spend `WSTETH` and `WETH` by the user
     * @custom:when The {execute} function is called for {SMARDEX_ADD_LIQUIDITY}
     * @custom:then The {SMARDEX_ADD_LIQUIDITY} command should be executed
     * @custom:and The smardex liquidity pair should be created
     * @custom:and The smardex liquidity balance of the user should be positive
     */
    function test_executeSmardexAddLiquidityPermit2() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        IERC20(WSTETH).approve(address(permit2), type(uint256).max);
        IERC20(WETH).approve(address(permit2), type(uint256).max);
        permit2.approve(WSTETH, address(router), type(uint160).max, type(uint48).max);
        permit2.approve(WETH, address(router), type(uint160).max, type(uint48).max);

        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, true);
        router.execute(commands, inputs);

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));

        assertTrue(address(pair) != address(0), "The smardex pair should be created");
        assertGt(pair.balanceOf(address(this)), 0, "The smardex liquidity balance should be positive");
    }

    /**
     * @custom:scenario Test the {SMARDEX_ADD_LIQUIDITY} with a too high price
     * @custom:given A created liquidity pair with token already minted
     * @custom:when The {execute} function is called for {SMARDEX_ADD_LIQUIDITY} to be in the condition:
     * reserveAFic * params.fictiveReserveB > params.fictiveReserveAMax * reserveB
     * @custom:then The {SMARDEX_ADD_LIQUIDITY} command should revert with {PriceTooHigh}
     */
    function test_RevertWhen_executeSmardexAddLiquidityPriceTooHigh() public {
        test_executeSmardexAddLiquidityRouterBalance();
        addLiquidityParams.fictiveReserveB = 1;

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, true);

        vm.expectRevert(ISmardexRouterErrors.PriceTooHigh.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the {SMARDEX_ADD_LIQUIDITY} with a too low price
     * @custom:given A created liquidity pair with token already minted
     * @custom:when The {execute} function is called for {SMARDEX_ADD_LIQUIDITY} to be in the condition:
     * reserveAFic * params.fictiveReserveB < params.fictiveReserveAMin * reserveBFic
     * @custom:then The {SMARDEX_ADD_LIQUIDITY} command should revert with {PriceTooLow}
     */
    function test_RevertWhen_executeSmardexAddLiquidityPriceTooLow() public {
        test_executeSmardexAddLiquidityRouterBalance();
        addLiquidityParams.fictiveReserveAMin = 1;

        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, true);

        vm.expectRevert(ISmardexRouterErrors.PriceTooLow.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the {SMARDEX_ADD_LIQUIDITY} with insufficient amountB
     * @custom:given A created liquidity pair with token already minted
     * @custom:when The {execute} function is called for {SMARDEX_ADD_LIQUIDITY} to be in the condition:
     * amountBOptimal < amountBMin
     * @custom:then The {SMARDEX_ADD_LIQUIDITY} command should revert with {InsufficientAmountB}
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
        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, true);

        vm.expectRevert(ISmardexRouterErrors.InsufficientAmountB.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the {SMARDEX_ADD_LIQUIDITY} with insufficient amountA
     * @custom:given A created liquidity pair with token already minted
     * @custom:when The {execute} function is called for {SMARDEX_ADD_LIQUIDITY} to be in the condition:
     * amountAOptimal < amountAMin
     * @custom:then The {SMARDEX_ADD_LIQUIDITY} command should revert with {InsufficientAmountA}
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
        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, true);

        vm.expectRevert(ISmardexRouterErrors.InsufficientAmountA.selector);
        router.execute(commands, inputs);
    }
}
