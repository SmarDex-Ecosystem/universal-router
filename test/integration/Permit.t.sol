// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { SigUtils } from "./utils/SigUtils.sol";

import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Doing a permit approval through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterPermit is UniversalRouterBaseFixture {
    SigUtils internal _sigUtils;

    function setUp() public {
        _setUp();
        deal(address(wstETH), vm.addr(1), 1 ether);
        deal(vm.addr(1), 1e6 ether);
        _sigUtils = new SigUtils();
    }

    /**
     * @custom:scenario Using a permit approval through the router to transfer assets
     * @custom:given The user has 1 wstETH
     * @custom:when The user initiates a permit through the router
     * @custom:and A transfer from is initiated
     * @custom:then The transfer is successful
     */
    function test_permit() public {
        uint256 wstETHBalanceBefore = wstETH.balanceOf(address(this));

        // commands building
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.PERMIT)) | Commands.FLAG_ALLOW_REVERT);
        // inputs building
        bytes[] memory inputs = new bytes[](1);
        // permits
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1, _sigUtils.getDigest(vm.addr(1), address(this), 1 ether, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR())
        );
        inputs[0] = abi.encode(address(wstETH), address(this), 1 ether, type(uint256).max, v, r, s);
        // execute
        vm.prank(vm.addr(1));
        router.execute(commands, inputs);

        wstETH.transferFrom(vm.addr(1), address(this), 1 ether);

        assertEq(wstETH.balanceOf(address(this)), wstETHBalanceBefore + 1 ether, "wstETH balance after transfer");
    }

    receive() external payable { }
}
