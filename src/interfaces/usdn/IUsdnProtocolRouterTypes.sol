// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IUsdnProtocolTypes } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { IPaymentLibTypes } from "../../interfaces/usdn/IPaymentLibTypes.sol";

interface IUsdnProtocolRouterTypes {
    /**
     * @notice The router USDN protocol initiate open position data struct
     * @param payment The USDN protocol payment method
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
     */
    struct InitiateOpenPositionData {
        IPaymentLibTypes.PaymentType payment;
        uint256 amount;
        uint256 desiredLiqPrice;
        uint256 userMaxPrice;
        uint256 userMaxLeverage;
        address to;
        address validator;
        uint256 deadline;
        bytes currentPriceData;
        IUsdnProtocolTypes.PreviousActionsData previousActionsData;
        uint256 ethAmount;
    }

    /**
     * @notice The router USDN protocol deposit data struct
     * @param payment The USDN protocol payment method
     * @param amount The amount of asset to deposit into the vault
     * @param sharesOutMin The minimum amount of shares to receive
     * @param to The address that will receive the USDN tokens upon validation
     * @param validator The address that should validate the deposit (receives the security deposit back)
     * @param deadline The transaction deadline
     * @param currentPriceData The current price data
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param ethAmount The amount of Ether to send with the transaction
     */
    struct InitiateDepositData {
        IPaymentLibTypes.PaymentType payment;
        uint256 amount;
        uint256 sharesOutMin;
        address to;
        address validator;
        uint256 deadline;
        bytes currentPriceData;
        IUsdnProtocolTypes.PreviousActionsData previousActionsData;
        uint256 ethAmount;
    }

    /**
     * @notice The router usdnProtocol initiate close position data struct
     * @param posId The unique identifier of the position to close
     * @param amountToClose The amount of collateral to remove from the position's amount
     * @param userMinPrice The minimum price at which the position can be closed (with _priceFeedDecimals). Note that
     * @param to The address that will receive the assets
     * @param validator The address that will validate the close action
     * @param deadline The deadline of the close position to be initiated
     * @param currentPriceData The current price data
     * @param previousActionsData The data needed to validate actionable pending actions
     * @param delegationSignature The EIP712 initiateClosePosition delegation signature
     * @param ethAmount The amount of Ether to send with the transaction
     */
    struct InitiateClosePositionData {
        IUsdnProtocolTypes.PositionId posId;
        uint128 amountToClose;
        uint256 userMinPrice;
        address to;
        address validator;
        uint256 deadline;
        bytes currentPriceData;
        IUsdnProtocolTypes.PreviousActionsData previousActionsData;
        bytes delegationSignature;
        uint256 ethAmount;
    }
}
