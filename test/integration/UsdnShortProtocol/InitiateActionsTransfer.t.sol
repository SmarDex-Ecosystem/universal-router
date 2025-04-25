// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { UsdnProtocolUtilsLibrary as Utils } from
    "@smardex-usdn-contracts-1/src/UsdnProtocol/libraries/UsdnProtocolUtilsLibrary.sol";

import { Commands } from "../../../src/libraries/Commands.sol";
import { IUsdnProtocolRouterTypes } from "../../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { IPaymentLibTypes } from "../../../src/interfaces/usdn/IPaymentLibTypes.sol";
import { IUsdnProtocolRouterErrors } from "../../../src/interfaces/usdn/IUsdnProtocolRouterErrors.sol";

import { UniversalRouterUsdnShortProtocolBaseFixture } from "./utils/Fixtures.sol";
import { USER_1 } from "../utils/Constants.sol";

/**
 * @custom:feature Test the usdn initiate actions through the router using transfer
 * @custom:background A deployed router
 */
contract TestForkUniversalRouterUsdnShortProtocolInitiateActionsTransfer is
    UniversalRouterUsdnShortProtocolBaseFixture
{
    uint256 internal constant BASE_AMOUNT = 5 ether;
    uint256 internal _baseUsdnShortShares;
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp();

        _baseUsdnShortShares = usdn.sharesOf(usdnShortDeployer) / 100;

        vm.prank(usdnShortDeployer);
        usdn.transferShares(address(this), _baseUsdnShortShares);
        _securityDeposit = protocol.getSecurityDepositValue();
    }

    /**
     * @custom:scenario Initiating a deposit through the router
     * @custom:given The user sent the exact amount of assets and exact amount of SDEX to the router
     * @custom:when The user initiates a deposit through the router
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkUsdnShortInitiateDeposit() public {
        asset.transfer(address(router), BASE_AMOUNT / 10);
        sdex.transfer(address(router), Utils._calcSdexToBurn(BASE_AMOUNT / 10, protocol.getSdexBurnOnDepositRatio()));

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_DEPOSIT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                IPaymentLibTypes.PaymentType.Transfer,
                BASE_AMOUNT / 10,
                0,
                USER_1,
                address(this),
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                _securityDeposit
            )
        );

        router.execute{ value: _securityDeposit }(commands, inputs);

        IUsdnProtocolTypes.DepositPendingAction memory depositAction =
            toDepositPendingAction(protocol.getUserPendingAction(address(this)));

        assertEq(depositAction.to, USER_1, "pending action to");
        assertEq(depositAction.validator, address(this), "pending action validator");
        assertEq(depositAction.amount, BASE_AMOUNT / 10, "pending action amount");
    }

    /**
     * @custom:scenario Initiating a deposit through the router with a "full balance" amount
     * @custom:given The user sent an amount of asset and SDEX to the router
     * @custom:when The user initiates a deposit through the router with amount `CONTRACT_BALANCE`
     * @custom:then The deposit is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `BASE_AMOUNT / 10`
     */
    function test_ForkUsdnShortInitiateDepositFullBalance() public {
        uint256 wstEthBalanceBefore = asset.balanceOf(address(this));
        asset.transfer(address(router), BASE_AMOUNT / 10);
        sdex.transfer(address(router), Utils._calcSdexToBurn(BASE_AMOUNT / 10, protocol.getSdexBurnOnDepositRatio()));

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_DEPOSIT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                IPaymentLibTypes.PaymentType.Transfer,
                Constants.CONTRACT_BALANCE,
                0,
                USER_1,
                address(this),
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                _securityDeposit
            )
        );

        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(asset.balanceOf(address(this)), wstEthBalanceBefore - BASE_AMOUNT / 10, "asset balance");

        IUsdnProtocolTypes.PendingAction memory action = protocol.getUserPendingAction(address(this));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating an open position through the router
     * @custom:given The user sent the exact amount of asset to the router
     * @custom:when The user initiates an open position through the router
     * @custom:then Open position is initiated successfully
     */
    function test_ForkUsdnShortInitiateOpenPosition() public {
        uint256 ethBalanceBefore = address(this).balance;
        uint256 assetBalanceBefore = asset.balanceOf(address(this));
        asset.transfer(address(router), minLongPosition);
        uint256 assetBalanceRouter = asset.balanceOf(address(router));

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_OPEN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                IPaymentLibTypes.PaymentType.Transfer,
                minLongPosition,
                initialPrice / 2,
                type(uint128).max,
                maxLeverage,
                USER_1,
                address(this),
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                _securityDeposit
            )
        );

        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(address(this).balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(asset.balanceOf(address(this)), assetBalanceBefore - assetBalanceRouter, "asset balance");

        IUsdnProtocolTypes.PendingAction memory action = protocol.getUserPendingAction(address(this));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating an open position through the router with a "full balance" amount
     * @custom:given The user sent the `BASE_AMOUNT` of asset to the router
     * @custom:when The user initiates an open position through the router with the amount `CONTRACT_BALANCE`
     * @custom:then The open position is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `BASE_AMOUNT`
     */
    function test_ForkUsdnShortInitiateOpenPositionFullBalance() public {
        uint256 ethBalanceBefore = address(this).balance;
        uint256 assetBalanceBefore = asset.balanceOf(address(this));
        asset.transfer(address(router), minLongPosition);
        uint256 assetBalanceRouter = asset.balanceOf(address(router));

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_OPEN));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                IPaymentLibTypes.PaymentType.Transfer,
                Constants.CONTRACT_BALANCE,
                initialPrice / 2,
                type(uint128).max,
                maxLeverage,
                USER_1,
                address(this),
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                _securityDeposit
            )
        );

        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(address(this).balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(asset.balanceOf(address(this)), assetBalanceBefore - assetBalanceRouter, "asset balance");

        IUsdnProtocolTypes.PendingAction memory action = protocol.getUserPendingAction(address(this));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router
     * @custom:given The user sent the exact amount of usdn to the router
     * @custom:when The user initiates a withdrawal through the router
     * @custom:then The withdrawal is initiated successfully
     */
    function test_ForkUsdnShortInitiateWithdraw() public {
        uint256 ethBalanceBefore = address(this).balance;
        uint256 usdnSharesBefore = usdn.sharesOf(address(this));
        usdn.transferShares(address(router), _baseUsdnShortShares);

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_WITHDRAWAL));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IPaymentLibTypes.PaymentType.Transfer,
            usdn.sharesOf(address(router)),
            0,
            USER_1,
            address(this),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA,
            _securityDeposit
        );

        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(address(this).balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(usdn.sharesOf(address(this)), usdnSharesBefore - _baseUsdnShortShares, "usdn shares");

        IUsdnProtocolTypes.PendingAction memory action = protocol.getUserPendingAction(address(this));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router with a "full balance" amount
     * @custom:given The user sent the `_baseUsdnShortShares` of usdn to the router
     * @custom:when The user initiates a withdrawal through the router with amount `CONTRACT_BALANCE`
     * @custom:then The withdrawal is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `_baseUsdnShortShares`
     */
    function test_ForkUsdnShortInitiateWithdrawFullBalance() public {
        uint256 ethBalanceBefore = address(this).balance;
        usdn.transfer(address(router), _baseUsdnShortShares);

        emit log_named_address("usdn", address(usdn));
        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_WITHDRAWAL));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IPaymentLibTypes.PaymentType.Transfer,
            Constants.CONTRACT_BALANCE,
            0,
            USER_1,
            address(this),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA,
            _securityDeposit
        );

        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(address(this).balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(usdn.sharesOf(address(this)), 0, "usdn shares");

        IUsdnProtocolTypes.PendingAction memory action = protocol.getUserPendingAction(address(this));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router with an invalid payment
     * @custom:when The user initiates a withdrawal through the router with an invalid payment
     * @custom:then The transactions should revert with `UsdnProtocolRouterInvalidPayment`
     */
    function test_RevertWhen_ForkUsdnShortInitiateWithdrawInvalidPayment() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_WITHDRAWAL));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IPaymentLibTypes.PaymentType.None,
            0,
            0,
            address(0),
            address(0),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA,
            0
        );

        vm.expectRevert(IUsdnProtocolRouterErrors.UsdnProtocolRouterInvalidPayment.selector);
        router.execute(commands, inputs);

        inputs[0] = abi.encode(
            IPaymentLibTypes.PaymentType.Permit2,
            0,
            0,
            address(0),
            address(0),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA,
            0
        );

        vm.expectRevert(IUsdnProtocolRouterErrors.UsdnProtocolRouterInvalidPayment.selector);
        router.execute(commands, inputs);
    }
}
