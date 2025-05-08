// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { ILidoImmutables } from "../../interfaces/lido/ILidoImmutables.sol";
import { IStETH } from "../../interfaces/lido/IStETH.sol";
import { IWstETH } from "../../interfaces/lido/IWstETH.sol";

contract LidoImmutables is ILidoImmutables {
    /// @inheritdoc ILidoImmutables
    IStETH public immutable STETH;

    /// @dev The address of the wrapped steth
    IWstETH internal immutable WSTETH;

    /// @param wsteth The address of wrapped steth
    constructor(address wsteth) {
        WSTETH = IWstETH(wsteth);
        STETH = IStETH(WSTETH.stETH());
    }
}
