// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import { ISmardexSwapRouterErrors } from "./ISmardexSwapRouterErrors.sol";

interface ISmardexSwapRouter is ISmardexSwapRouterErrors {
    /**
     * @notice Callback data for swap in SmardexRouter
     * @param path The path of the swap, array of token addresses tightly packed
     * @param payer The address of the payer for the swap
     */
    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    /**
     * @notice Callback of the Smardex swap
     * @param amount0Delta The amount of token0 for the swap (negative is incoming, positive is required to pay to pair)
     * @param amount1Delta The amount of token1 for the swap (negative is incoming, positive is required to pay to pair)
     * @param data The data for path and payer for the swap
     */
    function smardexSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}
