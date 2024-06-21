// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PreviousActionsData } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { PositionId } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { Permit2TokenBitfield } from "usdn-contracts/src/libraries/Permit2TokenBitfield.sol";
import { Permit2Payments } from "@uniswap/universal-router/contracts/modules/Permit2Payments.sol";
import { IUsdn } from "usdn-contracts/src/interfaces/Usdn/IUsdn.sol";

import { UsdnProtocolImmutables } from "./UsdnProtocolImmutables.sol";

abstract contract UsdnProtocolRouter is UsdnProtocolImmutables, Permit2Payments {
    using SafeCast for uint256;
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IUsdn;

    /**
     * @notice Initiate a deposit into the USDN protocol vault
     * @dev Check the protocol's documentation for information about how this function should be used
     * Note: the deposit can fail without reverting, in case there are some pending liquidations in the protocol
     * @param amount The amount of asset to deposit into the vault
     * @param to The address that will receive the USDN tokens upon validation
     * @param validator The address that should validate the deposit (receives the security deposit back)
     * @param permit2TokenBitfield The bitfield indicating which tokens should be used with permit2
     * @param currentPriceData The current price data
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the deposit was successful
     */
    function _usdnInitiateDeposit(
        uint256 amount,
        address to,
        address validator,
        Permit2TokenBitfield.Bitfield permit2TokenBitfield,
        bytes memory currentPriceData,
        PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) internal returns (bool success_) {
        // use amount == Constants.CONTRACT_BALANCE as a flag to deposit the entire balance of the contract
        if (amount == Constants.CONTRACT_BALANCE) {
            amount = PROTOCOL_ASSET.balanceOf(address(this));
        }
        PROTOCOL_ASSET.forceApprove(address(USDN_PROTOCOL), amount);
        SDEX.approve(address(USDN_PROTOCOL), type(uint256).max);
        // we send the full ETH balance, the protocol will refund any excess
        // slither-disable-next-line arbitrary-send-eth
        success_ = USDN_PROTOCOL.initiateDeposit{ value: ethAmount }(
            amount.toUint128(), to, payable(validator), permit2TokenBitfield, currentPriceData, previousActionsData
        );
        SDEX.approve(address(USDN_PROTOCOL), 0);
    }

    /**
     * @notice Validate a deposit into the USDN protocol vault
     * @dev Check the protocol's documentation for information about how this function should be used
     * @param validator The address that should validate the deposit (receives the security deposit)
     * @param depositPriceData The price data corresponding to the validator's pending deposit action
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the deposit was successfully
     */
    function _usdnValidateDeposit(
        address validator,
        bytes memory depositPriceData,
        PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) internal returns (bool success_) {
        // slither-disable-next-line arbitrary-send-eth
        success_ =
            USDN_PROTOCOL.validateDeposit{ value: ethAmount }(payable(validator), depositPriceData, previousActionsData);
    }

    /**
     * @notice Initiate a withdrawal from the USDN protocol vault
     * @dev Check the protocol's documentation for information about how this function should be used
     * Note: the withdrawal can fail without reverting, in case there are some pending liquidations in the protocol
     * @param amount The amount of USDN shares to burn
     * @param to The address that will receive the asset upon validation
     * @param validator The address that should validate the withdrawal (receives the security deposit back)
     * @param currentPriceData The current price data
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the withdrawal was successful
     */
    function _usdnInitiateWithdrawal(
        uint256 amount,
        address to,
        address validator,
        bytes memory currentPriceData,
        PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) internal returns (bool success_) {
        // use amount == Constants.CONTRACT_BALANCE as a flag to withdraw the entire balance of the contract
        if (amount == Constants.CONTRACT_BALANCE) {
            amount = USDN.sharesOf(address(this));
        }
        USDN.approve(address(USDN_PROTOCOL), USDN.convertToTokensRoundUp(amount));
        // we send the full ETH balance, the protocol will refund any excess
        // slither-disable-next-line arbitrary-send-eth
        success_ = USDN_PROTOCOL.initiateWithdrawal{ value: ethAmount }(
            amount.toUint152(), to, payable(validator), currentPriceData, previousActionsData
        );
    }

    /**
     * @notice Validate a withdrawal into the USDN protocol vault
     * @dev Check the protocol's documentation for information about how this function should be used
     * Note: the withdrawal can fail without reverting, in case there are some pending liquidations in the protocol
     * @param validator The address that should validate the withdrawal (receives the security deposit)
     * @param withdrawalPriceData The price data corresponding to the validator's pending deposit action
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the withdrawal was successful
     */
    function _usdnValidateWithdrawal(
        address validator,
        bytes memory withdrawalPriceData,
        PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) internal returns (bool success_) {
        // slither-disable-next-line arbitrary-send-eth
        success_ = USDN_PROTOCOL.validateWithdrawal{ value: ethAmount }(
            payable(validator), withdrawalPriceData, previousActionsData
        );
    }

    /**
     * @notice Initiate an open position in the USDN protocol
     * @dev Check the protocol's documentation for information about how this function should be used
     * Note: the open position can fail without reverting, in case there are some pending liquidations in the protocol
     * @param amount The amount of assets used to open the position
     * @param desiredLiqPrice The desired liquidation price for the position
     * @param to The address that will receive the position
     * @param validator The address that should validate the open position (receives the security deposit back)
     * @param permit2TokenBitfield The bitfield indicating which tokens should be used with permit2
     * @param currentPriceData The current price data
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the open position was successful
     * @return posId_ The position ID of the newly opened position
     */
    function _usdnInitiateOpenPosition(
        uint256 amount,
        uint128 desiredLiqPrice,
        address to,
        address validator,
        Permit2TokenBitfield.Bitfield permit2TokenBitfield,
        bytes memory currentPriceData,
        PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) internal returns (bool success_, PositionId memory posId_) {
        // use amount == Constants.CONTRACT_BALANCE as a flag to deposit the entire balance of the contract
        if (amount == Constants.CONTRACT_BALANCE) {
            amount = PROTOCOL_ASSET.balanceOf(address(this));
        }
        PROTOCOL_ASSET.forceApprove(address(USDN_PROTOCOL), amount);
        // we send the full ETH balance, and the protocol will refund any excess
        // slither-disable-next-line arbitrary-send-eth
        (success_, posId_) = USDN_PROTOCOL.initiateOpenPosition{ value: ethAmount }(
            amount.toUint128(),
            desiredLiqPrice,
            to,
            payable(validator),
            permit2TokenBitfield,
            currentPriceData,
            previousActionsData
        );
    }

    /**
     * @notice Validate an open position in the USDN protocol
     * @dev Check the protocol's documentation for information about how this function should be used
     * @param validator The address that should validate the open position (receives the security deposit)
     * @param openPositionPriceData The price data corresponding to the validator's pending open position action
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the open position was successful
     */
    function _usdnValidateOpenPosition(
        address validator,
        bytes memory openPositionPriceData,
        PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) internal returns (bool success_) {
        // slither-disable-next-line arbitrary-send-eth
        success_ = USDN_PROTOCOL.validateOpenPosition{ value: ethAmount }(
            payable(validator), openPositionPriceData, previousActionsData
        );
    }

    /**
     * @notice Validate a close position in the USDN protocol
     * @dev Check the protocol's documentation for information about how this function should be used
     * @param validator The address of the validator
     * @param closePriceData The price data corresponding to the position's close
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the close position was successful
     */
    function _usdnValidateClosePosition(
        address validator,
        bytes memory closePriceData,
        PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) internal returns (bool success_) {
        // slither-disable-next-line arbitrary-send-eth
        success_ = USDN_PROTOCOL.validateClosePosition{ value: ethAmount }(
            payable(validator), closePriceData, previousActionsData
        );
    }

    /**
     * @notice Validate actionable pending action in the USDN protocol
     * @dev Check the protocol's documentation for information about how this function should be used
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param maxValidations The maximum number of pending actions to validate
     * @param ethAmount The amount of Ether to send with the transaction
     */
    function _usdnValidateActionablePendingActions(
        PreviousActionsData memory previousActionsData,
        uint256 maxValidations,
        uint256 ethAmount
    ) internal {
        // slither-disable-next-line arbitrary-send-eth
        USDN_PROTOCOL.validateActionablePendingActions{ value: ethAmount }(previousActionsData, maxValidations);
    }

    /**
     * @notice Wrap the usdn shares value into wusdn
     * @param value The usdn value
     * @param receiver The wusdn receiver
     */
    function _wrapUSDNShares(uint256 value, address receiver) internal {
        uint256 sharesBalance = USDN.sharesOf(address(this));

        if (value == Constants.CONTRACT_BALANCE) {
            value = sharesBalance;
        } else if (value > sharesBalance) {
            revert InsufficientToken();
        }

        if (value > 0) {
            // To avoid missing approval dust
            // due of the usdn balanceOf rounding,
            // we approve max uint256 then reset to 0
            USDN.forceApprove(address(WUSDN), type(uint256).max);
            WUSDN.wrapShares(value, receiver);
            USDN.approve(address(WUSDN), 0);
        }
    }

    /**
     * @notice Unwrap the wusdn value into usdn
     * @param value The wusdn value
     * @param receiver The usdn receiver
     */
    function _unwrapUSDN(uint256 value, address receiver) internal {
        uint256 balance = WUSDN.balanceOf(address(this));

        if (value == Constants.CONTRACT_BALANCE) {
            value = balance;
        } else if (value > balance) {
            revert InsufficientToken();
        }

        if (value > 0) {
            WUSDN.unwrap(value, receiver);
        }
    }
}
