// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";

import { Path } from "../../src/libraries/Path.sol";

/// @custom:feature Test the universal-router `Path` library
contract PathTest is Test {
    /**
     * @custom:scenario The `hasMultiplePool` function return true
     * @custom:when The `hasMultiplePool` function is called with a 3 addresses length path
     * @custom:then The call return true
     */
    function test_hasMultiplePoolsTrue() external pure {
        bytes memory multiplePools = abi.encodePacked(address(1), address(2), address(3));
        assertTrue(Path.hasMultiplePools(multiplePools), "The hasMultiplePools call should return true");
    }

    /**
     * @custom:scenario The `hasMultiplePool` function return false
     * @custom:when The `hasMultiplePool` function is called with a 2 addresses length path
     * @custom:then The call return false
     */
    function test_hasMultiplePoolsFalse() external pure {
        bytes memory multiplePools = abi.encodePacked(address(1), address(2));
        assertFalse(Path.hasMultiplePools(multiplePools), "The hasMultiplePools call should return false");
    }

    /**
     * @custom:scenario The `decodeFirstPool` function return 2 addresses
     * @custom:when The `decodeFirstPool` function is called with a 3 addresses length path
     * @custom:then The call return the 2 first addresses
     */
    function test_decodeFirstPool() external pure {
        bytes memory multiplePools = abi.encodePacked(address(1), address(2), address(3));
        (address tokenA, address tokenB) = Path.decodeFirstPool(multiplePools);
        assertEq(tokenA, address(1), "The tokenA should be address 1");
        assertEq(tokenB, address(2), "The tokenA should be address 2");
    }

    /**
     * @custom:scenario The `decodeFirstToken` function return an address
     * @custom:when The `decodeFirstToken` function is called with a 3 addresses length path
     * @custom:then The call return the first address
     */
    function test_decodeFirstToken() external pure {
        bytes memory multiplePools = abi.encodePacked(address(1), address(2), address(3));
        assertEq(Path.decodeFirstToken(multiplePools), address(1), "The decodeFirstToken call should return address 1");
    }

    /**
     * @custom:scenario The `decodeFirstToken` function return an address
     * @custom:when The `decodeFirstToken` function is called with a 3 addresses length path
     * @custom:then The call return the first address
     */
    function test_getFirstPool() external pure {
        bytes memory multiplePools = abi.encodePacked(address(1), address(2), address(3));
        bytes memory simplePool = abi.encodePacked(address(1), address(2));
        assertEq(Path.getFirstPool(multiplePools), simplePool, "The getFirstPool call should return simple pool");
    }

    /**
     * @custom:scenario The `skipToken` function return a shorted path
     * @custom:when The `skipToken` function is called with a 3 addresses length path
     * @custom:then The call return the 2 last addresses length path
     */
    function test_skipToken() external pure {
        bytes memory multiplePools = abi.encodePacked(address(1), address(2), address(3));
        bytes memory simplePool = abi.encodePacked(address(2), address(3));
        assertEq(Path.skipToken(multiplePools), simplePool, "The skipToken call should return simple pool");
    }

    /**
     * @custom:scenario The `encodeTightlyPackedReversed` function return a reversed path
     * @custom:when The `encodeTightlyPackedReversed` function is called with a 3 addresses length path
     * @custom:then The call return the reversed path
     */
    function test_encodeTightlyPackedReversed() external pure {
        bytes memory multiplePools = abi.encodePacked(address(1), address(2), address(3));
        bytes memory reversedMultiplePools = abi.encodePacked(address(3), address(2), address(1));
        bytes memory result = Path.encodeTightlyPackedReversed(multiplePools);

        assertEq(result, reversedMultiplePools, "The result should be equal reversedMultiplePools");
        assertEq(multiplePools.length, result.length, "The result should have same length than multiplePools");
    }

    /**
     * @custom:scenario The `encodeTightlyPackedReversed` function with an empty path
     * @custom:when The `encodeTightlyPackedReversed` function is called with an empty path
     * @custom:then The call revert with `InvalidPath`
     */
    function test_RevertWhen_encodeTightlyPackedReversedEmpty() external {
        vm.expectRevert(Path.InvalidPath.selector);
        Path.encodeTightlyPackedReversed("");
    }

    /**
     * @custom:scenario The `encodeTightlyPackedReversed` function with an invalid path length
     * @custom:when The `encodeTightlyPackedReversed` function is called with an invalid path length
     * @custom:then The call revert with `InvalidPath`
     */
    function test_RevertWhen_encodeTightlyPackedReversedInvalid() external {
        vm.expectRevert(Path.InvalidPath.selector);
        Path.encodeTightlyPackedReversed(new bytes(1));
    }
}
