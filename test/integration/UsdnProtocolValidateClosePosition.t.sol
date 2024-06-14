// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { ProtocolAction, PositionId } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { PYTH_ETH_USD } from "./utils/Constants.sol";
import { USER_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Validating a close position through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterValidateClosePosition is UniversalRouterBaseFixture {
    uint128 constant OPEN_POSITION_AMOUNT = 2 ether;
    uint128 constant DESIRED_LIQUIDATION = 2500 ether;
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp();
        deal(address(wstETH), address(this), OPEN_POSITION_AMOUNT * 2);
        wstETH.approve(address(protocol), type(uint256).max);
        _securityDeposit = protocol.getSecurityDepositValue();
        (, PositionId memory posId) = protocol.initiateOpenPosition{ value: _securityDeposit }(
            OPEN_POSITION_AMOUNT,
            DESIRED_LIQUIDATION,
            address(this),
            payable(address(this)),
            NO_PERMIT2,
            "",
            EMPTY_PREVIOUS_DATA
        );
        _waitDelay(); // to be realistic because not mandatory
        uint256 ts1 = protocol.getUserPendingAction(address(this)).timestamp;
        (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, ts1 + oracleMiddleware.getValidationDelay());
        protocol.validateOpenPosition{
            value: oracleMiddleware.validationCost(data, ProtocolAction.ValidateOpenPosition)
        }(payable(address(this)), data, EMPTY_PREVIOUS_DATA);
        protocol.initiateClosePosition{ value: _securityDeposit }(
            posId, OPEN_POSITION_AMOUNT, USER_1, payable(address(this)), "", EMPTY_PREVIOUS_DATA
        );
    }

    /**
     * @custom:scenario Validating a close position through the router
     * @custom:given The user has initiated a close position
     * @custom:when The user validates a close position through the router
     * @custom:then The close position is validated successfully
     */
    function test_ForkValidateClosePosition() public {
        _waitDelay(); // to be realistic because not mandatory
        uint256 ts1 = protocol.getUserPendingAction(address(this)).timestamp;
        (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, ts1 + oracleMiddleware.getValidationDelay());

        uint256 ethBalanceBefore = address(this).balance;
        uint256 validationCost = oracleMiddleware.validationCost(data, ProtocolAction.ValidateClosePosition);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.VALIDATE_CLOSE)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, data, EMPTY_PREVIOUS_DATA, validationCost);
        router.execute{ value: validationCost }(commands, inputs);

        assertEq(address(this).balance, ethBalanceBefore + _securityDeposit - validationCost, "ether balance");
        assertApproxEqRel(wstETH.balanceOf(USER_1), OPEN_POSITION_AMOUNT, 1e16, "wstETH balance USER_1 with delta 1%");
    }

    receive() external payable { }
}
