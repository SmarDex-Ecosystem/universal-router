// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";

import { ISmardexFactory } from "../../interfaces/smardex/ISmardexFactory.sol";
import { ISmardexPair } from "../../interfaces/smardex/ISmardexPair.sol";
import { ISmardexRouter } from "../../interfaces/smardex/ISmardexRouter.sol";
import { ISmardexRouterErrors } from "../../interfaces/smardex/ISmardexRouterErrors.sol";
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
            _payOrPermit2Transfer(permit2, tokenIn, decodedData.payer, msg.sender, amountToPay);
        } else if (decodedData.path.hasMultiplePools()) {
            decodedData.path = decodedData.path.skipToken();
            _swapExactOut(smardexFactory, amountToPay, msg.sender, decodedData);
        } else {
            amountInCached_ = amountToPay;
            // swap in/out because exact output swaps are reversed
            tokenIn = tokenOut;
            _payOrPermit2Transfer(permit2, tokenIn, decodedData.payer, msg.sender, amountToPay);
        }
    }

    /**
     * @notice The Smardex callback for Smardex mint
     * @param smardexFactory The Smardex factory contract
     * @param permit2 The permit2 contract
     * @param data The mint callback data
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

        _payOrPermit2Transfer(permit2, data.token0, data.payer, msg.sender, data.amount0);
        _payOrPermit2Transfer(permit2, data.token1, data.payer, msg.sender, data.amount1);
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
     * @notice Performs the Smardex add liquidity
     * @dev Use router balance if the payer is the router or use permit2 from msg.sender
     * @param smardexFactory The Smardex factory contract
     * @param params The smardex add liquidity params
     * @param receiver The liquidity receiver address
     * @param payer The payer address
     * @return success_ Whether the add liquidity is successful
     * @return output_ The output which contains amountA, amountB and liquidity values
     */
    function addLiquidity(
        ISmardexFactory smardexFactory,
        ISmardexRouter.AddLiquidityParams calldata params,
        address receiver,
        address payer
    ) external returns (bool success_, bytes memory output_) {
        (uint256 amountA, uint256 amountB, address pair) = _addLiquidity(smardexFactory, params, receiver);
        (uint256 amount0, uint256 amount1) = PoolHelpers.sortAmounts(params.tokenA, params.tokenB, amountA, amountB);
        uint256 liquidity = ISmardexPair(pair).mint(receiver, amount0, amount1, payer);
        success_ = true;
        output_ = abi.encode(amountA, amountB, liquidity);
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

    /**
     * @notice Add liquidity to a smardex pair. Receive liquidity token to materialize shares in the pool
     * @param smardexFactory The smardex factory
     * @param params Parameters of the liquidity to add
     * @param skimReceiver The skim receiver address to use if a skim is performed
     * @return amountA_ The amount of tokenA sent to the pool.
     * @return amountB_ The amount of tokenB sent to the pool.
     * @return pair_ The address of the pool where the liquidity was added.
     */
    function _addLiquidity(
        ISmardexFactory smardexFactory,
        ISmardexRouter.AddLiquidityParams calldata params,
        address skimReceiver
    ) internal returns (uint256 amountA_, uint256 amountB_, address pair_) {
        pair_ = smardexFactory.getPair(params.tokenA, params.tokenB);

        if (pair_ == address(0)) {
            pair_ = smardexFactory.createPair(params.tokenA, params.tokenB);
        }
        if (ISmardexPair(pair_).totalSupply() == 0) {
            ISmardexPair(pair_).skim(skimReceiver); // in case some tokens are already on the pair
        }

        (uint256 reserveA, uint256 reserveB, uint256 reserveAFic, uint256 reserveBFic) =
            PoolHelpers.getAllReserves(ISmardexPair(pair_), params.tokenA);

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
