// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { ISmardexRouterErrors } from "../../src/interfaces/smardex/ISmardexRouterErrors.sol";
import { ISmardexRouter } from "../../src/interfaces/smardex/ISmardexRouter.sol";

/**
 * @custom:feature Test the universalRouter `smardexMintCallback` function
 * @custom:background A initiated universal router
 */
contract TestForkSmardexMintCallback is UniversalRouterBaseFixture {
    function setUp() external {
        _setUp(DEFAULT_PARAMS);
    }

    /**
     * @custom:scenario Test the `smardexMintCallback` with invalid amounts
     * @custom:given The initiated universal router
     * @custom:when The function is called
     * @custom:then The transaction should revert with `CallbackInvalidAmount`
     */
    function test_RevertWhen_ForkCallbackInvalidAmount() external {
        vm.expectRevert(ISmardexRouterErrors.CallbackInvalidAmount.selector);
        router.smardexMintCallback(ISmardexRouter.MintCallbackData(address(0), address(0), 0, 0, address(0)));
    }

    /**
     * @custom:scenario Test the `smardexMintCallback` with invalid amounts
     * @custom:given The initiated universal router
     * @custom:when The function is called
     * @custom:then The transaction should revert with `CallbackInvalidAmount`
     */
    function test_RevertWhen_ForkInvalidPair() external {
        vm.expectRevert(ISmardexRouterErrors.InvalidPair.selector);
        router.smardexMintCallback(ISmardexRouter.MintCallbackData(address(0), address(0), 1, 0, address(0)));
    }
}
