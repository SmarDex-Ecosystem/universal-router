// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import { ISmardexPair } from "../../interfaces/smardex/ISmardexPair.sol";

library PoolHelpers {
    /**
     * @notice sort token addresses, used to handle return values from pairs sorted in this order
     * @param _tokenA token to sort
     * @param _tokenB token to sort
     * @return token0_ token0 sorted
     * @return token1_ token1 sorted
     */
    function sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0_, address token1_) {
        require(_tokenA != _tokenB, "SmardexHelper: IDENTICAL_ADDRESSES");
        (token0_, token1_) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(token0_ != address(0), "SmardexHelper: ZERO_ADDRESS");
    }

    /**
     * @notice fetches the real and fictive reserves for a pair
     * @param pair The pair contract
     * @param tokenA The tokenA address
     * @return reserveA_ reserves of tokenA in the pair tokenA/TokenB
     * @return reserveB_ reserves of tokenB in the pair tokenA/TokenB
     * @return fictiveReserveA_ fictive reserves of tokenA in the pair tokenA/TokenB
     * @return fictiveReserveB_ fictive reserves of tokenB in the pair tokenA/TokenB
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
     * @notice given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
     * @param _amountA amount of asset A
     * @param _reserveA reserve of asset A
     * @param _reserveB reserve of asset B
     * @return amountB_ equivalent amount of asset B
     */
    function quote(uint256 _amountA, uint256 _reserveA, uint256 _reserveB) internal pure returns (uint256 amountB_) {
        require(_amountA != 0, "SmardexHelper: INSUFFICIENT_AMOUNT");
        require(_reserveA != 0 && _reserveB != 0, "SmardexHelper: INSUFFICIENT_LIQUIDITY");
        amountB_ = (_amountA * _reserveB) / _reserveA;
    }

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
