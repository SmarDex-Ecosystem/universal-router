// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";

import { ISmardexFactory } from "../../interfaces/smardex/ISmardexFactory.sol";
import { ISmardexPair } from "../../interfaces/smardex/ISmardexPair.sol";
import { ISmardexRouter } from "../../interfaces/smardex/ISmardexRouter.sol";
import { ISmardexRouterErrors } from "../../interfaces/smardex/ISmardexRouterErrors.sol";
import { Payment } from "../../utils/Payment.sol";
import { Path } from "./Path.sol";
import { PoolHelpers } from "./PoolHelpers.sol";

/// @title Router library for Smardex
library SmardexRouterLib {
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
            revert ISmardexRouterErrors.CallbackInvalidAmount();
        }

        ISmardexRouter.SwapCallbackData memory decodedData = abi.decode(data, (ISmardexRouter.SwapCallbackData));
        (address tokenIn, address tokenOut) = decodedData.path.decodeFirstPool();

        if (msg.sender != smardexFactory.getPair(tokenIn, tokenOut)) {
            revert ISmardexRouterErrors.InvalidPair();
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
     * @notice The callback called during a mint of LP token on Smardex.
     * @param smardexFactory The Smardex factory contract.
     * @param permit2 The permit2 contract.
     * @param data The data required to execute the callback.
     */
    function smardexMintCallback(
        ISmardexFactory smardexFactory,
        IAllowanceTransfer permit2,
        ISmardexRouter.MintCallbackData calldata data
    ) external {
        if (data.amount0 == 0 && data.amount1 == 0) {
            revert ISmardexRouterErrors.CallbackInvalidAmount();
        }

        if (msg.sender != smardexFactory.getPair(data.token0, data.token1)) {
            revert ISmardexRouterErrors.InvalidPair();
        }

        Payment.pay(permit2, data.token0, data.payer, msg.sender, data.amount0);
        Payment.pay(permit2, data.token1, data.payer, msg.sender, data.amount1);
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
                ISmardexRouter.SwapCallbackData({ path: path.getFirstPool(), payer: payer })
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
            smardexFactory, amountOut, recipient, ISmardexRouter.SwapCallbackData({ path: reversedPath, payer: payer })
        );
    }

    /**
     * @notice Adds liquidity in a Smardex pool.
     * @dev During the mint of the liquidity tokens, {smardexSwapCallback} will be called which will call for a transfer
     * of the tokens to the pair. Use the router's balance if the payer is the router or use permit2 if it's msg.sender.
     * @param smardexFactory The Smardex factory contract.
     * @param params The smardex add liquidity params.
     * @param receiver The liquidity receiver address.
     * @param payer The payer address.
     * @param deadline The deadline before which the liquidity must be added.
     * @return success_ Whether the liquidity was successfully added.
     * @return output_ The output which contains amountA, amountB and the amount of liquidity tokens minted.
     */
    function addLiquidity(
        ISmardexFactory smardexFactory,
        ISmardexRouter.AddLiquidityParams calldata params,
        address receiver,
        address payer,
        uint256 deadline
    ) external returns (bool success_, bytes memory output_) {
        if (block.timestamp > deadline) {
            revert ISmardexRouterErrors.DeadlineExceeded();
        }

        address pair = _getTokenPair(smardexFactory, params.tokenA, params.tokenB, receiver);
        (uint256 amountA, uint256 amountB) = _computesLiquidityToAdd(params, pair);
        (uint256 amount0, uint256 amount1) = PoolHelpers.sortAmounts(params.tokenA, params.tokenB, amountA, amountB);
        uint256 liquidity = ISmardexPair(pair).mint(receiver, amount0, amount1, payer);
        return (true, abi.encode(amountA, amountB, liquidity));
    }

    /**
     * @notice Removes liquidity from a Smardex pool.
     * @param smardexFactory The Smardex factory contract.
     * @param permit2 The permit2 contract.
     * @param params The parameters for removing liquidity.
     * @param payer The payer address.
     * @param receiver The recipient of the tokens.
     * @param deadline The deadline before which the liquidity must be removed.
     * @return success_ Whether the liquidity was successfully removed.
     * @return output_ The output which contains the amount of tokenA and tokenB received.
     */
    function removeLiquidity(
        ISmardexFactory smardexFactory,
        IAllowanceTransfer permit2,
        ISmardexRouter.RemoveLiquidityParams calldata params,
        address receiver,
        address payer,
        uint256 deadline
    ) external returns (bool success_, bytes memory output_) {
        if (block.timestamp > deadline) {
            revert ISmardexRouterErrors.DeadlineExceeded();
        }
        if (params.tokenA == params.tokenB) {
            revert ISmardexRouterErrors.InvalidTokenAddress();
        }
        if (params.tokenA == address(0) || params.tokenB == address(0)) {
            revert ISmardexRouterErrors.InvalidTokenAddress();
        }

        ISmardexPair pair = ISmardexPair(smardexFactory.getPair(params.tokenA, params.tokenB));

        if (address(pair) == address(0)) {
            revert ISmardexRouterErrors.InvalidPair();
        }

        Payment.pay(permit2, address(pair), payer, address(pair), params.liquidity);

        (uint256 amount0, uint256 amount1) = pair.burn(receiver);
        (uint256 amountA, uint256 amountB) = params.tokenA < params.tokenB ? (amount0, amount1) : (amount1, amount0);

        if (amountA < params.amountAMin) {
            revert ISmardexRouterErrors.InsufficientAmountA();
        }
        if (amountB < params.amountBMin) {
            revert ISmardexRouterErrors.InsufficientAmountB();
        }

        return (true, abi.encode(amountA, amountB));
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
        ISmardexRouter.SwapCallbackData memory data
    ) private returns (uint256 amountIn_) {
        if (to == address(0)) {
            revert ISmardexRouterErrors.InvalidRecipient();
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
        ISmardexRouter.SwapCallbackData memory data
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
     * @notice Gets the pair depending on the pair.
     * @dev Creates the pair if it doesn't exists.
     * @param smardexFactory The smardex factory.
     * @param tokenA The address of the first token of the pair.
     * @param tokenB The address of the second token of the pair.
     * @param skimReceiver The recipient of the possibly skimmed tokens.
     * @return pair_ The address of the pool where the liquidity was added.
     */
    function _getTokenPair(ISmardexFactory smardexFactory, address tokenA, address tokenB, address skimReceiver)
        private
        returns (address pair_)
    {
        pair_ = smardexFactory.getPair(tokenA, tokenB);
        // If the pair does not exist, create it
        if (pair_ == address(0)) {
            pair_ = smardexFactory.createPair(tokenA, tokenB);
        }

        if (ISmardexPair(pair_).totalSupply() == 0) {
            ISmardexPair(pair_).skim(skimReceiver); // in case some tokens are already on the pair
        }
    }

    /**
     * @notice Computes the amount of tokens to add as liquidity based on the given parameters.
     * @param params Parameters of the liquidity to add.
     * @param pair The token pair to add liquidity to.
     * @return amountA_ The amount of tokenA to send to the pool.
     * @return amountB_ The amount of tokenB to send to the pool.
     */
    function _computesLiquidityToAdd(ISmardexRouter.AddLiquidityParams calldata params, address pair)
        internal
        view
        returns (uint256 amountA_, uint256 amountB_)
    {
        (uint256 reserveA, uint256 reserveB, uint256 reserveAFic, uint256 reserveBFic) =
            PoolHelpers.getAllReserves(ISmardexPair(pair), params.tokenA);

        if (reserveA == 0 && reserveB == 0) {
            (amountA_, amountB_) = (params.amountADesired, params.amountBDesired);
        } else {
            uint256 product = reserveAFic * params.fictiveReserveB;

            if (product > params.fictiveReserveAMax * reserveBFic) {
                revert ISmardexRouterErrors.PriceTooHigh();
            }
            if (product < params.fictiveReserveAMin * reserveBFic) {
                revert ISmardexRouterErrors.PriceTooLow();
            }

            uint256 amountBOptimal = PoolHelpers.quote(params.amountADesired, reserveA, reserveB);

            if (amountBOptimal <= params.amountBDesired) {
                if (amountBOptimal < params.amountBMin) {
                    revert ISmardexRouterErrors.InsufficientAmountB();
                }

                (amountA_, amountB_) = (params.amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = PoolHelpers.quote(params.amountBDesired, reserveB, reserveA);

                // sanity check
                if (amountAOptimal > params.amountADesired) {
                    revert ISmardexRouterErrors.InsufficientAmountADesired();
                }
                if (amountAOptimal < params.amountAMin) {
                    revert ISmardexRouterErrors.InsufficientAmountA();
                }

                (amountA_, amountB_) = (amountAOptimal, params.amountBDesired);
            }
        }
    }
}
