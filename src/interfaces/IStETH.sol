// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IStETH is IERC20Metadata {
    /**
     * @notice Get the stEth shares of an address
     * @param user The user address
     * @return The amount of user shares
     */
    function sharesOf(address user) external view returns (uint256);

    /**
     * @notice Transfer the shares amount
     * @param recipient The recipient address
     * @param sharesAmount The shares amount
     * @return The amount of transferred shares
     */
    function transferShares(address recipient, uint256 sharesAmount) external returns (uint256);
}
