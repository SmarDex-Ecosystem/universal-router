// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { ISmardexFactory } from "../../interfaces/smardex/ISmardexFactory.sol";

/**
 * @notice The Smardex parameters struct
 * @param smardexFactory The Smardex factory
 * @param weth The wrapped ETH address
 * @param permit2 The permit2 address
 */
struct SmardexParameters {
    ISmardexFactory smardexFactory;
}

contract SmardexImmutables {
    /// @dev The Smardex factory
    ISmardexFactory internal immutable SMARDEX_FACTORY;

    /// @param smardexFactory The Smardex factory
    constructor(ISmardexFactory smardexFactory) {
        SMARDEX_FACTORY = smardexFactory;
    }
}
