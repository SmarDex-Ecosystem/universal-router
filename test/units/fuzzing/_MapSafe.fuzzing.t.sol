// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";

import { LockAndMapHandler, LockAndMap } from "./utils/LockAndMapHandler.sol";

/**
 * @custom:feature Test fuzzing of the {_mapSafe} function
 * @custom:background Given a deployed {LockAndMap} contract
 */
contract TestMapSafeFuzzing is Test {
    LockAndMapHandler internal handler;

    function setUp() public {
        handler = new LockAndMapHandler();
    }

    /**
     * @custom:scenario The result value of {i_mapSafe} should match the original {i_map} or revert
     * @custom:when The {i_mapSafe} is called with a random recipient address
     * @custom:then The result should be equal to the {i_map} result
     * @custom:or The call should reverts with {LockAndMapInvalidRecipient}
     */
    function testFuzz_safeMap(address recipient) public view {
        try handler.i_mapSafe(recipient) returns (address recipient_) {
            assertEq(recipient_, handler.i_map(recipient), "the recipient_ should be equal to the map result");
        } catch (bytes memory reason) {
            assertEq(
                bytes4(reason),
                LockAndMap.LockAndMapInvalidRecipient.selector,
                "Error should be the LockAndMapInvalidRecipient"
            );
        }
    }
}
