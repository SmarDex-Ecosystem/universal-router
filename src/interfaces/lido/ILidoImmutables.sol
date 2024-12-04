// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import { IStETH } from "./IStETH.sol";

interface ILidoImmutables {
    /**
     * @notice Getter for the steth token
     * @return The steth token
     */
    function STETH() external view returns (IStETH);
}
