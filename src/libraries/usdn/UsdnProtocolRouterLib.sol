// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IUsdn } from "usdn-contracts/src/interfaces/Usdn/IUsdn.sol";
import { IWusdn } from "usdn-contracts/src/interfaces/Usdn/IWusdn.sol";
import { IUsdnProtocol } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";
import { IUsdnProtocolTypes } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { IRebalancer } from "usdn-contracts/src/interfaces/Rebalancer/IRebalancer.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";

import { IUsdnProtocolRouterTypes } from "../../interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { IPaymentLibTypes } from "../../interfaces/usdn/IPaymentLibTypes.sol";
import { IUsdnProtocolRouterErrors } from "../../interfaces/usdn/IUsdnProtocolRouterErrors.sol";
import { PaymentLib } from "./PaymentLib.sol";

/// @title Router library for UsdnProtocol
library UsdnProtocolRouterLib {
    using SafeCast for uint256;
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IUsdn;

    /**
     * @notice The payment modifier
     * @param payment The payment value
     * @param action The USDN protocol action
     */
    modifier usePayment(IPaymentLibTypes.PaymentType payment, IPaymentLibTypes.PaymentAction action) {
        if (
            payment == IPaymentLibTypes.PaymentType.None
                || (action == IPaymentLibTypes.PaymentAction.Withdrawal && payment == IPaymentLibTypes.PaymentType.Permit2)
        ) {
            revert IUsdnProtocolRouterErrors.UsdnProtocolRouterInvalidPayment();
        }

        PaymentLib.setPayment(payment);
        _;
        PaymentLib.setPayment(IPaymentLibTypes.PaymentType.None);
    }

    /**
     * @notice Initiate a deposit into the USDN protocol vault
     * @dev Check the protocol's documentation for information about how this function should be used
     * Note: the deposit can fail without reverting, in case there are some pending liquidations in the protocol
     * @param protocolAsset The USDN protocol asset
     * @param usdnProtocol The USDN protocol
     * @param data The USDN initiateDeposit router data
     * @return success_ Whether the deposit was successful
     */
    function usdnInitiateDeposit(
        IERC20Metadata protocolAsset,
        IUsdnProtocol usdnProtocol,
        IUsdnProtocolRouterTypes.InitiateDepositData memory data
    ) external usePayment(data.payment, IPaymentLibTypes.PaymentAction.Deposit) returns (bool success_) {
        // use amount == Constants.CONTRACT_BALANCE as a flag to deposit the entire balance of the contract
        if (data.amount == Constants.CONTRACT_BALANCE) {
            data.amount = protocolAsset.balanceOf(address(this));
        }
        // we send the full ETH balance, the protocol will refund any excess
        // slither-disable-next-line arbitrary-send-eth
        success_ = usdnProtocol.initiateDeposit{ value: data.ethAmount }(
            data.amount.toUint128(),
            data.sharesOutMin,
            data.to,
            payable(data.validator),
            data.deadline,
            data.currentPriceData,
            data.previousActionsData
        );
    }

    /**
     * @notice Validate a deposit into the USDN protocol vault
     * @dev Check the protocol's documentation for information about how this function should be used
     * @param usdnProtocol The USDN protocol
     * @param validator The address that should validate the deposit (receives the security deposit)
     * @param depositPriceData The price data corresponding to the validator's pending deposit action
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the deposit was successfully
     */
    function usdnValidateDeposit(
        IUsdnProtocol usdnProtocol,
        address validator,
        bytes memory depositPriceData,
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) external returns (bool success_) {
        // slither-disable-next-line arbitrary-send-eth
        success_ =
            usdnProtocol.validateDeposit{ value: ethAmount }(payable(validator), depositPriceData, previousActionsData);
    }

    /**
     * @notice Initiate a withdrawal from the USDN protocol vault
     * @dev Check the protocol's documentation for information about how this function should be used
     * Note: the withdrawal can fail without reverting, in case there are some pending liquidations in the protocol
     * @param usdn The USDN token
     * @param usdnProtocol The USDN protocol
     * @param payment The USDN protocol payment method
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
    function usdnInitiateWithdrawal(
        IUsdn usdn,
        IUsdnProtocol usdnProtocol,
        IPaymentLibTypes.PaymentType payment,
        uint256 sharesAmount,
        uint256 amountOutMin,
        address to,
        address validator,
        uint256 deadline,
        bytes memory currentPriceData,
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) external usePayment(payment, IPaymentLibTypes.PaymentAction.Withdrawal) returns (bool success_) {
        // use amount == Constants.CONTRACT_BALANCE as a flag to withdraw the entire balance of the contract
        if (sharesAmount == Constants.CONTRACT_BALANCE) {
            sharesAmount = usdn.sharesOf(address(this));
        }
        // slither-disable-next-line arbitrary-send-eth
        success_ = usdnProtocol.initiateWithdrawal{ value: ethAmount }(
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
     * @param usdnProtocol The USDN protocol
     * @param validator The address that should validate the withdrawal (receives the security deposit)
     * @param withdrawalPriceData The price data corresponding to the validator's pending deposit action
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the withdrawal was successful
     */
    function usdnValidateWithdrawal(
        IUsdnProtocol usdnProtocol,
        address validator,
        bytes memory withdrawalPriceData,
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) external returns (bool success_) {
        // slither-disable-next-line arbitrary-send-eth
        success_ = usdnProtocol.validateWithdrawal{ value: ethAmount }(
            payable(validator), withdrawalPriceData, previousActionsData
        );
    }

    /**
     * @notice Initiate an open position in the USDN protocol
     * @dev Check the protocol's documentation for information about how this function should be used
     * Note: the open position can fail without reverting, in case there are some pending liquidations in the protocol
     * @param protocolAsset The USDN protocol asset
     * @param usdnProtocol The USDN protocol
     * @param data The initiateOpenPosition router data
     * @return success_ Whether the open position was successful
     * @return posId_ The position ID of the newly opened position
     */
    function usdnInitiateOpenPosition(
        IERC20Metadata protocolAsset,
        IUsdnProtocol usdnProtocol,
        IUsdnProtocolRouterTypes.InitiateOpenPositionData memory data
    )
        external
        usePayment(data.payment, IPaymentLibTypes.PaymentAction.Open)
        returns (bool success_, IUsdnProtocolTypes.PositionId memory posId_)
    {
        // use amount == Constants.CONTRACT_BALANCE as a flag to deposit the entire balance of the contract
        if (data.amount == Constants.CONTRACT_BALANCE) {
            data.amount = protocolAsset.balanceOf(address(this));
        }
        protocolAsset.forceApprove(address(usdnProtocol), data.amount);
        // we send the full ETH balance, and the protocol will refund any excess
        // slither-disable-next-line arbitrary-send-eth
        (success_, posId_) = usdnProtocol.initiateOpenPosition{ value: data.ethAmount }(
            data.amount.toUint128(),
            data.desiredLiqPrice.toUint128(),
            data.userMaxPrice.toUint128(),
            data.userMaxLeverage,
            data.to,
            payable(data.validator),
            data.deadline,
            data.currentPriceData,
            data.previousActionsData
        );
    }

    /**
     * @notice Validate an open position in the USDN protocol
     * @dev Check the protocol's documentation for information about how this function should be used
     * @param usdnProtocol The USDN protocol
     * @param validator The address that should validate the open position (receives the security deposit)
     * @param openPositionPriceData The price data corresponding to the validator's pending open position action
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the open position was successful
     */
    function usdnValidateOpenPosition(
        IUsdnProtocol usdnProtocol,
        address validator,
        bytes memory openPositionPriceData,
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) external returns (bool success_) {
        // slither-disable-next-line arbitrary-send-eth
        success_ = usdnProtocol.validateOpenPosition{ value: ethAmount }(
            payable(validator), openPositionPriceData, previousActionsData
        );
    }

    /**
     * @notice Validate a close position in the USDN protocol
     * @dev Check the protocol's documentation for information about how this function should be used
     * @param usdnProtocol The USDN protocol
     * @param validator The address of the validator
     * @param closePriceData The price data corresponding to the position's close
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     * @return success_ Whether the close position was successful
     */
    function usdnValidateClosePosition(
        IUsdnProtocol usdnProtocol,
        address validator,
        bytes memory closePriceData,
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
        uint256 ethAmount
    ) external returns (bool success_) {
        // slither-disable-next-line arbitrary-send-eth
        success_ = usdnProtocol.validateClosePosition{ value: ethAmount }(
            payable(validator), closePriceData, previousActionsData
        );
    }

    /**
     * @notice Validate actionable pending action in the USDN protocol
     * @dev Check the protocol's documentation for information about how this function should be used
     * @param usdnProtocol The USDN protocol
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param maxValidations The maximum number of pending actions to validate
     * @param ethAmount The amount of Ether to send with the transaction
     */
    function usdnValidateActionablePendingActions(
        IUsdnProtocol usdnProtocol,
        IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
        uint256 maxValidations,
        uint256 ethAmount
    ) external {
        // slither-disable-next-line arbitrary-send-eth
        usdnProtocol.validateActionablePendingActions{ value: ethAmount }(previousActionsData, maxValidations);
    }

    /**
     * @notice Wrap the usdn shares value into wusdn
     * @param usdn The USDN token
     * @param wusdn The WUSDN token
     * @param value The USDN value in shares
     * @param receiver The WUSDN receiver
     */
    function wrapUSDNShares(IUsdn usdn, IWusdn wusdn, uint256 value, address receiver) external {
        if (value == Constants.CONTRACT_BALANCE) {
            value = usdn.sharesOf(address(this));
        }

        if (value > 0) {
            // due to the rounding in the USDN's `balanceOf` function,
            // we approve max uint256 then reset to 0
            usdn.forceApprove(address(wusdn), type(uint256).max);
            wusdn.wrapShares(value, receiver);
            usdn.approve(address(wusdn), 0);
        }
    }

    /**
     * @notice Unwrap the wusdn value into usdn
     * @param wusdn The WUSDN token
     * @param value The WUSDN value
     * @param receiver The USDN receiver
     */
    function unwrapUSDN(IWusdn wusdn, uint256 value, address receiver) external {
        if (value == Constants.CONTRACT_BALANCE) {
            value = wusdn.balanceOf(address(this));
        }

        if (value > 0) {
            wusdn.unwrap(value, receiver);
        }
    }

    /**
     * @notice Performs tick liquidations of the USDN protocol
     * @param usdnProtocol The USDN protocol
     * @param currentPriceData The current price data
     * @param ethAmount The amount of Ether to send with the transaction
     */
    function usdnLiquidate(IUsdnProtocol usdnProtocol, bytes memory currentPriceData, uint256 ethAmount) external {
        // slither-disable-next-line arbitrary-send-eth
        usdnProtocol.liquidate{ value: ethAmount }(currentPriceData);
    }

    /**
     * @notice Performs rebalancer initiate deposit
     * @param usdnProtocol The USDN protocol
     * @param amount The initiateDeposit amount
     * @param to The address for which the deposit will be initiated
     * @return success_ Whether the initiate deposit is successful
     * @return data_ The transaction data
     */
    function rebalancerInitiateDeposit(IUsdnProtocol usdnProtocol, uint256 amount, address to)
        external
        returns (bool success_, bytes memory data_)
    {
        address rebalancerAddress = address(usdnProtocol.getRebalancer());

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
            abi.encodeWithSelector(IRebalancer.initiateDepositAssets.selector, amount.toUint88(), to)
        );
    }

    /**
     * @notice Callback function to be called during initiate functions to transfer asset tokens
     * @dev The implementation must ensure that the `msg.sender` is the protocol contract
     * @param usdnProtocol The USDN protocol contract address
     * @param lockedBy The router lockedBy address
     * @param permit2 The permit2 contract
     * @param token The token to transfer
     * @param amount The amount to transfer
     * @param to The address of the recipient
     */
    function transferCallback(
        address usdnProtocol,
        address lockedBy,
        IAllowanceTransfer permit2,
        IERC20Metadata token,
        uint256 amount,
        address to
    ) external {
        if (msg.sender != usdnProtocol) {
            revert IUsdnProtocolRouterErrors.UsdnProtocolRouterInvalidSender();
        }

        IPaymentLibTypes.PaymentType payment = PaymentLib.getPayment();

        if (payment == IPaymentLibTypes.PaymentType.Transfer) {
            token.safeTransfer(to, amount);
        } else if (payment == IPaymentLibTypes.PaymentType.TransferFrom) {
            // slither-disable-next-line arbitrary-send-erc20
            token.safeTransferFrom(lockedBy, to, amount);
        } else if (payment == IPaymentLibTypes.PaymentType.Permit2) {
            permit2.transferFrom(lockedBy, to, amount.toUint160(), address(token));
        } else {
            // sanity check: this should never happen
            revert IUsdnProtocolRouterErrors.UsdnProtocolRouterInvalidPayment();
        }
    }

    /**
     * @notice Callback function to be called during `initiateWithdrawal` to transfer USDN shares to the protocol
     * @dev The implementation must ensure that the `msg.sender` is the protocol contract
     * @param usdnProtocol The USDN protocol contract address
     * @param usdn The USDN contract address
     * @param lockedBy The router lockedBy address
     * @param shares The amount of USDN shares to transfer to the `msg.sender`
     */
    function usdnTransferCallback(address usdnProtocol, IUsdn usdn, address lockedBy, uint256 shares) external {
        if (msg.sender != usdnProtocol) {
            revert IUsdnProtocolRouterErrors.UsdnProtocolRouterInvalidSender();
        }

        IPaymentLibTypes.PaymentType payment = PaymentLib.getPayment();

        if (payment == IPaymentLibTypes.PaymentType.Transfer) {
            usdn.transferShares(msg.sender, shares);
        } else if (payment == IPaymentLibTypes.PaymentType.TransferFrom) {
            usdn.transferSharesFrom(lockedBy, msg.sender, shares);
        } else {
            // sanity check: this should never happen
            revert IUsdnProtocolRouterErrors.UsdnProtocolRouterInvalidPayment();
        }
    }
}
