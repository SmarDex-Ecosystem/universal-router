// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IUniversalRouterErrors {
    /// @notice Reverts when the recipient is invalid for a sweep operation.
    error SweepInvalidRecipient();

    /// @notice Reverts when the swap via Odos fails.
    error OdosSwapFailed();
}
