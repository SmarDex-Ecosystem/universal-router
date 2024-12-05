// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

interface ISmardexRouterErrors {
    /// @notice Indicates that the amountOut is lower than the minAmountOut
    error TooLittleReceived();

    /// @notice Indicates that the amountIn is higher than the maxAmountIn
    error ExcessiveInputAmount();

    /// @notice Indicates that the recipient is invalid
    error InvalidRecipient();

    /// @notice Indicates that the pair address is invalid
    error InvalidPair();

    /// @notice Indicates that the callback amount is invalid
    error CallbackInvalidAmount();

    /// @notice Indicates that the price is too high
    error PriceTooHigh();

    /// @notice Indicates that the price is too low
    error PriceTooLow();

    /// @notice Indicates that the amount of asset B is insufficient
    error InsufficientAmountB();

    /// @notice Indicates that the amount of asset A desired is insufficient
    error InsufficientAmountADesired();

    /// @notice Indicates that the amount of asset A is insufficient
    error InsufficientAmountA();

    /// @notice Indicates that the deadline was exceeded
    error DeadlineExceeded();

    /// @notice Indicates that the address is invalid
    error InvalidAddress();
}
