// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IWstETH } from "../../interfaces/IWstETH.sol";
import { IStETH } from "../../interfaces/IStETH.sol";
import { ILidoImmutables } from "../../interfaces/ILidoImmutables.sol";

contract LidoImmutables is ILidoImmutables {
    /// @inheritdoc ILidoImmutables
    IStETH public immutable STETH;

    /// @dev The address of the wrapped steth.
    IWstETH internal immutable WSTETH;

    /// @param wsteth The address of wrapped steth.
    constructor(address wsteth) {
        WSTETH = IWstETH(wsteth);
        STETH = IStETH(WSTETH.stETH());
    }
}
