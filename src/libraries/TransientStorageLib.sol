// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

library TransientStorageLib {
    /**
     * @notice Set the transient value
     * @dev Uses the transient storage
     * @param slot The slot value
     * @param value The value to store
     */
    function setTransientValue(bytes32 slot, bytes32 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @notice Get the transient value
     * @dev Uses the transient storage
     * @param slot The slot value
     * @return value_ The value to return
     */
    function getTransientValue(bytes32 slot) internal view returns (bytes32 value_) {
        assembly ("memory-safe") {
            value_ := tload(slot)
        }
    }
}
