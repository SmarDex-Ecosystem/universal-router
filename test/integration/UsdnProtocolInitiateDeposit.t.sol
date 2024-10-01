// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IUsdnProtocolTypes } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { USER_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { SigUtils } from "./utils/SigUtils.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { IUsdnProtocolRouterTypes } from "../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { IPaymentLibTypes } from "../../src/interfaces/usdn/IPaymentLibTypes.sol";

/**
 * @custom:feature Initiating a deposit through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterInitiateDeposit is UniversalRouterBaseFixture, SigUtils {
    uint256 constant DEPOSIT_AMOUNT = 0.1 ether;
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp(DEFAULT_PARAMS);
        deal(address(wstETH), address(this), DEPOSIT_AMOUNT * 2);
        deal(address(sdex), address(this), 1e6 ether);
        deal(address(wstETH), sigUser1, DEPOSIT_AMOUNT * 2);
        deal(address(sdex), sigUser1, 1e6 ether);
        deal(sigUser1, 1e6 ether);
        _securityDeposit = protocol.getSecurityDepositValue();
    }

    /**
     * @custom:scenario Initiating a deposit through the router
     * @custom:given The user sent the exact amount of assets and exact amount of SDEX to the router
     * @custom:when The user initiates a deposit through the router
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkInitiateDeposit() public {
        wstETH.transfer(address(router), DEPOSIT_AMOUNT);
        sdex.transfer(address(router), _calcSdexToBurn(DEPOSIT_AMOUNT));

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_DEPOSIT));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                IPaymentLibTypes.PaymentTypes.Transfer,
                DEPOSIT_AMOUNT,
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
        assertEq(action.amount, DEPOSIT_AMOUNT, "pending action amount");
    }

    /**
     * @custom:scenario Initiating a deposit through the router with a "full balance" amount
     * @custom:given The user sent the `DEPOSIT_AMOUNT` of wstETH to the router
     * @custom:when The user initiates a deposit through the router with amount `CONTRACT_BALANCE`
     * @custom:then The deposit is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `DEPOSIT_AMOUNT`
     */
    function test_ForkInitiateDepositFullBalance() public {
        uint256 wstEthBalanceBefore = wstETH.balanceOf(address(this));

        wstETH.transfer(address(router), DEPOSIT_AMOUNT);
        sdex.transfer(address(router), _calcSdexToBurn(DEPOSIT_AMOUNT));

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_DEPOSIT));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                IPaymentLibTypes.PaymentTypes.Transfer,
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

        assertEq(wstETH.balanceOf(address(this)), wstEthBalanceBefore - DEPOSIT_AMOUNT, "asset balance");
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
        // initial state
        uint256 wstEthBalanceBefore = wstETH.balanceOf(sigUser1);

        uint256 sdexAmount = _calcSdexToBurn(DEPOSIT_AMOUNT);

        // commands building
        bytes memory commands = abi.encodePacked(
            uint8(Commands.PERMIT),
            uint8(Commands.TRANSFER_FROM),
            uint8(Commands.PERMIT),
            uint8(Commands.TRANSFER_FROM),
            uint8(Commands.INITIATE_DEPOSIT)
        );

        // inputs building
        bytes[] memory inputs = new bytes[](5);

        // PERMIT signatures
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), DEPOSIT_AMOUNT, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR())
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), sdexAmount, 0, type(uint256).max, sdex.DOMAIN_SEPARATOR())
        );

        // PERMIT wsteth
        inputs[0] =
            abi.encode(address(wstETH), sigUser1, address(router), DEPOSIT_AMOUNT, type(uint256).max, v0, r0, s0);

        // TRANSFER_FROM wsteth
        inputs[1] = abi.encode(address(wstETH), address(router), DEPOSIT_AMOUNT);

        // PERMIT sdex
        inputs[2] = abi.encode(address(sdex), sigUser1, address(router), sdexAmount, type(uint256).max, v1, r1, s1);

        // TRANSFER_FROM sdex
        inputs[3] = abi.encode(address(sdex), address(router), sdexAmount);

        // deposit
        inputs[4] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                IPaymentLibTypes.PaymentTypes.Transfer,
                DEPOSIT_AMOUNT,
                0,
                USER_1,
                address(this),
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                _securityDeposit
            )
        );

        // execute
        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(wstETH.balanceOf(sigUser1), wstEthBalanceBefore - DEPOSIT_AMOUNT, "asset balance");
    }

    /**
     * @custom:scenario Initiating a deposit command from the user balance by calling permit
     * @custom:when The user calls the permit command
     * @custom:and The user calls a deposit through the router from the user balance
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkInitiateDepositPermitFromUser() public {
        uint256 sdexAmount = _calcSdexToBurn(DEPOSIT_AMOUNT);

        bytes memory commands =
            abi.encodePacked(uint8(Commands.PERMIT), uint8(Commands.PERMIT), uint8(Commands.INITIATE_DEPOSIT));

        bytes[] memory inputs = new bytes[](3);

        // PERMIT signatures
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), DEPOSIT_AMOUNT, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR())
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), sdexAmount, 0, type(uint256).max, sdex.DOMAIN_SEPARATOR())
        );

        // PERMIT wsteth
        inputs[0] =
            abi.encode(address(wstETH), sigUser1, address(router), DEPOSIT_AMOUNT, type(uint256).max, v0, r0, s0);

        // PERMIT sdex
        inputs[1] = abi.encode(address(sdex), sigUser1, address(router), sdexAmount, type(uint256).max, v1, r1, s1);

        // deposit
        inputs[2] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                IPaymentLibTypes.PaymentTypes.TransferFrom,
                DEPOSIT_AMOUNT,
                0,
                USER_1,
                address(this),
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                _securityDeposit
            )
        );

        // execute
        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        DepositPendingAction memory action =
            protocol.i_toDepositPendingAction(protocol.getUserPendingAction(address(this)));

        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertEq(action.amount, DEPOSIT_AMOUNT, "pending action amount");
    }

    receive() external payable { }
}
