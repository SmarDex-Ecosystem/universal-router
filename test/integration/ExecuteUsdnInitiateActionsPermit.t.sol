// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { DEPLOYER, USER_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { SigUtils } from "./utils/SigUtils.sol";

import { IPaymentLibTypes } from "../../src/interfaces/usdn/IPaymentLibTypes.sol";
import { IUsdnProtocolRouterTypes } from "../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Test the USDN initiate actions through the router using permit
 * @custom:background A deployed router
 */
contract TestForkUniversalRouterUsdnInitiateActionsPermit is UniversalRouterBaseFixture, SigUtils {
    uint256 internal constant BASE_AMOUNT = 5 ether;
    uint256 internal _baseUsdnShares;
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp(DEFAULT_PARAMS);

        deal(address(wstETH), sigUser1, BASE_AMOUNT * 10);
        deal(address(sdex), sigUser1, INITIAL_SDEX_BALANCE);
        deal(sigUser1, 1e6 ether);
        _baseUsdnShares = usdn.sharesOf(DEPLOYER) / 100;
        vm.prank(DEPLOYER);
        usdn.transferShares(sigUser1, _baseUsdnShares);
        _securityDeposit = protocol.getSecurityDepositValue();
    }

    /**
     * @custom:scenario Initiating a deposit command from the router balance by calling permit and transferFrom commands
     * @custom:when The user calls the permit command
     * @custom:and The user calls the transferFrom by sending the exact amount of assets and exact amount of SDEX to the
     * router
     * @custom:and The user calls a deposit through the router from the router balance
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkInitiateDepositPermitFromRouter() public {
        uint256 wstEthBalanceBefore = wstETH.balanceOf(sigUser1);
        uint256 sdexAmount = _calcSdexToBurn(BASE_AMOUNT / 10);

        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), BASE_AMOUNT / 10, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR())
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), sdexAmount, 0, type(uint256).max, sdex.DOMAIN_SEPARATOR())
        );

        bytes memory commands = abi.encodePacked(
            uint8(Commands.PERMIT),
            uint8(Commands.TRANSFER_FROM),
            uint8(Commands.PERMIT),
            uint8(Commands.TRANSFER_FROM),
            uint8(Commands.INITIATE_DEPOSIT)
        );

        bytes[] memory inputs = new bytes[](5);
        inputs[0] =
            abi.encode(address(wstETH), sigUser1, address(router), BASE_AMOUNT / 10, type(uint256).max, v0, r0, s0);
        inputs[1] = abi.encode(address(wstETH), address(router), BASE_AMOUNT / 10);
        inputs[2] = abi.encode(address(sdex), sigUser1, address(router), sdexAmount, type(uint256).max, v1, r1, s1);
        inputs[3] = abi.encode(address(sdex), address(router), sdexAmount);
        inputs[4] = abi.encode(
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

        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(wstETH.balanceOf(sigUser1), wstEthBalanceBefore - BASE_AMOUNT / 10, "asset balance");

        IUsdnProtocolTypes.DepositPendingAction memory action =
            protocol.i_toDepositPendingAction(protocol.getUserPendingAction(address(this)));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating a deposit command from the user balance by calling permit
     * @custom:when The user calls the permit command
     * @custom:and The user calls a deposit through the router from the user balance
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkInitiateDepositPermitFromUser() public {
        uint256 sdexAmount = _calcSdexToBurn(BASE_AMOUNT / 10);

        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), BASE_AMOUNT / 10, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR())
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), sdexAmount, 0, type(uint256).max, sdex.DOMAIN_SEPARATOR())
        );

        bytes memory commands =
            abi.encodePacked(uint8(Commands.PERMIT), uint8(Commands.PERMIT), uint8(Commands.INITIATE_DEPOSIT));

        bytes[] memory inputs = new bytes[](3);

        inputs[0] =
            abi.encode(address(wstETH), sigUser1, address(router), BASE_AMOUNT / 10, type(uint256).max, v0, r0, s0);
        inputs[1] = abi.encode(address(sdex), sigUser1, address(router), sdexAmount, type(uint256).max, v1, r1, s1);
        inputs[2] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                IPaymentLibTypes.PaymentType.TransferFrom,
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

        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        DepositPendingAction memory action =
            protocol.i_toDepositPendingAction(protocol.getUserPendingAction(address(this)));

        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertEq(action.amount, BASE_AMOUNT / 10, "pending action amount");
    }

    /**
     * @custom:scenario Initiating an open position through the router with a permit transfer
     * @custom:given The user sent the exact amount of wstETH to the router by doing a permit transfer
     * @custom:when The user initiates a permit transfer to the router
     * @custom:and The user initiates a transferFrom through the router
     * @custom:and The user initiates an open position through the router
     * @custom:then The Open position is initiated successfully
     */
    function test_ForkInitiateOpenPositionWithPermitFromRouter() public {
        uint256 ethBalanceBefore = sigUser1.balance;
        uint256 wstETHBefore = wstETH.balanceOf(sigUser1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), BASE_AMOUNT, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR())
        );

        bytes memory commands =
            abi.encodePacked(uint8(Commands.PERMIT), uint8(Commands.TRANSFER_FROM), uint8(Commands.INITIATE_OPEN));

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(address(wstETH), sigUser1, address(router), BASE_AMOUNT, type(uint256).max, v, r, s);
        inputs[1] = abi.encode(address(wstETH), address(router), BASE_AMOUNT);
        inputs[2] = abi.encode(
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

        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(sigUser1.balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(wstETH.balanceOf(sigUser1), wstETHBefore - BASE_AMOUNT, "wstETH balance");

        IUsdnProtocolTypes.LongPendingAction memory action =
            protocol.i_toLongPendingAction(protocol.getUserPendingAction(address(this)));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating an open position through the router with a permit transfer
     * @custom:given A user permit signature
     * @custom:when The user initiates a permit through the router
     * @custom:and The user initiates an open position through the router
     * @custom:then The Open position is initiated successfully
     */
    function test_ForkInitiateOpenPositionWithPermitFromUser() public {
        uint256 ethBalanceBefore = sigUser1.balance;
        uint256 wstETHBefore = wstETH.balanceOf(sigUser1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), BASE_AMOUNT, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR())
        );

        bytes memory commands = abi.encodePacked(uint8(Commands.PERMIT), uint8(Commands.INITIATE_OPEN));

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(address(wstETH), sigUser1, address(router), BASE_AMOUNT, type(uint256).max, v, r, s);
        inputs[1] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                IPaymentLibTypes.PaymentType.TransferFrom,
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

        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(sigUser1.balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(wstETH.balanceOf(sigUser1), wstETHBefore - BASE_AMOUNT, "wstETH balance");

        IUsdnProtocolTypes.LongPendingAction memory action =
            protocol.i_toLongPendingAction(protocol.getUserPendingAction(address(this)));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router by doing a permit transfer
     * @custom:given The user sent the exact amount of USDN to the router through a permit transfer
     * @custom:when The user initiates a permit transfer to the router
     * @custom:and The user initiates a withdrawal through the router
     * @custom:then The withdrawal is initiated successfully
     */
    function test_ForkInitiateWithdrawWithPermitFromRouter() public {
        uint256 ethBalanceBefore = sigUser1.balance;
        uint256 usdnSharesBefore = usdn.sharesOf(sigUser1);
        uint256 usdnTokensToTransfer = usdn.convertToTokensRoundUp(_baseUsdnShares);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), usdnTokensToTransfer, 0, type(uint256).max, usdn.DOMAIN_SEPARATOR())
        );

        bytes memory commands =
            abi.encodePacked(uint8(Commands.PERMIT), uint8(Commands.TRANSFER_FROM), uint8(Commands.INITIATE_WITHDRAWAL));

        bytes[] memory inputs = new bytes[](3);
        inputs[0] =
            abi.encode(address(usdn), sigUser1, address(router), usdnTokensToTransfer, type(uint256).max, v, r, s);
        inputs[1] = abi.encode(address(usdn), address(router), usdnTokensToTransfer);
        inputs[2] = abi.encode(
            IPaymentLibTypes.PaymentType.Transfer,
            _baseUsdnShares,
            0,
            USER_1,
            address(this),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA,
            _securityDeposit
        );

        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(sigUser1.balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(usdn.sharesOf(sigUser1), usdnSharesBefore - _baseUsdnShares, "usdn shares");

        IUsdnProtocolTypes.WithdrawalPendingAction memory action =
            protocol.i_toWithdrawalPendingAction(protocol.getUserPendingAction(address(this)));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router by doing a permit transfer
     * @custom:given The user gives a USDN approval to the router using permit command
     * @custom:when The user initiates a withdrawal through the router
     * @custom:then The withdrawal is initiated successfully
     */
    function test_ForkInitiateWithdrawWithPermitFromUser() public {
        uint256 ethBalanceBefore = sigUser1.balance;
        uint256 usdnSharesBefore = usdn.sharesOf(sigUser1);
        uint256 usdnTokensToTransfer = usdn.convertToTokensRoundUp(_baseUsdnShares);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), usdnTokensToTransfer, 0, type(uint256).max, usdn.DOMAIN_SEPARATOR())
        );

        bytes memory commands = abi.encodePacked(uint8(Commands.PERMIT), uint8(Commands.INITIATE_WITHDRAWAL));

        bytes[] memory inputs = new bytes[](2);
        inputs[0] =
            abi.encode(address(usdn), sigUser1, address(router), usdnTokensToTransfer, type(uint256).max, v, r, s);
        inputs[1] = abi.encode(
            IPaymentLibTypes.PaymentType.TransferFrom,
            _baseUsdnShares,
            0,
            USER_1,
            address(this),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA,
            _securityDeposit
        );

        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(sigUser1.balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(usdn.sharesOf(sigUser1), usdnSharesBefore - _baseUsdnShares, "usdn shares");

        IUsdnProtocolTypes.WithdrawalPendingAction memory action =
            protocol.i_toWithdrawalPendingAction(protocol.getUserPendingAction(address(this)));
        assertEq(action.to, USER_1, "pending action to");
    }
}
