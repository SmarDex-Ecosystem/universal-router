// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

interface IPaymentLibTypes {
    /**
     * @notice Indicates the type of payment in the USDN protocol action callbacks
     * @param None The no payment value
     * @param Transfer The transfer payment value from the contract balance
     * @param TransferFrom The transferFrom payment value to use standard approval or permit
     * @param Permit2 The permit2 payment value to use permit2
     */
    enum PaymentTypes {
        None,
        Transfer,
        TransferFrom,
        Permit2
    }

    /**
     * @notice Indicates the USDN protocol action in the callbacks
     * @param Withdrawal The withdrawal action
     * @param Deposit The deposit action
     * @param Open The open action
     */
    enum PaymentAction {
        Withdrawal,
        Deposit,
        Open
    }
}
