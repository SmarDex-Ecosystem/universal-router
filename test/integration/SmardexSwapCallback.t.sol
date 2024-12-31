// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { WETH, SDEX } from "usdn-contracts/test/utils/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { ISmardexRouterErrors } from "../../src/interfaces/smardex/ISmardexRouterErrors.sol";
import { ISmardexRouter } from "../../src/interfaces/smardex/ISmardexRouter.sol";

/**
 * @custom:feature Test the universalRouter `smardexSwapCallback` function
 * @custom:background A initiated universal router
 */
contract TestForkSmardexSwapCallback is UniversalRouterBaseFixture {
    function setUp() external {
        _setUp(DEFAULT_PARAMS);
    }

    /**
     * @custom:scenario Test the `smardexSwapCallback` with invalid amounts
     * @custom:given The initiated universal router
     * @custom:when The function is called
     * @custom:then The transaction should revert with `CallbackInvalidAmount`
     */
    function test_RevertWhen_ForkCallbackInvalidAmount() external {
        vm.expectRevert(ISmardexRouterErrors.CallbackInvalidAmount.selector);
        router.smardexSwapCallback(0, 0, "");
    }

    /**
     * @custom:scenario Test the `smardexSwapCallback` with invalid amounts
     * @custom:given The initiated universal router
     * @custom:when The function is called
     * @custom:then The transaction should revert with `CallbackInvalidAmount`
     */
    function test_RevertWhen_ForkInvalidPair() external {
        vm.expectRevert(ISmardexRouterErrors.InvalidPair.selector);
        router.smardexSwapCallback(
            1, 0, abi.encode(ISmardexRouter.SwapCallbackData(abi.encodePacked(WETH, SDEX), address(this)))
        );
    }
}
