// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IUniversalRouterErrors } from "../interfaces/IUniversalRouterErrors.sol";

abstract contract Odos {
    address immutable ODOS_SOR_ROUTER;

    constructor(address odosSorRouter) {
        ODOS_SOR_ROUTER = odosSorRouter;
    }

    function swapOdos(address tokenIn, uint256 amountIn, bytes memory data) internal {
        if (IERC20(tokenIn).allowance(address(this), ODOS_SOR_ROUTER) < amountIn) {
            IERC20(tokenIn).approve(ODOS_SOR_ROUTER, type(uint256).max);
        }

        (bool success,) = ODOS_SOR_ROUTER.call(data);
        if (!success) {
            revert IUniversalRouterErrors.OdosSwapFailed();
        }
    }
}
