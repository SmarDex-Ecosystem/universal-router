// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IStETH } from "../interfaces/IStETH.sol";

interface ILidoImmutables {
    /**
     * @notice Getter for the steth token
     * @return The steth token
     */
    function STETH() external view returns (IStETH);
}
