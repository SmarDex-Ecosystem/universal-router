// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Odos {
    using SafeERC20 for IERC20;

    address immutable ODOS_SOR_ROUTER;

    /// @notice Reverts when the swap via Odos fails.
    error OdosSwapFailed();

    constructor(address odosSorRouter) {
        ODOS_SOR_ROUTER = odosSorRouter;
    }

    function swapOdos(address tokenIn, uint256 amountToApprove, bytes memory data) internal {
        if (amountToApprove == Constants.CONTRACT_BALANCE) {
            amountToApprove = IERC20(tokenIn).balanceOf(address(this));
        }
        IERC20(tokenIn).approve(ODOS_SOR_ROUTER, amountToApprove);

        (bool success,) = ODOS_SOR_ROUTER.call(data);
        if (!success) {
            revert OdosSwapFailed();
        }

        IERC20(tokenIn).approve(ODOS_SOR_ROUTER, 0);
    }
}
