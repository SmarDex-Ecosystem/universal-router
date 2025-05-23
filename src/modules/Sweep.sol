// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { Payments } from "@uniswap/universal-router/contracts/modules/Payments.sol";
import { ERC20 } from "solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/src/utils/SafeTransferLib.sol";

/**
 * @title Sweep contract
 * @notice Sweeps all of the contract's ERC20 or ETH to an address
 */
abstract contract Sweep {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    /// @notice Reverts when the recipient is invalid for a sweep operation.
    error SweepInvalidRecipient();

    /**
     * @notice Sweeps all of the contract's ERC20 or ETH to an address
     * @param token The token to sweep (can be ETH using Constants.ETH)
     * @param recipient The address that will receive payment
     * @param amountOutMin The minimum desired amount
     * @param amountOutThreshold The minimum amount to activate the sweep
     */
    function sweep(address token, address recipient, uint256 amountOutMin, uint256 amountOutThreshold) internal {
        uint256 balance;
        if (token == Constants.ETH) {
            if (recipient == address(0)) {
                revert SweepInvalidRecipient();
            }
            balance = address(this).balance;
            if (balance < amountOutMin) {
                revert Payments.InsufficientETH();
            }
            if (balance >= amountOutThreshold) {
                recipient.safeTransferETH(balance);
            }
        } else {
            balance = ERC20(token).balanceOf(address(this));
            if (balance < amountOutMin) {
                revert Payments.InsufficientToken();
            }
            if (balance >= amountOutThreshold) {
                ERC20(token).safeTransfer(recipient, balance);
            }
        }
    }
}
