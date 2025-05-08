// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import { IUsdnErrors } from "@smardex-usdn-contracts-1/src/interfaces/Usdn/IUsdnErrors.sol";
import { DEPLOYER, SDEX, WETH, WSTETH } from "@smardex-usdn-contracts-1/test/utils/Constants.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Test wrap and unwrap commands of the `execute` function
 * @custom:background An initiated universal router
 */
contract TestForkExecuteWusdn is UniversalRouterBaseFixture {
    uint256 constant BASE_AMOUNT = 1 ether;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);

        deal(WETH, address(this), BASE_AMOUNT * 1e3);
        deal(address(sdex), address(this), INITIAL_SDEX_BALANCE);
        deal(address(wstETH), address(this), BASE_AMOUNT * 1e3);

        // mint usdn
        sdex.approve(address(protocol), type(uint256).max);
        wstETH.approve(address(protocol), type(uint256).max);
        usdn.approve(address(wusdn), type(uint256).max);

        bytes32 MINTER_ROLE = usdn.MINTER_ROLE();
        vm.prank(DEPLOYER);
        usdn.grantRole(MINTER_ROLE, address(this));
        usdn.mint(address(this), BASE_AMOUNT * 1e3);
    }

    /**
     * @custom:scenario Test the `WRAP_USDN` command using the router balance
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `usdn`
     * @custom:when The `execute` function is called for `WRAP_USDN` command
     * @custom:then The `WRAP_USDN` command should be executed
     * @custom:and The `usdn` user balance should be increased
     */
    function test_ForkExecuteWrapUsdn() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.WRAP_USDN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.CONTRACT_BALANCE, Constants.MSG_SENDER);

        usdn.transfer(address(router), BASE_AMOUNT);
        uint256 balanceWusdnBefore = wusdn.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(wusdn.balanceOf(address(this)), balanceWusdnBefore, "wrong wusdn balance");
    }

    /**
     * @custom:scenario Test the `WRAP_USDN` command using the router balance
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `usdn`
     * @custom:when The `execute` function is called for `WRAP_USDN` command
     * @custom:then The transaction should revert with `UsdnInsufficientSharesBalance`
     */
    function test_RevertWhen_ForkExecuteWrapUsdnInsufficientSharesBalance() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.WRAP_USDN));

        usdn.transfer(address(router), BASE_AMOUNT);

        uint256 currentShares = usdn.sharesOf(address(router));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(currentShares * 2, Constants.MSG_SENDER);

        vm.expectRevert(
            abi.encodeWithSelector(
                IUsdnErrors.UsdnInsufficientSharesBalance.selector, address(router), currentShares, currentShares * 2
            )
        );
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Test the `UNWRAP_WUSDN` command using the router balance
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `usdn`
     * @custom:when The `execute` function is called for `UNWRAP_WUSDN` command
     * @custom:then The `UNWRAP_WUSDN` command should be executed
     * @custom:and The `usdn` user balance should be increased
     */
    function test_ForkExecuteUnwrapUsdn() external {
        wusdn.wrap(BASE_AMOUNT, address(this));
        uint256 wusdnBalance = wusdn.balanceOf(address(this));
        bytes memory commands = abi.encodePacked(uint8(Commands.UNWRAP_WUSDN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.CONTRACT_BALANCE, Constants.MSG_SENDER);

        wusdn.transfer(address(router), wusdnBalance);
        uint256 balanceUsdnBefore = usdn.balanceOf(address(this));

        router.execute(commands, inputs);

        assertGt(usdn.balanceOf(address(this)), balanceUsdnBefore, "wrong usdn balance");
    }

    /**
     * @custom:scenario The `UNWRAP_WUSDN` command revert when the router doesn't have a high enough balance
     * @custom:given The initiated universal router
     * @custom:and The router should be funded with some `usdn`
     * @custom:when The `execute` function is called for `UNWRAP_WUSDN` command with an amount too high
     * @custom:then The transaction should revert with `ERC20InsufficientBalance`
     */
    function test_RevertWhen_ForkExecuteUnwrapUsdnERC20InsufficientBalance() external {
        wusdn.wrap(BASE_AMOUNT, address(this));
        uint256 wusdnBalance = wusdn.balanceOf(address(this));
        bytes memory commands = abi.encodePacked(uint8(Commands.UNWRAP_WUSDN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(wusdnBalance + 1, Constants.MSG_SENDER, Constants.ADDRESS_THIS);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(router), 0, BASE_AMOUNT + 1)
        );
        router.execute(commands, inputs);
    }
}
