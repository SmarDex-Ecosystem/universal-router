// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";

import { PoolHelpers } from "../../src/libraries/smardex/PoolHelpers.sol";

/// @custom:feature Test the universal-router `PoolHelpers` library
contract PoolHelpersTest is Test {
    /**
     * @custom:scenario Tests the {quote} function with an insufficient amount
     * @custom:when The {quote} function is called
     * @custom:then The call revert with {InsufficientAmount}
     * forge-config: default.allow_internal_expect_revert = true
     */
    function test_RevertWhen_quoteInsufficientAmount() public {
        vm.expectRevert(PoolHelpers.InsufficientAmount.selector);
        PoolHelpers.quote(0, 0, 0);
    }

    /**
     * @custom:scenario Tests the {quote} function with an insufficient liquidity
     * @custom:when The {quote} function is called
     * @custom:then The call revert with {InsufficientLiquidity}
     * forge-config: default.allow_internal_expect_revert = true
     */
    function test_RevertWhen_quoteInsufficientLiquidity() public {
        vm.expectRevert(PoolHelpers.InsufficientLiquidity.selector);
        PoolHelpers.quote(1, 0, 0);
    }

    /**
     * @custom:scenario Tests the {sortAmounts} function with ordered and disordered values
     * @custom:given Two different addresses
     * @custom:and Two different amounts
     * @custom:when The {sortAmounts} function is called with ordered values
     * @custom:then The call return ordered amounts
     * @custom:when The {sortAmounts} function is called with disordered values
     * @custom:then The call return reordered amounts
     */
    function test_sortAmounts() public pure {
        address token0 = address(0);
        uint256 amount0;
        address token1 = address(1);
        uint256 amount1 = 1;

        assertTrue(token0 < token1, "The token0 should be lower than the token1");

        (uint256 orderedAmount0, uint256 orderedAmount1) = PoolHelpers.sortAmounts(token0, token1, amount0, amount1);
        (uint256 reorderedAmount0, uint256 reorderedAmount1) = PoolHelpers.sortAmounts(token1, token0, amount1, amount0);

        assertTrue(orderedAmount0 == amount0 && reorderedAmount0 == amount0, "The values must be equal amount0");
        assertTrue(orderedAmount1 == amount1 && reorderedAmount1 == amount1, "The values must be equal amount1");
    }
}
