// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Enso {
    using SafeERC20 for IERC20;

    /// @notice The address of the Odos SOR router.
    address immutable ODOS_SOR_ROUTER;

    /// @notice Reverts when the swap via Odos fails.
    error OdosSwapFailed();

    /// @param odosSorRouter The address of the Odos SOR router.
    constructor(address odosSorRouter) {
        ODOS_SOR_ROUTER = odosSorRouter;
    }

    /**
     * @notice Swaps tokens via the Odos SOR router.
     * @param tokenIn The address of the input token.
     * @param data The data to send to the Odos SOR router.
     */
    function swapOdos(address tokenIn, uint256 ethAmount, bytes memory data) internal {
        if (ethAmount == 0) {
            // forceApprove is not needed because the allowance is reset to 0 after each swap
            IERC20(tokenIn).approve(ODOS_SOR_ROUTER, type(uint256).max);

            (bool success,) = ODOS_SOR_ROUTER.call(data);
            if (!success) {
                revert OdosSwapFailed();
            }

            IERC20(tokenIn).approve(ODOS_SOR_ROUTER, 0);
        } else {
            (bool success,) = ODOS_SOR_ROUTER.call{ value: ethAmount }(data);
            if (!success) {
                revert OdosSwapFailed();
            }
        }
    }
}
