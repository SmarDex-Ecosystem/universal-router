// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { PYTH_ETH_USD, USER_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Validating a close position through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterValidateClosePosition is UniversalRouterBaseFixture {
    uint128 constant OPEN_POSITION_AMOUNT = 2 ether;
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp(DEFAULT_PARAMS);
        deal(address(wstETH), address(this), OPEN_POSITION_AMOUNT * 2);
        wstETH.approve(address(protocol), type(uint256).max);
        _securityDeposit = protocol.getSecurityDepositValue();
        (, IUsdnProtocolTypes.PositionId memory posId) = protocol.initiateOpenPosition{ value: _securityDeposit }(
            OPEN_POSITION_AMOUNT,
            DEFAULT_PARAMS.initialLiqPrice,
            type(uint128).max,
            maxLeverage,
            address(this),
            payable(address(this)),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA
        );
        _waitDelay(); // to be realistic because not mandatory
        uint256 ts1 = protocol.getUserPendingAction(address(this)).timestamp;
        (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, ts1 + oracleMiddleware.getValidationDelay());
        protocol.validateOpenPosition{
            value: oracleMiddleware.validationCost(data, IUsdnProtocolTypes.ProtocolAction.ValidateOpenPosition)
        }(payable(address(this)), data, EMPTY_PREVIOUS_DATA);
        protocol.initiateClosePosition{ value: _securityDeposit }(
            posId,
            OPEN_POSITION_AMOUNT,
            0,
            USER_1,
            payable(address(this)),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA,
            ""
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
        uint256 validationCost =
            oracleMiddleware.validationCost(data, IUsdnProtocolTypes.ProtocolAction.ValidateClosePosition);

        bytes memory commands = abi.encodePacked(uint8(Commands.VALIDATE_CLOSE));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, data, EMPTY_PREVIOUS_DATA, validationCost);
        router.execute{ value: validationCost }(commands, inputs);

        assertEq(address(this).balance, ethBalanceBefore + _securityDeposit - validationCost, "ether balance");
        assertApproxEqRel(
            wstETH.balanceOf(USER_1),
            OPEN_POSITION_AMOUNT,
            OPEN_POSITION_AMOUNT / 10,
            "wstETH balance USER_1 with delta 1%"
        );
    }

    receive() external payable { }
}
