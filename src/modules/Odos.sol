// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

abstract contract Odos {
    address immutable ODOS_SOR_ROUTER;

    /// @notice Reverts when the swap via Odos fails.
    error OdosSwapFailed();

    constructor(address odosSorRouter) {
        ODOS_SOR_ROUTER = odosSorRouter;
    }

    function swapOdos(address tokenIn, uint256 amountIn, bytes memory data) internal {
        if (amountIn == Constants.CONTRACT_BALANCE) {
            amountIn = IERC20(tokenIn).balanceOf(address(this));
        }

        if (IERC20(tokenIn).allowance(address(this), ODOS_SOR_ROUTER) < amountIn) {
            IERC20(tokenIn).approve(ODOS_SOR_ROUTER, type(uint256).max);
        }

        (bool success,) = ODOS_SOR_ROUTER.call(data);
        if (!success) {
            revert OdosSwapFailed();
        }
    }
}
