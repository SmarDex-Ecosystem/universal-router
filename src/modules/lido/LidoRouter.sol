// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { LidoImmutables } from "./LidoImmutables.sol";
import { LidoRouterLib } from "../../libraries/lido/LidoRouterLib.sol";

/// @title Router for Lido
abstract contract LidoRouter is LidoImmutables {
    /**
     * @notice Wrap all of the contract's stETH into wstETH
     * @param recipient The recipient of the wstETH
     * @return Whether the wrapping was successful
     */
    function _wrapSTETH(address recipient) internal returns (bool) {
        return LidoRouterLib.wrapSTETH(STETH, WSTETH, recipient);
    }

    /**
     * @notice Unwraps all of the contract's wstETH into stETH
     * @param recipient The recipient of the stETH
     * @return Whether the unwrapping was successful
     */
    function _unwrapWSTETH(address recipient) internal returns (bool) {
        return LidoRouterLib.unwrapWSTETH(STETH, WSTETH, recipient);
    }
}
