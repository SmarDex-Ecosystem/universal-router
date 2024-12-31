// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { WETH, WSTETH } from "usdn-contracts/test/utils/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { ISmardexRouterErrors } from "../../src/interfaces/smardex/ISmardexRouterErrors.sol";
import { ISmardexRouter } from "../../src/interfaces/smardex/ISmardexRouter.sol";

/**
 * @custom:feature The `smardexMintCallback` function of the Universal Router
 * @custom:background A deployed universal router
 */
contract TestForkSmardexMintCallback is UniversalRouterBaseFixture {
    function setUp() external {
        _setUp(DEFAULT_PARAMS);
    }

    /**
     * @custom:scenario Callback is called with invalid amounts
     * @custom:given An existing token pair
     * @custom:when The function is called
     * @custom:then The transaction should revert with `CallbackInvalidAmount`
     */
    function test_RevertWhen_invalidAmount() external {
        address pair = smardexFactory.createPair(WSTETH, WETH);

        vm.prank(pair);
        vm.expectRevert(ISmardexRouterErrors.CallbackInvalidAmount.selector);
        router.smardexMintCallback(ISmardexRouter.MintCallbackData(WSTETH, WETH, 0, 0, address(0)));
    }

    /**
     * @custom:scenario Callback is called by an address that is not the expected pair
     * @custom:given An existing token pair
     * @custom:when The function is called
     * @custom:then The transaction should revert with a `InvalidPair` error
     */
    function test_RevertWhen_invalidPair() external {
        smardexFactory.createPair(WSTETH, WETH);

        vm.expectRevert(ISmardexRouterErrors.InvalidPair.selector);
        router.smardexMintCallback(ISmardexRouter.MintCallbackData(WSTETH, WETH, 1, 0, address(0)));
    }
}
