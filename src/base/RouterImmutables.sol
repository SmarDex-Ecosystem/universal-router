// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IUsdnProtocol } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";
import { IWusdn } from "@smardex-usdn-contracts-1/src/interfaces/Usdn/IWusdn.sol";

import { ISmardexFactory } from "../interfaces/smardex/ISmardexFactory.sol";

/**
 * @dev Structure to hold the immutable parameters for the router
 * @param permit2 The permit2 address
 * @param weth9 The WETH9 address
 * @param v2Factory The v2 factory address
 * @param v3Factory The v3 factory address
 * @param pairInitCodeHash The v2 pair hash
 * @param poolInitCodeHash The v3 pool hash
 * @param usdnProtocol The USDN protocol address
 * @param wstEth The WstETH address
 * @param wusdn The wrapped usdn address. If the address is set to the zero address,
 * the Usdn wrap and the Wusdn unwrap commands are disabled
 * @param smardexFactory The smardex factory
 */
struct RouterParameters {
    address permit2;
    address weth9;
    address v2Factory;
    address v3Factory;
    bytes32 pairInitCodeHash;
    bytes32 poolInitCodeHash;
    IUsdnProtocol usdnProtocol;
    address wstEth;
    IWusdn wusdn;
    ISmardexFactory smardexFactory;
}
