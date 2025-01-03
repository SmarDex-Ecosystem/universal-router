// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ISmardexRouter {
    /**
     * @notice Parameters used by the {SmardexRouterLib.addLiquidity} function.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param amountADesired The amount of `tokenA` to add as liquidity.
     * if the B/A price is <= `amountBDesired`/`amountADesired`.
     * @param amountBDesired The amount of `tokenB` to add as liquidity.
     * if the A/B price is <= `amountADesired`/`amountBDesired`.
     * @param amountAMin This bounds the extent to which the B/A price can go up before the transaction reverts.
     * Must be <= `amountADesired`.
     * @param amountBMin This bounds the extent to which the A/B price can go up before the transaction reverts.
     * Must be <= `amountBDesired`.
     * @param fictiveReserveB The fictive reserve of tokenB at time of submission.
     * @param fictiveReserveAMin The minimum fictive reserve of `tokenA` indicating the extent to which the A/B price
     * can go down.
     * @param fictiveReserveAMax The maximum fictive reserve of `tokenA` indicating the extent to which the A/B price
     * can go up.
     */
    struct AddLiquidityParams {
        address tokenA;
        address tokenB;
        uint256 amountADesired;
        uint256 amountBDesired;
        uint256 amountAMin;
        uint256 amountBMin;
        uint128 fictiveReserveB;
        uint128 fictiveReserveAMin;
        uint128 fictiveReserveAMax;
    }

    /**
     * @notice The data used by the callback of a token pair's mint function.
     * @param token0 The address of the first token of the pair.
     * @param token1 The address of the second token of the pair.
     * @param amount0 The amount of `token0` to provide.
     * @param amount1 The amount of `token1` to provide.
     * @param payer The address of the payer to provide token for the mint.
     */
    struct MintCallbackData {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        address payer;
    }

    /**
     * @notice The data used by the {SmardexRouterLib.removeLiquidity} function.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @param liquidity The amount of LP tokens to remove.
     * @param amountAMin The minimum amountA to receive.
     * @param amountBMin The minimum amountB to receive.
     */
    struct RemoveLiquidityParams {
        address tokenA;
        address tokenB;
        uint256 liquidity;
        uint256 amountAMin;
        uint256 amountBMin;
    }

    /**
     * @notice The data used by the callback of the {SmardexRouter}'s swap functions.
     * @param path The path of the swap, array of token addresses tightly packed.
     * @param payer The address of the payer for the swap.
     */
    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    /**
     * @notice The callback function called by {SmardexPair.mint}.
     * @param data The callback data.
     */
    function smardexMintCallback(MintCallbackData calldata data) external;

    /**
     * @notice The callback function called after a swap.
     * @dev The negative amount is tokens to be received, positive is required to pay to pair
     * @param amount0Delta The amount of token0 for the swap.
     * @param amount1Delta The amount of token1 for the swap.
     * @param data The data for the router path and payer for the swap.
     */
    function smardexSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}
