// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ISmardexRouterErrors {
    /// @notice The amount of token received is lower than the limit.
    error TooLittleReceived();

    /// @notice The amount of tokens to pay is higher than the limit.
    error ExcessiveInputAmount();

    /// @notice The recipient is invalid.
    error InvalidRecipient();

    /// @notice `msg.sender` is not the expected token pair.
    error InvalidPair();

    /// @notice Token amounts given to the callback are invalid.
    error CallbackInvalidAmount();

    /// @notice The price is too high for the swap.
    error PriceTooHigh();

    /// @notice The price is too low for the swap.
    error PriceTooLow();

    /// @notice The amount of asset B is below the minimum.
    error InsufficientAmountB();

    /// @notice The amount of asset A to pay is above the desired amount.
    error InsufficientAmountADesired();

    /// @notice The amount of asset A is below the minimum.
    error InsufficientAmountA();

    /// @notice The deadline for the action was exceeded.
    error DeadlineExceeded();
}
