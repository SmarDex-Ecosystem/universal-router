// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

interface IUniswapV2RouterErrors {
    /// @notice The amount received is too low.
    error UniswapV2TooLittleReceived();
    /// @notice The amount requested is too high.
    error UniswapV2TooMuchRequested();
    /// @notice The path is invalid.
    error UniswapV2InvalidPath();
}
