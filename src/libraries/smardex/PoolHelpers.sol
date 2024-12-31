// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import { ISmardexPair } from "../../interfaces/smardex/ISmardexPair.sol";

library PoolHelpers {
    /// @notice The given amount of asset is insufficient.
    error InsufficientAmount();
    /// @notice The amount of liquidity in the pair is insufficient.
    error InsufficientLiquidity();

    /**
     * @notice Gets the real and fictive reserves for a pair.
     * @param pair The pair to get the reserves of.
     * @param tokenA The address of `tokenA`.
     * @return reserveA_ The reserve of `tokenA`.
     * @return reserveB_ The reserve of `tokenB`.
     * @return fictiveReserveA_ The fictive reserve of `tokenA`.
     * @return fictiveReserveB_ The fictive reserve of `tokenB`.
     */
    function getAllReserves(ISmardexPair pair, address tokenA)
        internal
        view
        returns (uint256 reserveA_, uint256 reserveB_, uint256 fictiveReserveA_, uint256 fictiveReserveB_)
    {
        (uint256 reserve0, uint256 reserve1) = pair.getReserves();
        (uint256 fictiveReserve0, uint256 fictiveReserve1) = pair.getFictiveReserves();
        if (tokenA == pair.token0()) {
            reserveA_ = reserve0;
            reserveB_ = reserve1;
            fictiveReserveA_ = fictiveReserve0;
            fictiveReserveB_ = fictiveReserve1;
        } else {
            reserveA_ = reserve1;
            reserveB_ = reserve0;
            fictiveReserveA_ = fictiveReserve1;
            fictiveReserveB_ = fictiveReserve0;
        }
    }

    /**
     * @notice Calculates the estimated amount of `tokenB` received for the given amount of `tokenA`.
     * @param amountA The amount of `tokenA` to exchange.
     * @param reserveA The reserve of `tokenA`.
     * @param reserveB The reserve of `tokenB`.
     * @return amountB_ The estimated amount of `tokenB` to be received.
     */
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB_) {
        if (amountA == 0) {
            revert InsufficientAmount();
        }
        if (reserveA == 0 || reserveB == 0) {
            revert InsufficientLiquidity();
        }

        amountB_ = (amountA * reserveB) / reserveA;
    }

    /**
     * @notice Sorts the given amounts of tokens by token address in ascending order.
     * @param tokenA The `tokenA` address.
     * @param tokenB The `tokenB` address
     * @param amountA The amount of `tokenA`
     * @param amountB The amount of `tokenB`
     * @return amount0_ The amount of `token0`
     * @return amount1_ The amount of `token1`
     */
    function sortAmounts(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        internal
        pure
        returns (uint256 amount0_, uint256 amount1_)
    {
        bool orderedPair = tokenA < tokenB;
        if (orderedPair) {
            amount0_ = amountA;
            amount1_ = amountB;
        } else {
            amount0_ = amountB;
            amount1_ = amountA;
        }
    }
}
