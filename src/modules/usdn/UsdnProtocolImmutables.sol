// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IUsdnProtocol } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";
import { IUsdn } from "usdn-contracts/src/interfaces/Usdn/IUsdn.sol";
import { IWusdn } from "usdn-contracts/src/interfaces/Usdn/IWusdn.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";

struct UsdnProtocolParameters {
    IUsdnProtocol usdnProtocol;
    IWusdn wusdn;
    address permit2;
}

contract UsdnProtocolImmutables {
    /// @dev The address of the USDN protocol
    IUsdnProtocol internal immutable USDN_PROTOCOL;

    /// @dev The address of the protocol asset
    IERC20Metadata internal immutable PROTOCOL_ASSET;

    /// @dev The address of the SDEX token
    IERC20Metadata internal immutable SDEX;

    /// @dev The address of the USDN
    IUsdn internal immutable USDN;

    /// @dev The address of the WUSDN
    IWusdn internal immutable WUSDN;

    /// @dev The permit2 contract
    IAllowanceTransfer internal immutable USDN_PROTOCOL_PERMIT2;

    /// @param params The immutable parameters for the USDN protocol
    constructor(UsdnProtocolParameters memory params) {
        USDN_PROTOCOL = params.usdnProtocol;
        PROTOCOL_ASSET = params.usdnProtocol.getAsset();
        SDEX = params.usdnProtocol.getSdex();
        WUSDN = params.wusdn;
        USDN = params.wusdn.USDN();
        USDN_PROTOCOL_PERMIT2 = IAllowanceTransfer(params.permit2);
    }
}
