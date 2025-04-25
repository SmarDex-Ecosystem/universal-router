// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { UsdnProtocolUtilsLibrary as Utils } from
    "@smardex-usdn-contracts-1/src/UsdnProtocol/libraries/UsdnProtocolUtilsLibrary.sol";

import { Commands } from "../../../src/libraries/Commands.sol";
import { IUsdnProtocolRouterTypes } from "../../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { IPaymentLibTypes } from "../../../src/interfaces/usdn/IPaymentLibTypes.sol";
import { UniversalRouterUsdnShortProtocolBaseFixture } from "./utils/Fixtures.sol";
import { USER_1 } from "../utils/Constants.sol";

/**
 * @custom:feature Test the usdn initiate actions through the router using permit2
 * @custom:background A deployed router
 */
contract TestForkUniversalRouterUsdnShortInitiateActionsPermit2 is UniversalRouterUsdnShortProtocolBaseFixture {
    uint256 internal _securityDeposit;
    uint256 internal _baseDeposit;

    function setUp() public {
        _setUp();
        _baseDeposit = minLongPosition;

        vm.startPrank(sigUser1);
        asset.approve(address(permit2), type(uint256).max);
        sdex.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        _securityDeposit = protocol.getSecurityDepositValue();
    }

    /**
     * @custom:scenario Initiating a deposit command from the user balance by calling permit2
     * @custom:when The user calls the permit2 command
     * @custom:and The user calls a deposit through the router from the user balance
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkUsdnShortInitiateDepositPermit2BatchToUsdnProtocol() public {
        uint256 sdexAmount = Utils._calcSdexToBurn(_baseDeposit, protocol.getSdexBurnOnDepositRatio());

        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](2);
        details[0] = IAllowanceTransfer.PermitDetails(address(asset), uint160(_baseDeposit), type(uint48).max, 0);
        details[1] = IAllowanceTransfer.PermitDetails(address(sdex), uint160(sdexAmount), type(uint48).max, 0);
        IAllowanceTransfer.PermitBatch memory permitBatch =
            IAllowanceTransfer.PermitBatch(details, address(router), type(uint256).max);
        bytes memory signature = getPermitBatchSignature(permitBatch, SIG_USER1_PK, permit2.DOMAIN_SEPARATOR());

        bytes memory commands = abi.encodePacked(uint8(Commands.PERMIT2_PERMIT_BATCH), uint8(Commands.INITIATE_DEPOSIT));

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitBatch, signature);
        inputs[1] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                IPaymentLibTypes.PaymentType.Permit2,
                _baseDeposit,
                0,
                USER_1,
                address(this),
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                _securityDeposit
            )
        );

        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        DepositPendingAction memory action = toDepositPendingAction(protocol.getUserPendingAction(address(this)));
        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertEq(action.amount, _baseDeposit, "pending action amount");
    }

    /**
     * @custom:scenario Initiating an open position command from the user balance by calling permit2
     * @custom:when The user calls the permit2 command
     * @custom:and The user calls a deposit through the router from the user balance
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkUsdnShortInitiateOpenPositionPermit2BatchToUsdnProtocol() public {
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](1);
        details[0] = IAllowanceTransfer.PermitDetails(address(asset), uint160(minLongPosition), type(uint48).max, 0);
        IAllowanceTransfer.PermitBatch memory permitBatch =
            IAllowanceTransfer.PermitBatch(details, address(router), type(uint256).max);
        bytes memory signature = getPermitBatchSignature(permitBatch, SIG_USER1_PK, permit2.DOMAIN_SEPARATOR());

        bytes memory commands = abi.encodePacked(uint8(Commands.PERMIT2_PERMIT_BATCH), uint8(Commands.INITIATE_OPEN));

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitBatch, signature);
        inputs[1] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                IPaymentLibTypes.PaymentType.Permit2,
                minLongPosition,
                initialPrice / 2,
                type(uint128).max,
                maxLeverage,
                USER_1,
                address(this),
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                _securityDeposit
            )
        );

        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        IUsdnProtocolTypes.LongPendingAction memory action =
            toLongPendingAction(protocol.getUserPendingAction(address(this)));
        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertTrue(
            action.action == IUsdnProtocolTypes.ProtocolAction.ValidateOpenPosition,
            "pending action should be a validate open position"
        );
    }
}
