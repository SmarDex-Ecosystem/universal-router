// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeTransferLib } from "solmate/src/utils/SafeTransferLib.sol";

/// @title Payment library for swapping
library Payment {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeTransferLib for address;

    /**
     * @notice Either performs a regular payment or transferFrom on Permit2, depending on the payer address
     * @param permit2 The permit2 contract
     * @param token The token to transfer
     * @param payer The address to pay for the transfer
     * @param recipient The recipient of the transfer
     * @param amount The amount to transfer
     */
    function _pay(IAllowanceTransfer permit2, address token, address payer, address recipient, uint256 amount)
        external
    {
        if (payer == address(this)) {
            if (token == Constants.ETH) {
                recipient.safeTransferETH(amount);
            } else {
                if (amount == Constants.CONTRACT_BALANCE) {
                    amount = IERC20(token).balanceOf(address(this));
                }

                IERC20(token).safeTransfer(recipient, amount);
            }
        } else {
            permit2.transferFrom(payer, recipient, amount.toUint160(), token);
        }
    }
}
