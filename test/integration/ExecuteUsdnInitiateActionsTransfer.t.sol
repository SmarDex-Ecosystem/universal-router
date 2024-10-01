// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IUsdnProtocolTypes } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { IUsdnProtocolRouterTypes } from "../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { IPaymentLibTypes } from "../../src/interfaces/usdn/IPaymentLibTypes.sol";
import { IUsdnProtocolRouterErrors } from "../../src/interfaces/usdn/IUsdnProtocolRouterErrors.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { DEPLOYER, USER_1 } from "./utils/Constants.sol";

/**
 * @custom:feature Test the USDN initiate actions through the router using transfer
 * @custom:background A deployed router
 */
contract TestForkUniversalRouterUsdnInitiateActionsTransfer is UniversalRouterBaseFixture {
    uint256 internal constant BASE_AMOUNT = 5 ether;
    uint256 internal _baseUsdnShares;
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp(DEFAULT_PARAMS);

        deal(address(wstETH), address(this), BASE_AMOUNT * 10);
        deal(address(sdex), address(this), BASE_AMOUNT * 10);
        deal(address(this), 1e6 ether);
        _baseUsdnShares = usdn.sharesOf(DEPLOYER) / 100;
        vm.prank(DEPLOYER);
        usdn.transferShares(address(this), _baseUsdnShares);
        _securityDeposit = protocol.getSecurityDepositValue();
    }

    /**
     * @custom:scenario Initiating a deposit through the router
     * @custom:given The user sent the exact amount of assets and exact amount of SDEX to the router
     * @custom:when The user initiates a deposit through the router
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkInitiateDeposit() public {
        wstETH.transfer(address(router), BASE_AMOUNT / 10);
        sdex.transfer(address(router), _calcSdexToBurn(BASE_AMOUNT / 10));

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

        IUsdnProtocolTypes.DepositPendingAction memory action =
            protocol.i_toDepositPendingAction(protocol.getUserPendingAction(address(this)));

        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertEq(action.amount, BASE_AMOUNT / 10, "pending action amount");
    }

    /**
     * @custom:scenario Initiating a deposit through the router with a "full balance" amount
     * @custom:given The user sent an amount of asset and SDEX to the router
     * @custom:when The user initiates a deposit through the router with amount `CONTRACT_BALANCE`
     * @custom:then The deposit is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `BASE_AMOUNT / 10`
     */
    function test_ForkInitiateDepositFullBalance() public {
        uint256 wstEthBalanceBefore = wstETH.balanceOf(address(this));

        wstETH.transfer(address(router), BASE_AMOUNT / 10);
        sdex.transfer(address(router), _calcSdexToBurn(BASE_AMOUNT / 10));

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

        assertEq(wstETH.balanceOf(address(this)), wstEthBalanceBefore - BASE_AMOUNT / 10, "asset balance");
    }

    /**
     * @custom:scenario Initiating an open position through the router
     * @custom:given The user sent the exact amount of wstETH to the router
     * @custom:when The user initiates an open position through the router
     * @custom:then Open position is initiated successfully
     */
    function test_ForkInitiateOpenPosition() public {
        uint256 ethBalanceBefore = address(this).balance;
        uint256 wstETHBefore = wstETH.balanceOf(address(this));

        wstETH.transfer(address(router), BASE_AMOUNT);

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_OPEN));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                IPaymentLibTypes.PaymentType.Transfer,
                BASE_AMOUNT,
                params.initialLiqPrice,
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
        assertEq(wstETH.balanceOf(address(this)), wstETHBefore - BASE_AMOUNT, "wstETH balance");
    }

    /**
     * @custom:scenario Initiating an open position through the router with a "full balance" amount
     * @custom:given The user sent the `BASE_AMOUNT` of wstETH to the router
     * @custom:when The user initiates an open position through the router with the amount `CONTRACT_BALANCE`
     * @custom:then The open position is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `BASE_AMOUNT`
     */
    function test_ForkInitiateOpenPositionFullBalance() public {
        uint256 ethBalanceBefore = address(this).balance;
        uint256 wstETHBefore = wstETH.balanceOf(address(this));

        wstETH.transfer(address(router), BASE_AMOUNT);

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_OPEN));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                IPaymentLibTypes.PaymentType.Transfer,
                Constants.CONTRACT_BALANCE,
                params.initialLiqPrice,
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
        assertEq(wstETH.balanceOf(address(this)), wstETHBefore - BASE_AMOUNT, "wstETH balance");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router
     * @custom:given The user sent the exact amount of USDN to the router
     * @custom:when The user initiates a withdrawal through the router
     * @custom:then The withdrawal is initiated successfully
     */
    function test_ForkInitiateWithdraw() public {
        uint256 ethBalanceBefore = address(this).balance;
        uint256 usdnSharesBefore = usdn.sharesOf(address(this));

        usdn.transferShares(address(router), _baseUsdnShares);

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
        assertEq(usdn.sharesOf(address(this)), usdnSharesBefore - _baseUsdnShares, "usdn shares");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router with a "full balance" amount
     * @custom:given The user sent the `_baseUsdnShares` of USDN to the router
     * @custom:when The user initiates a withdrawal through the router with amount `CONTRACT_BALANCE`
     * @custom:then The withdrawal is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `_baseUsdnShares`
     */
    function test_ForkInitiateWithdrawFullBalance() public {
        uint256 ethBalanceBefore = address(this).balance;
        uint256 usdnSharesBefore = usdn.sharesOf(address(this));

        usdn.transferShares(address(router), _baseUsdnShares);

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
        assertEq(usdn.sharesOf(address(this)), usdnSharesBefore - _baseUsdnShares, "usdn shares");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router with an invalid payment
     * @custom:when The user initiates a withdrawal through the router with an invalid payment
     * @custom:then The transactions should revert with `UsdnProtocolRouterInvalidPayment`
     */
    function testFork_RevertWhen_initiateWithdrawInvalidPayment() public {
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
