// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

interface IUniswapV2Router {
    /**
     * @dev Structure to hold the data for a swap
     * @param input The input token address
     * @param output The output token address
     * @param nextPair The next pair to swap to
     * @param reserve0 The reserve0 of the pair
     * @param reserve1 The reserve1 of the pair
     * @param reserveInput The reserve of the input token
     * @param reserveOutput The reserve of the output token
     * @param amountInput The amount of input tokens
     * @param amountOutput The amount of output tokens
     * @param amount0Out The amount of token0 to swap
     * @param amount1Out The amount of token1 to swap
     */
    struct V2SwapData {
        address input;
        address output;
        address nextPair;
        uint256 reserve0;
        uint256 reserve1;
        uint256 reserveInput;
        uint256 reserveOutput;
        uint256 amountInput;
        uint256 amountOutput;
        uint256 amount0Out;
        uint256 amount1Out;
    }
}
