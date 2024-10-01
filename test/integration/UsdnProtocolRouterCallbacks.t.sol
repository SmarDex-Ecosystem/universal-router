// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IUsdn } from "usdn-contracts/src/interfaces/Usdn/IUsdn.sol";

import { IUsdnProtocolRouterErrors } from "../../src/interfaces/usdn/IUsdnProtocolRouterErrors.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

/// @custom:feature Test the USDN protocol router callbacks
contract TestUsdnProtocolRouterCallbacks is UniversalRouterBaseFixture {
    function setUp() public {
        _setUp(DEFAULT_PARAMS);
    }

    /**
     * @custom:scenario Calls the callbacks from an invalid sender
     * @custom:when The callback functions are called
     * @custom:then The transaction should revert with `UsdnProtocolRouterInvalidSender`
     */
    function test_RevertWhen_invalidSenderCallbacks() public {
        vm.expectRevert(IUsdnProtocolRouterErrors.UsdnProtocolRouterInvalidSender.selector);
        router.transferCallback(IERC20Metadata(address(0)), 0, address(0));

        vm.expectRevert(IUsdnProtocolRouterErrors.UsdnProtocolRouterInvalidSender.selector);
        router.usdnTransferCallback(IUsdn(address(0)), 0);
    }
}
