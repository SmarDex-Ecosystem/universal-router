// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import { DEPLOYER, USER_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { IUniversalRouter } from "../../src/interfaces/IUniversalRouter.sol";
import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Test commands USDN_TRANSFER_SHARES_FROM
 * @custom:background A initiated universal router
 */
contract TestForkUniversalRouterExecuteUsdnTransferSharesFrom is UniversalRouterBaseFixture {
    uint256 constant BASE_AMOUNT = 1000 ether;
    uint256 usdnSharesAmount;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);

        bytes32 MINTER_ROLE = usdn.MINTER_ROLE();
        vm.prank(DEPLOYER);
        usdn.grantRole(MINTER_ROLE, address(this));
        usdn.mint(address(this), BASE_AMOUNT);
        usdnSharesAmount = usdn.sharesOf(address(this));
    }

    /**
     * @custom:scenario Test the `USDN_TRANSFER_SHARES_FROM` command
     * @custom:given The initiated universal router
     * @custom:and The router should be approved with the correct ERC20 amount
     * @custom:when The `execute` function is called for `USDN_TRANSFER_SHARES_FROM` command
     * @custom:then The `USDN_TRANSFER_SHARES_FROM` command should be executed
     * @custom:and The `wsteth` user balance should be decreased
     * @custom:and The `wsteth` receiver balance should be increased
     */
    function test_executeUsdnTransferSharesFrom() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.USDN_TRANSFER_SHARES_FROM));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(router), usdnSharesAmount);

        usdn.approve(address(router), type(uint256).max);

        router.execute(commands, inputs);

        assertEq(usdn.sharesOf(address(this)), 0, "usdn shares of user should be zero");
        assertEq(usdn.sharesOf(address(router)), usdnSharesAmount, "usdn shares of router should be positive");
    }

    /**
     * @custom:scenario Test the `USDN_TRANSFER_SHARES_FROM` command from a different user
     * @custom:given The initiated universal router
     * @custom:and The router should be approved with the correct ERC20 amount
     * @custom:when The `execute` function is called for `USDN_TRANSFER_SHARES_FROM` command
     * @custom:then The `USDN_TRANSFER_SHARES_FROM` command should be reverted
     */
    function test_RevertWhen_executeUsdnTransferSharesFromDifferentUser() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.USDN_TRANSFER_SHARES_FROM));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(router), usdnSharesAmount);

        usdn.approve(address(router), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniversalRouter.ExecutionFailed.selector,
                0,
                abi.encodeWithSelector(
                    IERC20Errors.ERC20InsufficientAllowance.selector,
                    address(router),
                    0,
                    usdn.convertToTokens(usdnSharesAmount)
                )
            )
        );

        vm.prank(USER_1);
        router.execute(commands, inputs);
    }
}
