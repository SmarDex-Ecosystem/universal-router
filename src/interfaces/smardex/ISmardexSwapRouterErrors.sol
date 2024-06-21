// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

interface ISmardexSwapRouterErrors {
    /// @notice Indicates that the amountOut is lower than the minAmountOut
    error TooLittleReceived();

    /// @notice Indicates that the amountIn is higher than the maxAmountIn
    error ExcessiveInputAmount();

    /// @notice Indicates that the recipient is invalid
    error InvalidRecipient();

    /// @notice Indicates that msg.sender is not the pair
    error InvalidPair();

    /// @notice Indicates that the callback amount is invalid
    error CallbackInvalidAmount();
}
