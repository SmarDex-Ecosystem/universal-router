// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { WETH, SDEX } from "usdn-contracts/test/utils/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { ISmardexSwapRouterErrors } from "../../src/interfaces/smardex/ISmardexSwapRouterErrors.sol";
import { ISmardexSwapRouter } from "../../src/interfaces/smardex/ISmardexSwapRouter.sol";

/**
 * @custom:feature Test the universalRouter `smardexSwapCallback` function
 * @custom:background A initiated universal router
 */
contract TestForkSmardexSwapCallback is UniversalRouterBaseFixture, ISmardexSwapRouterErrors {
    function setUp() external {
        _setUp();
    }

    /**
     * @custom:scenario Test the `smardexSwapCallback` with invalid amounts
     * @custom:given The initiated universal router
     * @custom:when The function is called
     * @custom:then The transaction should revert with `CallbackInvalidAmount`
     */
    function test_RevertWhen_ForkCallbackInvalidAmount() external {
        vm.expectRevert(CallbackInvalidAmount.selector);
        router.smardexSwapCallback(0, 0, "");
    }

    /**
     * @custom:scenario Test the `smardexSwapCallback` with invalid amounts
     * @custom:given The initiated universal router
     * @custom:when The function is called
     * @custom:then The transaction should revert with `CallbackInvalidAmount`
     */
    function test_RevertWhen_ForkInvalidPair() external {
        vm.expectRevert(InvalidPair.selector);
        router.smardexSwapCallback(
            1, 0, abi.encode(ISmardexSwapRouter.SwapCallbackData(abi.encodePacked(WETH, SDEX), address(this)))
        );
    }
}
