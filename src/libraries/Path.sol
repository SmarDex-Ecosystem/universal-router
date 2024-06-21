// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

// libraries
import "./BytesLib.sol";

/**
 * @title Functions for manipulating path data for multihop swaps
 * @custom:from UniswapV3
 * @custom:url https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/Path.sol
 * @custom:editor SmarDex team
 */
library Path {
    using BytesLib for bytes;

    /// @dev The length of the bytes encoded address
    uint256 private constant ADDR_SIZE = 20;
    /// @dev The offset of a single token address
    uint256 private constant NEXT_OFFSET = ADDR_SIZE;
    /// @dev The offset of an encoded pool key
    uint256 private constant POP_OFFSET = NEXT_OFFSET + ADDR_SIZE;
    /// @dev The minimum length of an encoding that contains 2 or more pools
    uint256 private constant MULTIPLE_POOLS_MIN_LENGTH = POP_OFFSET + NEXT_OFFSET;

    /**
     * @notice Returns true if the path contains two or more pools
     * @param path The encoded swap path
     * @return True if path contains two or more pools, otherwise false
     */
    function hasMultiplePools(bytes memory path) internal pure returns (bool) {
        return path.length >= MULTIPLE_POOLS_MIN_LENGTH;
    }

    /**
     * @notice Decodes the first pool in path
     * @param path The bytes encoded swap path
     * @return tokenA_ The first token of the given pool
     * @return tokenB_ The second token of the given pool
     */
    function decodeFirstPool(bytes memory path) internal pure returns (address tokenA_, address tokenB_) {
        tokenA_ = path.toAddress(0);
        tokenB_ = path.toAddress(NEXT_OFFSET);
    }

    /**
     * @notice Decodes the first token in path
     * @param path The bytes encoded swap path
     * @return tokenA_ The first token of the given pool
     */
    function decodeFirstToken(bytes calldata path) internal pure returns (address tokenA_) {
        tokenA_ = path.toAddress(0);
    }

    /**
     * @notice Gets the segment corresponding to the first pool in the path
     * @param path The bytes encoded swap path
     * @return The segment containing all data necessary to target the first pool in the path
     */
    function getFirstPool(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(0, POP_OFFSET);
    }

    /**
     * @notice Skips a token from the buffer and returns the remainder
     * @dev Require a calldata path
     * @param _path The swap path
     * @return The remaining token elements in the path
     */
    function skipToken(bytes calldata _path) internal pure returns (bytes calldata) {
        return _path[NEXT_OFFSET:];
    }
}
