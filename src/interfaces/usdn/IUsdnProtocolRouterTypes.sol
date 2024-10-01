// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import { IUsdnProtocolTypes } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { IPaymentLibTypes } from "../../interfaces/usdn/IPaymentLibTypes.sol";

interface IUsdnProtocolRouterTypes {
    /**
     * @notice The router usdnProtocol initiate open position data struct
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
        IPaymentLibTypes.PaymentTypes payment;
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
     * @notice The router usdnProtocol deposit data struct
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
        IPaymentLibTypes.PaymentTypes payment;
        uint256 amount;
        uint256 sharesOutMin;
        address to;
        address validator;
        uint256 deadline;
        bytes currentPriceData;
        IUsdnProtocolTypes.PreviousActionsData previousActionsData;
        uint256 ethAmount;
    }
}
