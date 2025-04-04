// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import { IPaymentLibTypes } from "../../interfaces/usdn/IPaymentLibTypes.sol";
import { TransientStorageLib } from "../TransientStorageLib.sol";

library PaymentLib {
    /// @notice The transient payment storage slot
    bytes32 private constant TRANSIENT_PAYMENT_SLOT =
        keccak256(abi.encode(uint256(keccak256("transient.payment")) - 1)) & ~bytes32(uint256(0xff));

    /**
     * @notice Set the payment value
     * @param payment The payment value
     */
    function setPayment(IPaymentLibTypes.PaymentType payment) internal {
        TransientStorageLib.setTransientValue(TRANSIENT_PAYMENT_SLOT, bytes32(uint256(payment)));
    }

    /**
     * @notice Get the payment value
     * @return payment_ The payment value
     */
    function getPayment() internal view returns (IPaymentLibTypes.PaymentType payment_) {
        payment_ = IPaymentLibTypes.PaymentType(uint256(TransientStorageLib.getTransientValue(TRANSIENT_PAYMENT_SLOT)));
    }
}
