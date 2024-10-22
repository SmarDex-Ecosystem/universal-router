// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { LockAndMap } from "../../../../src/modules/usdn/LockAndMap.sol";

contract LockAndMapHandler is LockAndMap {
    function i_map(address recipient) external view returns (address) {
        return map(recipient);
    }

    function i_mapSafe(address recipient) external view returns (address output_) {
        return _mapSafe(recipient);
    }
}
