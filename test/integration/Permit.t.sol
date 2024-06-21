// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
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
        bytes memory commands = abi.encodePacked(uint8(Commands.PERMIT) | uint8(Commands.FLAG_ALLOW_REVERT));
        // inputs building
        bytes[] memory inputs = new bytes[](1);
        // permits signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            _sigUtils.getDigest(
                vm.addr(1),
                address(this),
                1 ether,
                ERC20Permit(wstETH).nonces(vm.addr(1)),
                type(uint256).max,
                wstETH.DOMAIN_SEPARATOR()
            )
        );
        inputs[0] = abi.encode(address(wstETH), address(vm.addr(1)), address(this), 1 ether, type(uint256).max, v, r, s);
        // execute
        vm.prank(vm.addr(1));
        router.execute(commands, inputs);

        wstETH.transferFrom(vm.addr(1), address(this), 1 ether);

        assertEq(wstETH.balanceOf(address(this)), wstETHBalanceBefore + 1 ether, "wstETH balance after transfer");
    }

    /**
     * @custom:scenario An attackant steals the signature of a permit approval to transfer assets
     * @custom:given The user has 1 `wstETH`
     * @custom:when The user initiates a permit through the router with a `FLAG_ALLOW_REVERT`
     * @custom:and An attackant steals the signature of the user and front-runs the permit approval through the router
     * @custom:and A transfer from is initiated, consuming the approval
     * @custom:then The user permit tx is not reverting
     * @custom:and The transfer is successful
     */
    function test_griefing() public {
        uint256 wstETHBalanceBefore = wstETH.balanceOf(address(this));

        // commands building
        bytes memory commands = abi.encodePacked((uint8(Commands.PERMIT)) | uint8(Commands.FLAG_ALLOW_REVERT));

        // inputs building
        bytes[] memory inputs = new bytes[](1);

        // permits
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            _sigUtils.getDigest(
                vm.addr(1),
                address(this),
                1 ether,
                ERC20Permit(wstETH).nonces(vm.addr(1)),
                type(uint256).max,
                wstETH.DOMAIN_SEPARATOR()
            )
        );
        inputs[0] = abi.encode(address(wstETH), vm.addr(1), address(this), 1 ether, type(uint256).max, v, r, s);

        // executing by an attackant
        vm.prank(vm.addr(2)); // griefing
        router.execute(commands, inputs);

        // executing by the victim (the real user)
        vm.prank(vm.addr(1)); // griefed user
        router.execute(commands, inputs);

        wstETH.transferFrom(vm.addr(1), address(this), 1 ether);

        assertEq(wstETH.balanceOf(address(this)), wstETHBalanceBefore + 1 ether, "wstETH balance after transfer");
    }

    /**
     * @custom:scenario An attackant steals the signature of a permit approval to transfer assets
     * @custom:given The user has 1 `wstETH`
     * @custom:when The user initiates a permit through the router without any flag
     * @custom:and An attackant steals the signature of the user and front-runs the permit approval through the router
     * @custom:and A transfer from is initiated, consuming the approval
     * @custom:then The user permit tx is reverting
     * @custom:and The transfer is successful
     */
    function test_RevertWhen_griefing() public {
        uint256 wstETHBalanceBefore = wstETH.balanceOf(address(this));

        // commands building
        bytes memory commands = abi.encodePacked(uint8(Commands.PERMIT)); // victim choose to be reverted in
            // case of griefing because mask is applied

        // inputs building
        bytes[] memory inputs = new bytes[](1);

        // permits
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            _sigUtils.getDigest(
                vm.addr(1), // victim
                address(this),
                1 ether,
                ERC20Permit(wstETH).nonces(vm.addr(1)),
                type(uint256).max,
                wstETH.DOMAIN_SEPARATOR()
            )
        );
        inputs[0] = abi.encode(address(wstETH), vm.addr(1), address(this), 1 ether, type(uint256).max, v, r, s);

        // executing by an attackant
        vm.prank(vm.addr(2)); // griefing
        router.execute(commands, inputs);

        // executing by the victim (the real user)
        vm.prank(vm.addr(1)); // griefed user
        vm.expectRevert();
        router.execute(commands, inputs);

        wstETH.transferFrom(vm.addr(1), address(this), 1 ether); // still griefed

        assertEq(wstETH.balanceOf(address(this)), wstETHBalanceBefore + 1 ether, "wstETH balance after transfer");
    }

    receive() external payable { }
}
