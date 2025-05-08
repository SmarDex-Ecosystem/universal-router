// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { PaymentsImmutables } from "@uniswap/universal-router/contracts/modules/PaymentsImmutables.sol";

import { ISmardexFactory } from "../../interfaces/smardex/ISmardexFactory.sol";
import { ISmardexRouter } from "../../interfaces/smardex/ISmardexRouter.sol";
import { ISmardexRouterErrors } from "../../interfaces/smardex/ISmardexRouterErrors.sol";
import { Path } from "../../libraries/smardex/Path.sol";
import { SmardexRouterLib } from "../../libraries/smardex/SmardexRouterLib.sol";

/// @title Router for Smardex
abstract contract SmardexRouter is PaymentsImmutables, ISmardexRouter {
    /// @dev Transient storage variable used for checking slippage
    uint256 private amountInCached = type(uint256).max;

    /// @dev The size in bytes of a single address
    uint8 private constant ADDR_SIZE = 20;

    /// @dev The Smardex factory
    ISmardexFactory internal immutable SMARDEX_FACTORY;

    /// @param smardexFactory The Smardex factory
    constructor(ISmardexFactory smardexFactory) {
        SMARDEX_FACTORY = smardexFactory;
    }

    /// @inheritdoc ISmardexRouter
    function smardexSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        uint256 amountIn =
            SmardexRouterLib.smardexSwapCallback(SMARDEX_FACTORY, PERMIT2, amount0Delta, amount1Delta, data);
        if (amountIn > 0) {
            amountInCached = amountIn;
        }
    }

    /// @inheritdoc ISmardexRouter
    function smardexMintCallback(MintCallbackData calldata data) external {
        SmardexRouterLib.smardexMintCallback(SMARDEX_FACTORY, PERMIT2, data);
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
        uint256 amountOut = SmardexRouterLib.smardexSwapExactInput(SMARDEX_FACTORY, recipient, amountIn, path, payer);

        if (amountOut < amountOutMinimum) {
            revert ISmardexRouterErrors.TooLittleReceived();
        }
    }

    /**
     * @notice Performs a Smardex exact output swap
     * @dev Use router balance if payer is the router or use permit2 from msg.sender
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
        uint256 amountIn = SmardexRouterLib.smardexSwapExactOutput(SMARDEX_FACTORY, recipient, amountOut, path, payer);

        // amountIn is the right one for the first hop, otherwise we need the cached amountIn from callback
        if (path.length > 2 * ADDR_SIZE) {
            amountIn = amountInCached;
        }

        if (amountIn > amountInMax) {
            revert ISmardexRouterErrors.ExcessiveInputAmount();
        }

        amountInCached = type(uint256).max;
    }
}
