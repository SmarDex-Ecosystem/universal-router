// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

interface IUsdnProtocolRouterErrors {
    /// @notice Reverts when the sender is invalid.
    error UsdnProtocolRouterInvalidSender();

    /// @notice Reverts when the payment is invalid.
    error UsdnProtocolRouterInvalidPayment();
}
