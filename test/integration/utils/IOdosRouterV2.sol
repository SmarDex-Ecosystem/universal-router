// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**
 * @title Odos token swapping functionality.
 * @notice Functions for swapping tokens via Odos.
 */
interface IOdosRouterV2 {
    /// @dev Contains all information needed to describe the input and output for a swap
    struct swapTokenInfo {
        address inputToken;
        uint256 inputAmount;
        address inputReceiver;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }

    /**
     * @notice Externally facing interface for swapping two tokens
     * @param tokenInfo All information about the tokens being swapped
     * @param pathDefinition Encoded path definition for executor
     * @param executor Address of contract that will execute the path
     * @param referralCode referral code to specify the source of the swap
     * @return amountOut The amount of the output token received
     */
    function swap(swapTokenInfo memory tokenInfo, bytes calldata pathDefinition, address executor, uint32 referralCode)
        external
        payable
        returns (uint256 amountOut);
}
