// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WETH, WSTETH } from "usdn-contracts/test/utils/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { ISmardexRouter } from "../../src/interfaces/smardex/ISmardexRouter.sol";
import { ISmardexPair } from "../../src/interfaces/smardex/ISmardexPair.sol";

/**
 * @custom:feature Test router commands for smardex add liquidity
 * @custom:background A initiated universal router
 */
contract TestForkUniversalRouterSmardexAddLiquidity is UniversalRouterBaseFixture {
    uint256 constant BASE_AMOUNT = 1000 ether;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);

        deal(WSTETH, address(this), BASE_AMOUNT);
        deal(WETH, address(this), BASE_AMOUNT);
    }

    /**
     * @custom:scenario Test the `SMARDEX_ADD_LIQUIDITY` command using the router balance
     * @custom:given The router should be funded with some `WSTETH` and `WETH`
     * @custom:when The `execute` function is called for `SMARDEX_ADD_LIQUIDITY`
     * @custom:then The `SMARDEX_ADD_LIQUIDITY` command should be executed
     * @custom:and The smardex liquidity pair should be created
     * @custom:and The smardex liquidity balance of the user should be positive
     */
    function test_executeSmardexAddLiquidityRouterBalance() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        IERC20(WSTETH).transfer(address(router), BASE_AMOUNT);
        IERC20(WETH).transfer(address(router), BASE_AMOUNT);

        ISmardexRouter.AddLiquidityParams memory params = ISmardexRouter.AddLiquidityParams({
            tokenA: WSTETH,
            tokenB: WETH,
            amountADesired: BASE_AMOUNT,
            amountBDesired: BASE_AMOUNT,
            amountAMin: 0,
            amountBMin: 0,
            fictiveReserveB: 0,
            fictiveReserveAMin: 0,
            fictiveReserveAMax: type(uint128).max
        });

        inputs[0] = abi.encode(params, Constants.MSG_SENDER, false);
        router.execute(commands, inputs);

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));

        assertTrue(address(pair) != address(0), "The smardex pair should be created");
        assertGt(pair.balanceOf(address(this)), 0, "The smardex liquidity balance should be positive");
    }

    /**
     * @custom:scenario Test the `SMARDEX_ADD_LIQUIDITY` command using permit2
     * @custom:given The permit2 contract is allowed to spend `WSTETH` and `WETH` by the user
     * @custom:when The `execute` function is called for `SMARDEX_ADD_LIQUIDITY`
     * @custom:then The `SMARDEX_ADD_LIQUIDITY` command should be executed
     * @custom:and The smardex liquidity pair should be created
     * @custom:and The smardex liquidity balance of the user should be positive
     */
    function test_executeSmardexAddLiquidityPermit2() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        IERC20(WSTETH).approve(address(permit2), type(uint256).max);
        IERC20(WETH).approve(address(permit2), type(uint256).max);
        permit2.approve(WSTETH, address(router), type(uint160).max, type(uint48).max);
        permit2.approve(WETH, address(router), type(uint160).max, type(uint48).max);

        ISmardexRouter.AddLiquidityParams memory params = ISmardexRouter.AddLiquidityParams({
            tokenA: WSTETH,
            tokenB: WETH,
            amountADesired: BASE_AMOUNT,
            amountBDesired: BASE_AMOUNT,
            amountAMin: 0,
            amountBMin: 0,
            fictiveReserveB: 0,
            fictiveReserveAMin: 0,
            fictiveReserveAMax: type(uint128).max
        });

        inputs[0] = abi.encode(params, Constants.MSG_SENDER, true);
        router.execute(commands, inputs);

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(WSTETH, WETH));

        assertTrue(address(pair) != address(0), "The smardex pair should be created");
        assertGt(pair.balanceOf(address(this)), 0, "The smardex liquidity balance should be positive");
    }
}
