// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Permit2Payments } from "@uniswap/universal-router/contracts/modules/Permit2Payments.sol";

import { LidoImmutables } from "./LidoImmutables.sol";
import { IWstETH } from "../../interfaces/IWstETH.sol";
import { IStETH } from "../../interfaces/IStETH.sol";

/// @title Router for StEth
abstract contract LidoRouter is LidoImmutables, Permit2Payments {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IWstETH;
    using SafeERC20 for IStETH;

    /**
     * @notice Wrap all of the contract's stETH into wstETH
     * @param recipient The recipient of the wstETH
     * @return Whether the wrapping was successful
     */
    function _wrapSTETH(address recipient) internal returns (bool) {
        uint256 amount = STETH.balanceOf(address(this));
        if (amount == 0) {
            return false;
        }
        STETH.forceApprove(address(WSTETH), amount);
        amount = WSTETH.wrap(amount);

        if (recipient != address(this)) {
            WSTETH.safeTransfer(recipient, amount);
        }
        return true;
    }

    /**
     * @notice Unwraps all of the contract's wstETH into stETH
     * @param recipient The recipient of the stETH
     * @return Whether the unwrapping was successful
     */
    function _unwrapWSTETH(address recipient) internal returns (bool) {
        uint256 amount = WSTETH.balanceOf(address(this));
        if (amount == 0) {
            return false;
        }

        uint256 stEthSharesBefore = STETH.sharesOf(address(this));
        WSTETH.unwrap(amount);
        uint256 stEthSharesAmount = STETH.sharesOf(address(this)) - stEthSharesBefore;

        if (stEthSharesAmount == 0) {
            return false;
        }

        if (recipient != address(this)) {
            STETH.transferShares(recipient, stEthSharesAmount);
        }

        return true;
    }
}
