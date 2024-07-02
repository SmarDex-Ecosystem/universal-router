// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { ISmardexFactory } from "../interfaces/smardex/ISmardexFactory.sol";
import { ISmardexPair } from "../interfaces/smardex/ISmardexPair.sol";
import { ISmardexSwapRouter } from "../interfaces/smardex/ISmardexSwapRouter.sol";
import { Path } from "../libraries/Path.sol";
import { ISmardexSwapRouterErrors } from "../interfaces/smardex/ISmardexSwapRouterErrors.sol";

/// @title Router library for Smardex
library SmardexSwapRouterLib {
    using Path for bytes;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeERC20 for IERC20;

    /**
     * @notice Used as the placeholder value for maxAmountIn, because the computed amount
     * in for an exact output swap can never actually be this value
     */
    uint256 private constant DEFAULT_MAX_AMOUNT_IN = type(uint256).max;

    /// @notice The address size
    uint8 private constant ADDR_SIZE = 20;

    /**
     * @notice The Smardex callback for Smardex swap
     * @param smardexFactory The Smardex factory contract
     * @param permit2 The permit2 contract
     * @param amountInCached The cached amountIn value
     * @param amount0Delta The amount of token0 for the swap (negative is incoming, positive is required to pay to pair)
     * @param amount1Delta The amount of token1 for the swap (negative is incoming, positive is required to pay to pair)
     * @param data The data path and payer for the swap
     */
    function smardexSwapCallback(
        ISmardexFactory smardexFactory,
        IAllowanceTransfer permit2,
        uint256 amountInCached,
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
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
            _payOrPermit2Transfer(permit2, tokenIn, decodedData.payer, msg.sender, amountToPay);
        } else if (decodedData.path.hasMultiplePools()) {
            decodedData.path = decodedData.path.skipTokenMemory();
            _swapExactOut(smardexFactory, amountToPay, msg.sender, decodedData);
        } else {
            amountInCached = amountToPay;
            // swap in/out because exact output swaps are reversed
            tokenIn = tokenOut;
            _payOrPermit2Transfer(permit2, tokenIn, decodedData.payer, msg.sender, amountToPay);
        }
    }

    /**
     * @notice Performs a Smardex exact input swap
     * @dev Use router balance if the payer is the router or use permit2 from msg.sender
     * @param smardexFactory The Smardex factory contract
     * @param recipient The recipient of the output tokens
     * @param amountIn The amount of input tokens for the trade
     * @param amountOutMinimum The minimum desired amount of output tokens
     * @param path The path of the trade as a bytes string
     * @param payer The address that will be paying the input
     */
    function smardexSwapExactInput(
        ISmardexFactory smardexFactory,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path,
        address payer
    ) external {
        // use amountIn == Constants.CONTRACT_BALANCE as a flag to swap the entire balance of the contract
        if (amountIn == Constants.CONTRACT_BALANCE) {
            address tokenIn = path.decodeFirstToken();
            amountIn = IERC20(tokenIn).balanceOf(address(this));
        }

        uint256 amountOut;
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
                amountOut = amountIn;
                break;
            }
        }

        if (amountOut < amountOutMinimum) {
            revert ISmardexSwapRouterErrors.TooLittleReceived();
        }
    }

    /**
     * @notice Performs a Smardex exact output swap
     * @dev Use router balance if the payer is the router or use permit2 from msg.sender
     * @param smardexFactory The Smardex factory contract
     * @param recipient The recipient of the output tokens
     * @param amountInMaximum The maximum desired amount of input tokens
     * @param path The path of the trade as a bytes string
     * @param payer The address that will be paying the input
     */
    function smardexSwapExactOutput(
        ISmardexFactory smardexFactory,
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        bytes calldata path,
        address payer
    ) external {
        // path needs to be reversed to get the amountIn that we will ask from the next pair hop
        bytes memory reversedPath = path.encodeTightlyPackedReversed();
        uint256 amountIn = _swapExactOut(
            smardexFactory,
            amountOut,
            recipient,
            ISmardexSwapRouter.SwapCallbackData({ path: reversedPath, payer: payer })
        );

        // amountIn is the right one for the first hop, otherwise we need the cached amountIn from callback
        if (path.length > 2 * ADDR_SIZE) {
            amountIn = amountInMaximum;
        }

        if (amountIn > amountInMaximum) {
            revert ISmardexSwapRouterErrors.ExcessiveInputAmount();
        }
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

    /**
     * @notice Either performs a regular payment or transferFrom on Permit2, depending on the payer address
     * @param permit2 The permit2 contract
     * @param token The token to transfer
     * @param payer The address to pay for the transfer
     * @param recipient The recipient of the transfer
     * @param amount The amount to transfer
     */
    function _payOrPermit2Transfer(
        IAllowanceTransfer permit2,
        address token,
        address payer,
        address recipient,
        uint256 amount
    ) private {
        if (payer == address(this)) {
            IERC20(token).safeTransfer(recipient, amount);
        } else {
            permit2.transferFrom(payer, recipient, amount.toUint160(), token);
        }
    }
}
