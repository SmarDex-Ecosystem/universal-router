// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import { ISmardexSwapRouter } from "../../interfaces/smardex/ISmardexSwapRouter.sol";
import { ISmardexSwapRouterErrors } from "../../interfaces/smardex/ISmardexSwapRouterErrors.sol";
import { Path } from "../../libraries/Path.sol";
import { SmardexSwapRouterLib } from "../../libraries/SmardexSwapRouterLib.sol";
import { SmardexImmutables } from "./SmardexImmutables.sol";

/// @title Router for Smardex
abstract contract SmardexSwapRouter is ISmardexSwapRouter, SmardexImmutables {
    /// @dev Transient storage variable used for checking slippage
    uint256 private amountInCached = type(uint256).max;
    uint8 private constant ADDR_SIZE = 20;

    /// @inheritdoc ISmardexSwapRouter
    function smardexSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        uint256 amountIn =
            SmardexSwapRouterLib.smardexSwapCallback(SMARDEX_FACTORY, SMARDEX_PERMIT2, amount0Delta, amount1Delta, data);
        if (amountIn > 0) {
            amountInCached = amountIn;
        }
    }

    /**
     * @notice Performs a Smardex exact input swap
     * @dev Use router balance if payer is the router or use permit2 from msg.sender
     * @param recipient The recipient of the output tokens
     * @param amountIn The amount of input tokens for the trade
     * @param amountOutMinimum The minimum desired amount of output tokens
     * @param path The path of the trade as a bytes string
     * @param payer The address that will be paying the input
     */
    function _smardexSwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path,
        address payer
    ) internal {
        SmardexSwapRouterLib.smardexSwapExactInput(SMARDEX_FACTORY, recipient, amountIn, amountOutMinimum, path, payer);
    }

    /**
     * @notice Performs a Smardex exact output swap
     * @dev Use router balance if payer is the router or use permit2 from msg.sender
     * @param recipient The recipient of the output tokens
     * @param recipient The recipient of the output tokens
     * @param amountOut The amount of output tokens to receive for the trade
     * @param amountInMax The maximum desired amount of input tokens
     * @param path The path of the trade as a bytes string
     * @param payer The address that will be paying the input
     */
    function _smardexSwapExactOutput(
        address recipient,
        uint256 amountOut,
        uint256 amountInMax,
        bytes calldata path,
        address payer
    ) internal {
        uint256 amountIn =
            SmardexSwapRouterLib.smardexSwapExactOutput(SMARDEX_FACTORY, recipient, amountOut, path, payer);

        // amountIn is the right one for the first hop, otherwise we need the cached amountIn from callback
        if (path.length > 2 * ADDR_SIZE) {
            amountIn = amountInCached;
        }

        if (amountIn > amountInMax) {
            revert ISmardexSwapRouterErrors.ExcessiveInputAmount();
        }
    }
}
