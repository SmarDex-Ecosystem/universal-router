// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { ISmardexFactory } from "../../interfaces/smardex/ISmardexFactory.sol";

contract SmardexImmutables {
    /// @dev The Smardex factory
    ISmardexFactory internal immutable SMARDEX_FACTORY;

    /// @param smardexFactory The Smardex factory
    constructor(ISmardexFactory smardexFactory) {
        SMARDEX_FACTORY = smardexFactory;
    }
}
