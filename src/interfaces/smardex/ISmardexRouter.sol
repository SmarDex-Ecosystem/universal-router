// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

interface ISmardexRouter {
    /**
     * @notice parameters used by the addLiquidity function
     * @param tokenA address of the first token in the pair
     * @param tokenB address of the second token in the pair
     * @param amountADesired The amount of tokenA to add as liquidity
     * if the B/A price is <= amountBDesired/amountADesired
     * @param amountBDesired The amount of tokenB to add as liquidity
     * if the A/B price is <= amountADesired/amountBDesired
     * @param amountAMin Bounds the extent to which the B/A price can go up before the transaction reverts.
     * Must be <= amountADesired.
     * @param amountBMin Bounds the extent to which the A/B price can go up before the transaction reverts.
     * Must be <= amountBDesired.
     * @param fictiveReserveB The fictive reserve of tokenB at time of submission
     * @param fictiveReserveAMin The minimum fictive reserve of tokenA indicating the extent to which the A/B price can
     * go down
     * @param fictiveReserveAMax The maximum fictive reserve of tokenA indicating the extent to which the A/B price can
     * go up
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
     * @notice callback data for mint
     * @param token0 address of the first token of the pair
     * @param token1 address of the second token of the pair
     * @param amount0 amount of token0 to provide
     * @param amount1 amount of token1 to provide
     * @param payer address of the payer to provide token for the mint
     */
    struct MintCallbackData {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        address payer;
    }

    /**
     * @notice callback data for swap from SmardexRouter
     * @param path path of the swap, array of token addresses tightly packed
     * @param payer address of the payer for the swap
     */
    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    /**
     * @notice callback to implement when calling SmardexPair.mint
     * @param data callback data for mint
     */
    function smardexMintCallback(MintCallbackData calldata data) external;

    /**
     * @notice callback data for swap
     * @param _amount0Delta amount of token0 for the swap (negative is incoming, positive is required to pay to pair)
     * @param _amount1Delta amount of token1 for the swap (negative is incoming, positive is required to pay to pair)
     * @param _data for Router path and payer for the swap (see router for details)
     */
    function smardexSwapCallback(int256 _amount0Delta, int256 _amount1Delta, bytes calldata _data) external;
}
