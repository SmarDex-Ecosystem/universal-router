// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IUsdnProtocolTypes } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { IRebalancer } from "usdn-contracts/src/interfaces/Rebalancer/IRebalancer.sol";
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
     * @param sharesOutMin The minimum amount of shares to receive
     * @param to The address that will receive the USDN tokens upon validation
     * @param validator The address that should validate the deposit (receives the security deposit back)
     * @param deadline The transaction deadline
     * @param currentPriceData The current price data
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the deposit was successful
     */
    function _usdnInitiateDeposit(
        uint256 amount,
        uint256 sharesOutMin,
        address to,
        address validator,
        uint256 deadline,
        bytes memory currentPriceData,
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
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
            amount.toUint128(), sharesOutMin, to, payable(validator), deadline, currentPriceData, previousActionsData
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
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
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
     * @param sharesAmount The amount of USDN shares to burn
     * @param amountOutMin The minimum amount of assets to receive
     * @param to The address that will receive the asset upon validation
     * @param validator The address that should validate the withdrawal (receives the security deposit back)
     * @param deadline The transaction deadline
     * @param currentPriceData The current price data
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the withdrawal was successful
     */
    function _usdnInitiateWithdrawal(
        uint256 sharesAmount,
        uint256 amountOutMin,
        address to,
        address validator,
        uint256 deadline,
        bytes memory currentPriceData,
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) internal returns (bool success_) {
        // use amount == Constants.CONTRACT_BALANCE as a flag to withdraw the entire balance of the contract
        if (sharesAmount == Constants.CONTRACT_BALANCE) {
            sharesAmount = USDN.sharesOf(address(this));
        }
        USDN.approve(address(USDN_PROTOCOL), USDN.convertToTokensRoundUp(sharesAmount));
        // we send the full ETH balance, the protocol will refund any excess
        // slither-disable-next-line arbitrary-send-eth
        success_ = USDN_PROTOCOL.initiateWithdrawal{ value: ethAmount }(
            sharesAmount.toUint152(),
            amountOutMin,
            to,
            payable(validator),
            deadline,
            currentPriceData,
            previousActionsData
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
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
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
     * @param userMaxPrice The maximum price
     * @param userMaxLeverage The maximum leverage
     * @param to The address that will receive the position
     * @param validator The address that should validate the open position (receives the security deposit back)
     * @param deadline The transaction deadline
     * @param currentPriceData The current price data
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the open position was successful
     * @return posId_ The position ID of the newly opened position
     */
    function _usdnInitiateOpenPosition(
        uint256 amount,
        uint128 desiredLiqPrice,
        uint128 userMaxPrice,
        uint256 userMaxLeverage,
        address to,
        address validator,
        uint256 deadline,
        bytes memory currentPriceData,
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) internal returns (bool success_, IUsdnProtocolTypes.PositionId memory posId_) {
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
            userMaxPrice,
            userMaxLeverage,
            to,
            payable(validator),
            deadline,
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
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
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
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
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
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
        uint256 maxValidations,
        uint256 ethAmount
    ) internal {
        // slither-disable-next-line arbitrary-send-eth
        USDN_PROTOCOL.validateActionablePendingActions{ value: ethAmount }(previousActionsData, maxValidations);
    }

    /**
     * @notice Wrap the usdn shares value into wusdn
     * @param value The usdn value in shares
     * @param receiver The wusdn receiver
     */
    function _wrapUSDNShares(uint256 value, address receiver) internal {
        if (value == Constants.CONTRACT_BALANCE) {
            value = USDN.sharesOf(address(this));
        }

        if (value > 0) {
            // due to the rounding in the USDN's `balanceOf` function,
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
        if (value == Constants.CONTRACT_BALANCE) {
            value = WUSDN.balanceOf(address(this));
        }

        if (value > 0) {
            WUSDN.unwrap(value, receiver);
        }
    }

    /**
     * @notice Performs tick liquidations of the USDN protocol
     * @param currentPriceData The current price data
     * @param ethAmount The amount of Ether to send with the transaction
     */
    function _usdnLiquidate(bytes memory currentPriceData, uint256 ethAmount) internal {
        // slither-disable-next-line arbitrary-send-eth
        USDN_PROTOCOL.liquidate{ value: ethAmount }(currentPriceData);
    }

    /**
     * @notice Performs rebalancer initiate deposit
     * @param amount The initiateDeposit amount
     * @param to The address for which the deposit will be initiated
     * @return success_ Whether the initiate deposit is successful
     * @return data_ The transaction data
     */
    function _rebalancerInitiateDeposit(uint256 amount, address to)
        internal
        returns (bool success_, bytes memory data_)
    {
        address rebalancerAddress = address(USDN_PROTOCOL.getRebalancer());

        if (rebalancerAddress == address(0)) {
            return (false, "");
        }

        IERC20Metadata asset = IRebalancer(rebalancerAddress).getAsset();

        if (amount == Constants.CONTRACT_BALANCE) {
            amount = asset.balanceOf(address(this));
        }

        if (amount == 0) {
            return (false, "");
        }

        asset.forceApprove(rebalancerAddress, amount);

        (success_, data_) = rebalancerAddress.call(
            abi.encodeWithSelector(IRebalancer.initiateDepositAssets.selector, uint80(amount), to)
        );
    }
}
