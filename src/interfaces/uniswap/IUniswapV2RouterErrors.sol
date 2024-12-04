// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

interface IUniswapV2RouterErrors {
    /// @notice Error emitted when the amount received is too low
    error V2TooLittleReceived();
    /// @notice Error emitted when the amount requested is too high
    error V2TooMuchRequested();
    /// @notice Error emitted when the path is invalid
    error V2InvalidPath();
}
