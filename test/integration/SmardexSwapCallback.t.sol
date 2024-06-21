// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { WETH, SDEX } from "usdn-contracts/test/utils/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { SmardexSwapRouter } from "../../src/modules/smardex/SmardexSwapRouter.sol";

/**
 * @custom:feature Test the universalRouter `smardexSwapCallback` function
 * @custom:background A initiated universal router
 */
contract TestForkSmardexSwapCallback is UniversalRouterBaseFixture {
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
        vm.expectRevert(SmardexSwapRouter.CallbackInvalidAmount.selector);
        router.smardexSwapCallback(0, 0, "");
    }

    /**
     * @custom:scenario Test the `smardexSwapCallback` with invalid amounts
     * @custom:given The initiated universal router
     * @custom:when The function is called
     * @custom:then The transaction should revert with `CallbackInvalidAmount`
     */
    function test_RevertWhen_ForkInvalidPair() external {
        vm.expectRevert(SmardexSwapRouter.InvalidPair.selector);
        router.smardexSwapCallback(
            1, 0, abi.encode(SmardexSwapRouter.SwapCallbackData(abi.encodePacked(WETH, SDEX), address(this)))
        );
    }
}
