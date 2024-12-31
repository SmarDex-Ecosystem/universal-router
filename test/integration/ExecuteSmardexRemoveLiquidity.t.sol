// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WETH, WSTETH } from "usdn-contracts/test/utils/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { ISmardexRouter } from "../../src/interfaces/smardex/ISmardexRouter.sol";
import { ISmardexRouterErrors } from "../../src/interfaces/smardex/ISmardexRouterErrors.sol";
import { ISmardexPair } from "../../src/interfaces/smardex/ISmardexPair.sol";

/**
 * @custom:feature The `SMARDEX_REMOVE_LIQUIDITY` command of the Universal Router
 * @custom:background A deployed universal router
 */
contract TestForkUniversalRouterSmardexRemoveLiquidity is UniversalRouterBaseFixture {
    uint256 constant BASE_AMOUNT = 1000 ether;

    ISmardexRouter.RemoveLiquidityParams internal _removeParams = ISmardexRouter.RemoveLiquidityParams({
        tokenA: WETH,
        tokenB: WSTETH,
        liquidity: 0,
        amountAMin: 0,
        amountBMin: 0
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
        _addLiquidity(WSTETH, WETH, BASE_AMOUNT, BASE_AMOUNT);

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
     * @custom:given A created liquidity pair with token already minted
     * @custom:and The permit2 contract is allowed to spend the liquidity token by the user
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called
     * @custom:then The `SMARDEX_REMOVE_LIQUIDITY` command should be executed
     * @custom:and The `WSTETH` balance of the user should be increased
     * @custom:and The `WETH` balance of the user should be increased
     */
    function test_executeSmardexRemoveLiquidityRouterPermit2() public {
        _addLiquidity(WSTETH, WETH, BASE_AMOUNT, BASE_AMOUNT);

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
     * @custom:scenario Remove liquidity identical addresses
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called with identical addresses
     * @custom:then The `SMARDEX_REMOVE_LIQUIDITY` command should revert with {InvalidAddress}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityIdenticalAddresses() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_REMOVE_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        _removeParams.tokenA = address(0);
        _removeParams.tokenB = address(0);

        inputs[0] = abi.encode(_removeParams, Constants.MSG_SENDER, false, type(uint256).max);

        vm.expectRevert(ISmardexRouterErrors.InvalidTokenAddress.selector);
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Remove liquidity tokenA or tokenB address equal the zero address
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called with a tokenA equal zero address
     * @custom:then The `SMARDEX_REMOVE_LIQUIDITY` command should revert with {InvalidAddress}
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called with a tokenB equal zero address
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
     * @custom:scenario Remove liquidity nonexistent pair
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called
     * @custom:then The `SMARDEX_REMOVE_LIQUIDITY` command should revert with {InvalidPair}
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
     * @custom:scenario Remove liquidity insufficient amount A
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called
     * @custom:then The `SMARDEX_REMOVE_LIQUIDITY` command should revert with {InsufficientAmountA}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityInsufficientAmountA() public {
        _addLiquidity(WSTETH, WETH, BASE_AMOUNT, BASE_AMOUNT);

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
     * @custom:scenario Remove liquidity insufficient amount B
     * @custom:when The `SMARDEX_REMOVE_LIQUIDITY` command is called
     * @custom:then The `SMARDEX_REMOVE_LIQUIDITY` command should revert with {InsufficientAmountB}
     */
    function test_RevertWhen_executeSmardexRemoveLiquidityInsufficientAmountB() public {
        _addLiquidity(WSTETH, WETH, BASE_AMOUNT, BASE_AMOUNT);

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

    function _addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) internal {
        bytes memory commands = abi.encodePacked(uint8(Commands.SMARDEX_ADD_LIQUIDITY));
        bytes[] memory inputs = new bytes[](1);

        ISmardexRouter.AddLiquidityParams memory addLiquidityParams = ISmardexRouter.AddLiquidityParams({
            tokenA: tokenA,
            tokenB: tokenB,
            amountADesired: amountA,
            amountBDesired: amountB,
            amountAMin: 0,
            amountBMin: 0,
            fictiveReserveB: 0,
            fictiveReserveAMin: 0,
            fictiveReserveAMax: 0
        });

        deal(tokenA, address(router), amountA);
        deal(tokenB, address(router), amountB);

        inputs[0] = abi.encode(addLiquidityParams, Constants.MSG_SENDER, false, type(uint256).max);
        router.execute(commands, inputs);
    }
}
