// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { SafeTransferLib } from "solmate/src/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/src/tokens/ERC20.sol";

library Sweep {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    /// @notice Indicates that the contract has insufficient tokens
    error InsufficientToken();
    /// @notice Indicates that the contract has insufficient ETH
    error InsufficientETH();

    /**
     * @notice Sweeps all of the contract's ERC20 or ETH to an address
     * @param token The token to sweep (can be ETH using Constants.ETH)
     * @param recipient The address that will receive payment
     * @param amountMinimum The minimum desired amount
     * @param amountMinimumForGas The minimum amount to activate the sweep
     */
    function sweep(address token, address recipient, uint256 amountMinimum, uint256 amountMinimumForGas) internal {
        uint256 balance;
        if (token == Constants.ETH) {
            balance = address(this).balance;
            if (balance < amountMinimum) revert InsufficientETH();
            if (balance > amountMinimumForGas) {
                recipient.safeTransferETH(balance);
            }
        } else {
            balance = ERC20(token).balanceOf(address(this));
            if (balance < amountMinimum) revert InsufficientToken();
            if (balance > amountMinimumForGas) {
                ERC20(token).safeTransfer(recipient, balance);
            }
        }
    }
}
