// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import { IPaymentLibTypes } from "../../interfaces/usdn/IPaymentLibTypes.sol";
import { TransientStorageLib } from "../TransientStorageLib.sol";

library PaymentLib {
    /// @notice The transient payment storage slot
    bytes32 private constant TRANSIENT_PAYMENT_SLOT = bytes32(uint256(keccak256("transient.payment")) - 1);

    /**
     * @notice Set the payment value
     * @param payment The payment value
     */
    function setPayment(IPaymentLibTypes.PaymentTypes payment) external {
        TransientStorageLib.setTransientValue(TRANSIENT_PAYMENT_SLOT, bytes32(uint256(payment)));
    }

    /**
     * @notice Get the payment value
     * @return payment_ The payment value
     */
    function getPayment() external view returns (IPaymentLibTypes.PaymentTypes payment_) {
        payment_ = IPaymentLibTypes.PaymentTypes(uint256(TransientStorageLib.getTransientValue(TRANSIENT_PAYMENT_SLOT)));
    }
}
