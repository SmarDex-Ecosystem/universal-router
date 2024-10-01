// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { IUsdnProtocolTypes } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { IUsdnProtocolRouterTypes } from "../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { IPaymentLibTypes } from "../../src/interfaces/usdn/IPaymentLibTypes.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { USER_1 } from "./utils/Constants.sol";

/**
 * @custom:feature Test the USDN initiate actions through the router using permit2
 * @custom:background A deployed router
 */
contract TestForkUniversalRouterUsdnInitiateActionsPermit2 is UniversalRouterBaseFixture {
    uint256 internal constant BASE_AMOUNT = 5 ether;
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp(DEFAULT_PARAMS);

        deal(address(wstETH), sigUser1, BASE_AMOUNT * 10);
        deal(address(sdex), sigUser1, BASE_AMOUNT * 10);
        deal(sigUser1, 1e6 ether);

        vm.startPrank(sigUser1);
        wstETH.approve(address(permit2), type(uint256).max);
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
    function test_ForkInitiateDepositPermit2BatchToUsdnProtocol() public prankUser(sigUser1) {
        uint256 sdexAmount = _calcSdexToBurn(BASE_AMOUNT / 10);

        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](2);
        details[0] = IAllowanceTransfer.PermitDetails(address(wstETH), uint160(BASE_AMOUNT / 10), type(uint48).max, 0);
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
                BASE_AMOUNT / 10,
                0,
                USER_1,
                address(this),
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                _securityDeposit
            )
        );

        router.execute{ value: _securityDeposit }(commands, inputs);

        DepositPendingAction memory action =
            protocol.i_toDepositPendingAction(protocol.getUserPendingAction(address(this)));
        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertEq(action.amount, BASE_AMOUNT / 10, "pending action amount");
    }

    /**
     * @custom:scenario Initiating an open position command from the user balance by calling permit2
     * @custom:when The user calls the permit2 command
     * @custom:and The user calls a deposit through the router from the user balance
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkInitiateOpenPositionPermit2BatchToUsdnProtocol() public prankUser(sigUser1) {
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](1);
        details[0] = IAllowanceTransfer.PermitDetails(address(wstETH), uint160(BASE_AMOUNT), type(uint48).max, 0);
        IAllowanceTransfer.PermitBatch memory permitBatch =
            IAllowanceTransfer.PermitBatch(details, address(router), type(uint256).max);
        bytes memory signature = getPermitBatchSignature(permitBatch, SIG_USER1_PK, permit2.DOMAIN_SEPARATOR());

        bytes memory commands = abi.encodePacked(uint8(Commands.PERMIT2_PERMIT_BATCH), uint8(Commands.INITIATE_OPEN));

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitBatch, signature);
        inputs[1] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                IPaymentLibTypes.PaymentType.Permit2,
                BASE_AMOUNT,
                params.initialPrice / 2,
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

        router.execute{ value: _securityDeposit }(commands, inputs);

        IUsdnProtocolTypes.PendingAction memory action = protocol.getUserPendingAction(address(this));
        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertTrue(
            action.action == IUsdnProtocolTypes.ProtocolAction.ValidateOpenPosition,
            "pending action should be a validate open position"
        );
    }
}
