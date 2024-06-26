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
     * @dev Used as the placeholder value for maxAmountIn, because the computed amount
     * in for an exact output swap can never actually be this value
     */
    uint256 private constant DEFAULT_MAX_AMOUNT_IN = type(uint256).max;

    /// @dev The address size
    uint8 private constant ADDR_SIZE = 20;

    /**
     * @notice Callback function for smardex swap
     * @param amountInCached The amountInCached value
     * @param smardexFactory The Smardex factory contract
     * @param amount0Delta The amount of token0 for the swap (negative is incoming, positive is required to pay to pair)
     * @param amount1Delta The amount of token1 for the swap (negative is incoming, positive is required to pay to pair)
     * @param data The router path and payer for the swap
     */
    function smardexSwapCallback(
        uint256 amountInCached,
        ISmardexFactory smardexFactory,
        IAllowanceTransfer permit2,
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (amount0Delta <= 0 && amount1Delta <= 0) {
            revert ISmardexSwapRouterErrors.CallbackInvalidAmount();
        }

        ISmardexSwapRouter.SwapCallbackData memory decodedData = abi.decode(data, (ISmardexSwapRouter.SwapCallbackData));
        (address tokenIn, address tokenOut) = decodedData.path.decodeFirstPool();

        // ensure that msg.sender is a pair
        if (msg.sender != smardexFactory.getPair(tokenIn, tokenOut)) {
            revert ISmardexSwapRouterErrors.InvalidPair();
        }

        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0 ? (tokenIn < tokenOut, uint256(amount0Delta)) : (tokenOut < tokenIn, uint256(amount1Delta));

        if (isExactInput) {
            _payOrPermit2Transfer(tokenIn, decodedData.payer, msg.sender, amountToPay, permit2);
        } else if (decodedData.path.hasMultiplePools()) {
            decodedData.path = decodedData.path.skipTokenMemory();
            _swapExactOut(amountToPay, msg.sender, decodedData, smardexFactory);
        } else {
            amountInCached = amountToPay;
            tokenIn = tokenOut; // swap in/out because exact output swaps are reversed
            _payOrPermit2Transfer(tokenIn, decodedData.payer, msg.sender, amountToPay, permit2);
        }
    }

    /**
     * @notice Performs a Smardex exact input swap
     * @dev Uses router balance if payer is the router or uses permit2 from msg.sender
     * @param recipient The recipient of the output tokens
     * @param amountIn The amount of input tokens for the trade
     * @param amountOutMinimum The minimum desired amount of output tokens
     * @param path The path of the trade as a bytes string
     * @param payer The address that will be paying the input
     * @param smardexFactory The Smardex factory contract
     */
    function smardexSwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path,
        address payer,
        ISmardexFactory smardexFactory
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
                amountIn,
                // for intermediate swaps, this contract custodies
                hasMultiplePools ? address(this) : recipient,
                // only the first pool in the path is necessary
                ISmardexSwapRouter.SwapCallbackData({ path: path.getFirstPool(), payer: payer }),
                smardexFactory
            );

            // decide whether to continue or terminate
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
     * @dev Use router balance if payer is the router or use permit2 from msg.sender
     * @param recipient The recipient of the output tokens
     * @param amountOut The amount of output tokens to receive for the trade
     * @param amountInMaximum The maximum desired amount of input tokens
     * @param path The path of the trade as a bytes string
     * @param payer The address that will be paying the input
     * @param smardexFactory The Smardex factory contract
     */
    function smardexSwapExactOutput(
        uint256 amountInCached,
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        bytes calldata path,
        address payer,
        ISmardexFactory smardexFactory
    ) external {
        amountInCached = amountInMaximum;

        // Path needs to be reversed to get the amountIn that we will ask from the next pair hop
        bytes memory _reversedPath = path.encodeTightlyPackedReversed();
        uint256 amountIn = _swapExactOut(
            amountOut,
            recipient,
            ISmardexSwapRouter.SwapCallbackData({ path: _reversedPath, payer: payer }),
            smardexFactory
        );

        // amount In is only the right one for one Hop, otherwise we need cached amountIn from callback
        if (path.length > 2 * ADDR_SIZE) {
            amountIn = amountInCached;
        }

        if (amountIn > amountInMaximum) {
            revert ISmardexSwapRouterErrors.ExcessiveInputAmount();
        }
        amountInCached = DEFAULT_MAX_AMOUNT_IN;
    }

    /**
     * @notice Internal function to swap quantity of token to receive a determined quantity
     * @param amountOut The quantity to receive
     * @param to The address that will receive the token
     * @param data The SwapCallbackData data of the swap to transmit
     * @param smardexFactory The Smardex factory contract
     * @return amountIn_ The amount of token to pay
     */
    function _swapExactOut(
        uint256 amountOut,
        address to,
        ISmardexSwapRouter.SwapCallbackData memory data,
        ISmardexFactory smardexFactory
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
     * @param amountIn The quantity to swap
     * @param to The address that will receive the token
     * @param data The SwapCallbackData data of the swap to transmit
     * @param smardexFactory The Smardex factory contract
     * @return amountOut_ The amount of token that to will receive
     */
    function _swapExactIn(
        uint256 amountIn,
        address to,
        ISmardexSwapRouter.SwapCallbackData memory data,
        ISmardexFactory smardexFactory
    ) internal returns (uint256 amountOut_) {
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
     * @param token The token to transfer
     * @param payer The address to pay for the transfer
     * @param recipient The recipient of the transfer
     * @param amount The amount to transfer
     */
    function _payOrPermit2Transfer(
        address token,
        address payer,
        address recipient,
        uint256 amount,
        IAllowanceTransfer permit2
    ) internal {
        if (payer == address(this)) {
            IERC20(token).safeTransfer(recipient, amount);
        } else {
            permit2.transferFrom(payer, recipient, amount.toUint160(), token);
        }
    }
}
