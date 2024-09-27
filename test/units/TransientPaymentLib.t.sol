// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";

import { IPaymentLibErrors } from "../../src/interfaces/usdn/IPaymentLibErrors.sol";
import { PaymentLib } from "../../src/libraries/usdn/PaymentLib.sol";

/// @custom:feature Test the `PaymentLib`
contract TestTransientPaymentLib is Test {
    /**
     * @custom:scenario Set the transient payment value
     * @custom:when The function is called
     * @custom:then The payment value should be updated
     */
    function test_setPayment() public {
        PaymentLib.setPayment(PaymentLib.PERMIT2_PAYMENT);
        assertEq(PaymentLib.getPayment(), PaymentLib.PERMIT2_PAYMENT, "The payment value should be updated");
    }

    /**
     * @custom:scenario Set the transient payment with an invalid payment
     * @custom:when The function is called
     * @custom:then The call should revert with `InvalidPayment`
     */
    function test_RevertWhen_setPaymentInvalidPayment() public {
        vm.expectRevert(IPaymentLibErrors.InvalidPayment.selector);
        PaymentLib.setPayment(PaymentLib.NO_PAYMENT);

        vm.expectRevert(IPaymentLibErrors.InvalidPayment.selector);
        PaymentLib.setPayment(bytes1(uint8(PaymentLib.PERMIT2_PAYMENT) + 1));
    }

    /**
     * @custom:scenario Delete the transient payment value
     * @custom:given A payment value is set
     * @custom:when The function is called
     * @custom:then The payment value should be equal to `NO_PAYMENT`
     */
    function test_deletePayment() public {
        test_setPayment();
        PaymentLib.deletePayment();
        assertEq(PaymentLib.getPayment(), PaymentLib.NO_PAYMENT, "The payment value should be no payment");
    }
}
