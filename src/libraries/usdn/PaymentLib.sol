// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import { IPaymentLibErrors } from "../../interfaces/usdn/IPaymentLibErrors.sol";
import { TransientStorageLib } from "../TransientStorageLib.sol";

library PaymentLib {
    /// @notice The no payment value
    bytes1 public constant NO_PAYMENT = 0x00;
    /// @notice The transfer payment value
    bytes1 public constant TRANSFER_PAYMENT = 0x01;
    /// @notice The transferFrom payment value
    bytes1 public constant TRANSFER_FROM_PAYMENT = 0x02;
    /// @notice The permit2 payment value
    bytes1 public constant PERMIT2_PAYMENT = 0x03;

    /**
     * @notice The transient payment storage slot
     * @dev This is equal to bytes32(uint256(keccak256("transient.payment")) - 1)
     */
    bytes32 private constant TRANSIENT_PAYMENT_SLOT = 0xed481feabce399bdb83741349758428352670f34b088aede021db151e359cc77;

    /**
     * @notice Set the payment value
     * @dev Uses the transient storage
     * @param payment The payment value
     */
    function setPayment(bytes1 payment) external {
        if (payment == NO_PAYMENT || payment > PERMIT2_PAYMENT) {
            revert IPaymentLibErrors.InvalidPayment();
        }

        TransientStorageLib.setTransientValue(TRANSIENT_PAYMENT_SLOT, payment);
    }

    /**
     * @notice Delete the payment value
     * @dev Uses the transient storage
     */
    function deletePayment() external {
        bytes1 payment = bytes1(TransientStorageLib.getTransientValue(TRANSIENT_PAYMENT_SLOT));
        if (payment > NO_PAYMENT && payment <= PERMIT2_PAYMENT) {
            TransientStorageLib.setTransientValue(TRANSIENT_PAYMENT_SLOT, NO_PAYMENT);
        }
    }

    /**
     * @notice Get the payment value
     * @dev Uses the transient storage
     * @return payment_ The payment value
     */
    function getPayment() external view returns (bytes1 payment_) {
        payment_ = bytes1(TransientStorageLib.getTransientValue(TRANSIENT_PAYMENT_SLOT));
    }
}
