// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { IMapErrors } from "../interfaces/IMapErrors.sol";

library Map {
    /**
     *  @notice Calculates the recipient address for a command
     *  @param lockedBy The sender address locked by the contract
     *  @param recipient The recipient or recipient-flag for the command
     *  @return output_ The resultant recipient for the command
     */
    function _map(address lockedBy, address recipient) internal view returns (address output_) {
        if (recipient == Constants.ADDRESS_THIS || recipient == address(this)) {
            revert IMapErrors.InvalidRecipient();
        } else if (recipient == Constants.MSG_SENDER) {
            return lockedBy;
        } else {
            return recipient;
        }
    }
}
