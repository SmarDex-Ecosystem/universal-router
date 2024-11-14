// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IWstETH } from "../../interfaces/IWstETH.sol";
import { IStETH } from "../../interfaces/IStETH.sol";

/// @title Router library for Lido
library LidoRouterLib {
    using SafeERC20 for IWstETH;
    using SafeERC20 for IStETH;

    /**
     * @notice Wrap all of the contract's stETH into wstETH
     * @param steth The steth contract
     * @param wsteth The wsteth contract
     * @param recipient The recipient of the wstETH
     * @return Whether the wrapping was successful
     */
    function wrapSTETH(IStETH steth, IWstETH wsteth, address recipient) external returns (bool) {
        uint256 amount = steth.balanceOf(address(this));
        if (amount == 0) {
            return false;
        }
        steth.forceApprove(address(wsteth), amount);
        amount = wsteth.wrap(amount);

        if (recipient != address(this)) {
            wsteth.safeTransfer(recipient, amount);
        }
        return true;
    }

    /**
     * @notice Unwraps all of the contract's wstETH into stETH
     * @param steth The steth contract
     * @param wsteth The wsteth contract
     * @param recipient The recipient of the stETH
     * @return Whether the unwrapping was successful
     */
    function unwrapWSTETH(IStETH steth, IWstETH wsteth, address recipient) external returns (bool) {
        uint256 amount = wsteth.balanceOf(address(this));
        if (amount == 0) {
            return false;
        }

        uint256 stEthSharesBefore = steth.sharesOf(address(this));
        wsteth.unwrap(amount);
        uint256 stEthSharesAmount = steth.sharesOf(address(this)) - stEthSharesBefore;

        if (stEthSharesAmount == 0) {
            return false;
        }

        if (recipient != address(this)) {
            steth.transferShares(recipient, stEthSharesAmount);
        }

        return true;
    }
}
