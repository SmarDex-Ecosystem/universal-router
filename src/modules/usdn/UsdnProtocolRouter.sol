// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IPaymentCallback } from "usdn-contracts/src/interfaces/UsdnProtocol/IPaymentCallback.sol";
import { IUsdn } from "usdn-contracts/src/interfaces/Usdn/IUsdn.sol";

import { UsdnProtocolImmutables } from "./UsdnProtocolImmutables.sol";
import { UsdnProtocolRouterLib } from "../../libraries/usdn/UsdnProtocolRouterLib.sol";
import { LockAndMap } from "./LockAndMap.sol";

/// @title Router for UsdnProtocol
abstract contract UsdnProtocolRouter is UsdnProtocolImmutables, IPaymentCallback, ERC165, LockAndMap {
    /// @inheritdoc IPaymentCallback
    function transferCallback(IERC20Metadata token, uint256 amount, address to) external {
        UsdnProtocolRouterLib.transferCallback(
            address(USDN_PROTOCOL), lockedBy, USDN_PROTOCOL_PERMIT2, token, amount, to
        );
    }

    /// @inheritdoc IPaymentCallback
    function usdnTransferCallback(IUsdn usdn, uint256 shares) external {
        UsdnProtocolRouterLib.usdnTransferCallback(address(USDN_PROTOCOL), usdn, lockedBy, shares);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        if (interfaceId == type(IPaymentCallback).interfaceId) {
            return true;
        }

        return super.supportsInterface(interfaceId);
    }
}
