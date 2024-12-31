// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { ISmardexFactory } from "../../interfaces/smardex/ISmardexFactory.sol";
import { ISmardexPair } from "../../interfaces/smardex/ISmardexPair.sol";
import { ISmardexSwapRouter } from "../../interfaces/smardex/ISmardexSwapRouter.sol";
import { ISmardexSwapRouterErrors } from "../../interfaces/smardex/ISmardexSwapRouterErrors.sol";
import { Path } from "./Path.sol";
import { Payment } from "../../utils/Payment.sol";

/// @title Router library for Smardex
library SmardexSwapRouterLib {
    using Path for bytes;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeERC20 for IERC20;

    /// @notice The address size
    uint8 private constant ADDR_SIZE = 20;

    /**
     * @notice The Smardex callback for Smardex swap
     * @param smardexFactory The Smardex factory contract
     * @param permit2 The permit2 contract
     * @param amount0Delta The amount of token0 for the swap (negative is incoming, positive is required to pay to pair)
     * @param amount1Delta The amount of token1 for the swap (negative is incoming, positive is required to pay to pair)
     * @param data The data path and payer for the swap
     * @return amountInCached_ Cached input amount, used to check slippage
     */
    function smardexSwapCallback(
        ISmardexFactory smardexFactory,
        IAllowanceTransfer permit2,
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external returns (uint256 amountInCached_) {
        if (amount0Delta <= 0 && amount1Delta <= 0) {
            revert ISmardexSwapRouterErrors.CallbackInvalidAmount();
        }

        ISmardexSwapRouter.SwapCallbackData memory decodedData = abi.decode(data, (ISmardexSwapRouter.SwapCallbackData));
        (address tokenIn, address tokenOut) = decodedData.path.decodeFirstPool();

        if (msg.sender != smardexFactory.getPair(tokenIn, tokenOut)) {
            revert ISmardexSwapRouterErrors.InvalidPair();
        }

        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0 ? (tokenIn < tokenOut, uint256(amount0Delta)) : (tokenOut < tokenIn, uint256(amount1Delta));

        if (isExactInput) {
            Payment.pay(permit2, tokenIn, decodedData.payer, msg.sender, amountToPay);
        } else if (decodedData.path.hasMultiplePools()) {
            decodedData.path = decodedData.path.skipToken();
            _swapExactOut(smardexFactory, amountToPay, msg.sender, decodedData);
        } else {
            amountInCached_ = amountToPay;
            // swap in/out because exact output swaps are reversed
            tokenIn = tokenOut;
            Payment.pay(permit2, tokenIn, decodedData.payer, msg.sender, amountToPay);
        }
    }

    /**
     * @notice Performs a Smardex exact input swap
     * @dev Use router balance if the payer is the router or use permit2 from msg.sender
     * @param smardexFactory The Smardex factory contract
     * @param recipient The recipient of the output tokens
     * @param amountIn The amount of input tokens for the trade
     * @param path The path of the trade as a bytes string
     * @param payer The address that will be paying the input
     * @return amountOut_ The amount out
     */
    function smardexSwapExactInput(
        ISmardexFactory smardexFactory,
        address recipient,
        uint256 amountIn,
        bytes memory path,
        address payer
    ) external returns (uint256 amountOut_) {
        // use amountIn == Constants.CONTRACT_BALANCE as a flag to swap the entire balance of the contract
        if (amountIn == Constants.CONTRACT_BALANCE && payer == address(this)) {
            address tokenIn = path.decodeFirstToken();
            amountIn = IERC20(tokenIn).balanceOf(address(this));
        }

        while (true) {
            bool hasMultiplePools = path.hasMultiplePools();
            amountIn = _swapExactIn(
                smardexFactory,
                amountIn,
                hasMultiplePools ? address(this) : recipient,
                // only the first pool in the path is necessary
                ISmardexSwapRouter.SwapCallbackData({ path: path.getFirstPool(), payer: payer })
            );

            if (hasMultiplePools) {
                payer = address(this);
                path = path.skipToken();
            } else {
                amountOut_ = amountIn;
                break;
            }
        }
    }

    /**
     * @notice Performs a Smardex exact output swap
     * @dev Use router balance if the payer is the router or use permit2 from msg.sender
     * @param smardexFactory The Smardex factory contract
     * @param recipient The recipient of the output tokens
     * @param amountOut The amount of output tokens to receive for the swap
     * @param path The path of the trade as a bytes string
     * @param payer The address that will be paying the input
     * @return amountIn_ The amount of input tokens to pay
     */
    function smardexSwapExactOutput(
        ISmardexFactory smardexFactory,
        address recipient,
        uint256 amountOut,
        bytes memory path,
        address payer
    ) external returns (uint256 amountIn_) {
        // path needs to be reversed to get the amountIn that we will ask from the next pair hop
        bytes memory reversedPath = path.encodeTightlyPackedReversed();

        amountIn_ = _swapExactOut(
            smardexFactory,
            amountOut,
            recipient,
            ISmardexSwapRouter.SwapCallbackData({ path: reversedPath, payer: payer })
        );
    }

    /**
     * @notice Internal function to swap quantity of token to receive a determined quantity
     * @param smardexFactory The Smardex factory contract
     * @param amountOut The quantity to receive
     * @param to The address that will receive the token
     * @param data The SwapCallbackData data of the swap to transmit
     * @return amountIn_ The amount of token to pay
     */
    function _swapExactOut(
        ISmardexFactory smardexFactory,
        uint256 amountOut,
        address to,
        ISmardexSwapRouter.SwapCallbackData memory data
    ) private returns (uint256 amountIn_) {
        if (to == address(0)) {
            revert ISmardexSwapRouterErrors.InvalidRecipient();
        }

        (address tokenOut, address tokenIn) = data.path.decodeFirstPool();
        bool zeroForOne = tokenIn < tokenOut;

        (int256 amount0, int256 amount1) = ISmardexPair(smardexFactory.getPair(tokenIn, tokenOut)).swap(
            to, zeroForOne, -amountOut.toInt256(), abi.encode(data)
        );

        if (zeroForOne) {
            amountIn_ = uint256(amount0);
        } else {
            amountIn_ = uint256(amount1);
        }
    }

    /**
     * @notice Internal function to swap a determined quantity of token
     * @param smardexFactory The Smardex factory contract
     * @param amountIn The quantity to swap
     * @param to The address that will receive the token
     * @param data The SwapCallbackData data of the swap to transmit
     * @return amountOut_ The amount of token that _to will receive
     */
    function _swapExactIn(
        ISmardexFactory smardexFactory,
        uint256 amountIn,
        address to,
        ISmardexSwapRouter.SwapCallbackData memory data
    ) private returns (uint256 amountOut_) {
        // allow swapping to the router address with address 0
        if (to == address(0)) {
            to = address(this);
        }

        (address tokenIn, address tokenOut) = data.path.decodeFirstPool();
        bool _zeroForOne = tokenIn < tokenOut;
        (int256 amount0, int256 amount1) = ISmardexPair(smardexFactory.getPair(tokenIn, tokenOut)).swap(
            to, _zeroForOne, amountIn.toInt256(), abi.encode(data)
        );
        amountOut_ = (_zeroForOne ? -amount1 : -amount0).toUint256();
    }
}
