// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { USER_1 } from "@smardex-usdn-contracts-1/test/utils/Constants.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { ISmardexRouterErrors } from "../../src/interfaces/smardex/ISmardexRouterErrors.sol";
import { IPaymentLibTypes } from "../../src/interfaces/usdn/IPaymentLibTypes.sol";
import { IUsdnProtocolRouterTypes } from "../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Entire workflow of open position through the router
 * @custom:background An initiated universal router
 */
contract TestForkWorkflowOpenPosition is UniversalRouterBaseFixture, ISmardexRouterErrors {
    uint256 constant OPEN_POSITION_AMOUNT = 3 ether;
    uint256 internal _securityOpenPosition;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);
        _securityOpenPosition = protocol.getSecurityDepositValue();
    }

    /**
     * @custom:action Entire workflow of opening a position through the router
     * @custom:given The user has some ETH
     * @custom:when The user runs some commands to opening a position through the router
     * @custom:then The open position is initiated successfully
     * @custom:and All tokens are returned to the user
     */
    function test_ForkWorkflowOpenPosition() external {
        bytes memory commands = abi.encodePacked(
            uint8(Commands.TRANSFER), uint8(Commands.INITIATE_OPEN), uint8(Commands.SWEEP), uint8(Commands.SWEEP)
        );

        bytes[] memory inputs = new bytes[](4);
        inputs[0] = abi.encode(Constants.ETH, wstETH, OPEN_POSITION_AMOUNT * 2);
        inputs[1] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                IPaymentLibTypes.PaymentType.Transfer,
                Constants.CONTRACT_BALANCE,
                DEFAULT_PARAMS.initialLiqPrice,
                type(uint128).max,
                maxLeverage,
                USER_1,
                USER_1,
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                _securityOpenPosition
            )
        );
        inputs[2] = abi.encode(Constants.ETH, address(this), 0, 0);
        inputs[3] = abi.encode(wstETH, address(this), 0, 0);

        router.execute{ value: _securityOpenPosition + OPEN_POSITION_AMOUNT * 2 }(commands, inputs);

        LongPendingAction memory action = protocol.i_toLongPendingAction(protocol.getUserPendingAction(USER_1));

        assertTrue(action.action == ProtocolAction.ValidateOpenPosition, "The action type is wrong");
        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, USER_1, "pending action validator");
        assertEq(action.tickVersion, 0, "pending action tick version");
        assertEq(action.securityDepositValue, _securityOpenPosition, "pending action security deposit value");
        assertEq(address(router).balance, 0, "ETH balance");
        assertEq(IERC20(wstETH).balanceOf(address(router)), 0, "wstETH balance");
    }

    receive() external payable { }
}
