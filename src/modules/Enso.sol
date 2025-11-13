// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Enso {
    using SafeERC20 for IERC20;

    /// @notice The address of the Enso v2 router.
    address immutable ENSO_V2_ROUTER;

    /// @notice Reverts when the swap via Enso fails.
    error EnsoSwapFailed();

    /// @param ensoV2Router The address of the Enso v2 router.
    constructor(address ensoV2Router) {
        ENSO_V2_ROUTER = ensoV2Router;
    }

    /**
     * @notice Swaps tokens via the Enso router.
     * @param tokenIn The address of the input token.
     * @param data The data to send to the Enso router.
     */
    function swapViaEnso(address tokenIn, uint256 ethAmount, bytes memory data) internal {
        if (ethAmount == 0) {
            // forceApprove is not needed because the allowance is reset to 0 after each swap
            IERC20(tokenIn).approve(ENSO_V2_ROUTER, type(uint256).max);

            (bool success,) = ENSO_V2_ROUTER.call(data);
            if (!success) {
                revert EnsoSwapFailed();
            }

            IERC20(tokenIn).approve(ENSO_V2_ROUTER, 0);
        } else {
            (bool success,) = ENSO_V2_ROUTER.call{ value: ethAmount }(data);
            if (!success) {
                revert EnsoSwapFailed();
            }
        }
    }
}
