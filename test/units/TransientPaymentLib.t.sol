// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";

import { IPaymentLibTypes } from "../../src/interfaces/usdn/IPaymentLibTypes.sol";
import { PaymentLib } from "../../src/libraries/usdn/PaymentLib.sol";

/// @custom:feature Test the `PaymentLib`
contract TestPaymentLib is Test {
    /**
     * @custom:scenario Set the transient payment value
     * @custom:when The function is called
     * @custom:then The payment value should be updated
     */
    function test_setPayment() public {
        PaymentLib.setPayment(type(IPaymentLibTypes.PaymentType).max);
        assertTrue(
            PaymentLib.getPayment() == type(IPaymentLibTypes.PaymentType).max, "The payment value should be updated"
        );
    }
}
