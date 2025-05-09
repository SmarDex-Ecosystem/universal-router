// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { SDEX, WETH } from "@smardex-usdn-contracts-1/test/utils/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { ISmardexRouter } from "../../src/interfaces/smardex/ISmardexRouter.sol";
import { ISmardexRouterErrors } from "../../src/interfaces/smardex/ISmardexRouterErrors.sol";

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
