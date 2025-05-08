// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IUsdn } from "@smardex-usdn-contracts-1/src/interfaces/Usdn/IUsdn.sol";
import { IWusdn } from "@smardex-usdn-contracts-1/src/interfaces/Usdn/IWusdn.sol";
import { IUsdnProtocol } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";

struct UsdnProtocolParameters {
    IUsdnProtocol usdnProtocol;
    IWusdn wusdn;
}

contract UsdnProtocolImmutables {
    /// @dev The address of the USDN protocol
    IUsdnProtocol internal immutable USDN_PROTOCOL;

    /// @dev The address of the protocol asset
    IERC20Metadata internal immutable PROTOCOL_ASSET;

    /// @dev The address of the USDN
    IUsdn internal immutable USDN;

    /// @dev The address of the WUSDN
    IWusdn internal immutable WUSDN;

    /// @param params The immutable parameters for the USDN protocol
    constructor(UsdnProtocolParameters memory params) {
        USDN_PROTOCOL = params.usdnProtocol;
        PROTOCOL_ASSET = params.usdnProtocol.getAsset();
        WUSDN = params.wusdn;
        USDN = params.usdnProtocol.getUsdn();
    }
}
