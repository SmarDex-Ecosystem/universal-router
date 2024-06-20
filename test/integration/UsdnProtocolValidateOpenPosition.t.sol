// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ProtocolAction, Position, PositionId } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { PYTH_ETH_USD, USER_1, USER_2, PKEY_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { SigUtils } from "./utils/SigUtils.sol";

import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Validating an open position through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterValidateOpenPosition is UniversalRouterBaseFixture {
    using SafeCast for uint256;

    uint256 constant OPEN_POSITION_AMOUNT = 2 ether;
    uint256 constant DESIRED_LIQUIDATION = 2500 ether;
    uint256 internal _securityDeposit;
    PositionId internal _posId;
    SigUtils internal _sigUtils;

    function setUp() public {
        _setUp();
        _sigUtils = new SigUtils();
        deal(address(wstETH), address(this), OPEN_POSITION_AMOUNT * 2);
        deal(address(wstETH), vm.addr(PKEY_1), OPEN_POSITION_AMOUNT * 2);
        deal(vm.addr(PKEY_1), 1e6 ether);
        wstETH.approve(address(protocol), type(uint256).max);
        _securityDeposit = protocol.getSecurityDepositValue();
        (, _posId) = protocol.initiateOpenPosition{ value: _securityDeposit }(
            OPEN_POSITION_AMOUNT.toUint128(),
            DESIRED_LIQUIDATION.toUint128(),
            USER_2,
            USER_1,
            NO_PERMIT2,
            "",
            EMPTY_PREVIOUS_DATA
        );
    }

    /**
     * @custom:scenario Validating an open position through the router
     * @custom:given The user has initiated an open position
     * @custom:when The user validates an open position through the router
     * @custom:then The open position is validated successfully
     */
    function test_ForkValidateOpenPosition() public {
        _waitDelay(); // to be realistic because not mandatory
        uint256 ts1 = protocol.getUserPendingAction(USER_1).timestamp;
        (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, ts1 + oracleMiddleware.getValidationDelay());

        uint256 ethBalanceBefore = address(this).balance;
        uint256 ethBalanceBeforeUser = USER_1.balance;
        uint256 validationCost = oracleMiddleware.validationCost(data, ProtocolAction.ValidateOpenPosition);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.VALIDATE_OPEN)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(USER_1, data, EMPTY_PREVIOUS_DATA, validationCost);
        router.execute{ value: validationCost }(commands, inputs);

        assertEq(address(this).balance, ethBalanceBefore - validationCost, "ether balance");
        assertEq(USER_1.balance, ethBalanceBeforeUser + _securityDeposit, "user balance");
        assertEq(wstETH.balanceOf(address(this)), OPEN_POSITION_AMOUNT, "wstETH balance");

        (Position memory pos_,) = protocol.getLongPosition(_posId);
        assertEq(pos_.user, USER_2, "position does not belong to the user");
    }
}
