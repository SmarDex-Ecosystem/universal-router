// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import { UniswapV2Library } from "@uniswap/universal-router/contracts/modules/uniswap/v2/UniswapV2Library.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeTransferLib } from "solmate/src/utils/SafeTransferLib.sol";

import { IUniswapV2Router } from "../../interfaces/uniswap/IUniswapV2Router.sol";
import { IUniswapV2RouterErrors } from "../../interfaces/uniswap/IUniswapV2RouterErrors.sol";

/// @title Router library for Uniswap v2
library UniswapV2RouterLib {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeTransferLib for address;

    /**
     * @notice Performs a Uniswap v2 exact input swap
     * @param uniswapV2Factory The address of UniswapV3Factory
     * @param uniswapV2PairInitCodeHash The UniswapV2Pair init code hash
     * @param permit2 The permit2 contract
     * @param recipient The recipient of the output tokens
     * @param amountIn The amount of input tokens for the trade
     * @param amountOutMinimum The minimum desired amount of output tokens
     * @param path The path of the trade as an array of token addresses
     * @param payer The address that will be paying the input
     */
    function v2SwapExactInput(
        address uniswapV2Factory,
        bytes32 uniswapV2PairInitCodeHash,
        IAllowanceTransfer permit2,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address[] calldata path,
        address payer
    ) external {
        address firstPair = UniswapV2Library.pairFor(uniswapV2Factory, uniswapV2PairInitCodeHash, path[0], path[1]);
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            _payOrPermit2Transfer(permit2, path[0], payer, firstPair, amountIn);
        }

        IERC20 tokenOut = IERC20(path[path.length - 1]);
        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        _v2Swap(uniswapV2Factory, uniswapV2PairInitCodeHash, path, recipient, firstPair);

        uint256 amountOut = tokenOut.balanceOf(recipient) - balanceBefore;
        if (amountOut < amountOutMinimum) {
            revert IUniswapV2RouterErrors.V2TooLittleReceived();
        }
    }

    /**
     * @notice Performs a Uniswap v2 exact output swap
     * @param uniswapV2Factory The address of UniswapV3Factory
     * @param uniswapV2PairInitCodeHash The UniswapV2Pair init code hash
     * @param permit2 The permit2 contract
     * @param recipient The recipient of the output tokens
     * @param amountOut The amount of output tokens to receive for the trade
     * @param amountInMaximum The maximum desired amount of input tokens
     * @param path The path of the trade as an array of token addresses
     * @param payer The address that will be paying the input
     */
    function v2SwapExactOutput(
        address uniswapV2Factory,
        bytes32 uniswapV2PairInitCodeHash,
        IAllowanceTransfer permit2,
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        address[] calldata path,
        address payer
    ) external {
        (uint256 amountIn, address firstPair) =
            UniswapV2Library.getAmountInMultihop(uniswapV2Factory, uniswapV2PairInitCodeHash, amountOut, path);
        if (amountIn > amountInMaximum) {
            revert IUniswapV2RouterErrors.V2TooMuchRequested();
        }

        _payOrPermit2Transfer(permit2, path[0], payer, firstPair, amountIn);
        _v2Swap(uniswapV2Factory, uniswapV2PairInitCodeHash, path, recipient, firstPair);
    }

    /**
     * @notice Checks if the path is valid and performs the swap
     * @param uniswapV2Factory The address of UniswapV3Factory
     * @param uniswapV2PairInitCodeHash The UniswapV2Pair init code hash
     * @param path The path of the trade as an array of token addresses
     * @param recipient The recipient of the output tokens
     * @param pair The address of the pair to start the swap
     */
    function _v2Swap(
        address uniswapV2Factory,
        bytes32 uniswapV2PairInitCodeHash,
        address[] calldata path,
        address recipient,
        address pair
    ) internal {
        unchecked {
            if (path.length < 2) {
                revert IUniswapV2RouterErrors.V2InvalidPath();
            }

            // cached to save on duplicate operations
            (address token0,) = UniswapV2Library.sortTokens(path[0], path[1]);
            uint256 finalPairIndex = path.length - 1;
            uint256 penultimatePairIndex = finalPairIndex - 1;
            for (uint256 i; i < finalPairIndex; i++) {
                IUniswapV2Router.V2SwapData memory data;

                (data.input, data.output) = (path[i], path[i + 1]);

                (data.reserve0, data.reserve1,) = IUniswapV2Pair(pair).getReserves();

                (data.reserveInput, data.reserveOutput) =
                    data.input == token0 ? (data.reserve0, data.reserve1) : (data.reserve1, data.reserve0);

                data.amountInput = IERC20(data.input).balanceOf(pair) - data.reserveInput;

                data.amountOutput =
                    UniswapV2Library.getAmountOut(data.amountInput, data.reserveInput, data.reserveOutput);

                (data.amount0Out, data.amount1Out) =
                    data.input == token0 ? (uint256(0), data.amountOutput) : (data.amountOutput, uint256(0));
                (data.nextPair, token0) = i < penultimatePairIndex
                    ? UniswapV2Library.pairAndToken0For(
                        uniswapV2Factory, uniswapV2PairInitCodeHash, data.output, path[i + 2]
                    )
                    : (recipient, address(0));
                IUniswapV2Pair(pair).swap(data.amount0Out, data.amount1Out, data.nextPair, new bytes(0));
                pair = data.nextPair;
            }
        }
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
            _pay(token, recipient, amount);
        } else {
            permit2.transferFrom(payer, recipient, amount.toUint160(), token);
        }
    }

    /**
     * @notice Pays an amount of ETH or ERC20 to a recipient
     * @param token The token to pay (can be ETH using Constants.ETH)
     * @param recipient The address that will receive the payment
     * @param value The amount to pay
     */
    function _pay(address token, address recipient, uint256 value) internal {
        if (token == Constants.ETH) {
            recipient.safeTransferETH(value);
        } else {
            if (value == Constants.CONTRACT_BALANCE) {
                value = IERC20(token).balanceOf(address(this));
            }

            IERC20(token).safeTransfer(recipient, value);
        }
    }
}
