// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import { IWETH9 } from "@uniswap/universal-router/contracts/interfaces/external/IWETH9.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";

import { ISmardexFactory } from "../../interfaces/smardex/ISmardexFactory.sol";

/**
 * @notice The smardex parameters struct
 * @param smardexFactory The smardex factory
 * @param weth The wrapped ETH address
 * @param permit2 The permit2 address
 */
struct SmardexParameters {
    ISmardexFactory smardexFactory;
    address weth;
    address permit2;
}

contract SmardexImmutables {
    /// @dev The smardex factory
    ISmardexFactory internal immutable SMARDEX_FACTORY;

    /// @dev The wrapped ETH
    IWETH9 internal immutable WETH;

    /// @dev The permit2 contract
    IAllowanceTransfer internal immutable SMARDEX_PERMIT2;

    /// @param params The smardex parameters
    constructor(SmardexParameters memory params) {
        SMARDEX_FACTORY = params.smardexFactory;
        WETH = IWETH9(params.weth);
        SMARDEX_PERMIT2 = IAllowanceTransfer(params.permit2);
    }
}
