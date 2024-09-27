// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IUsdnProtocolTypes } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";

import { USER_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { SigUtils } from "./utils/SigUtils.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { PaymentLib } from "../../src/libraries/usdn/PaymentLib.sol";
import { IUsdnProtocolRouterTypes } from "../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";

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
        deal(address(wstETH), vm.addr(1), DEPOSIT_AMOUNT * 2);
        deal(address(sdex), vm.addr(1), 1e6 ether);
        deal(vm.addr(1), 1e6 ether);
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
                PaymentLib.TRANSFER_PAYMENT,
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
                PaymentLib.TRANSFER_PAYMENT,
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
    function test_ForkInitiateDepositPermitToRouter() public {
        // initial state
        uint256 wstEthBalanceBefore = wstETH.balanceOf(vm.addr(1));

        // commands building
        bytes memory commands = _getPermitCommandForRouter();

        // inputs building
        bytes[] memory inputs = new bytes[](5);
        uint256 sdexAmount = _calcSdexToBurn(DEPOSIT_AMOUNT);

        // PERMIT signatures
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(
            1, _getDigest(vm.addr(1), address(router), DEPOSIT_AMOUNT, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR())
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(
            1, _getDigest(vm.addr(1), address(router), sdexAmount, 0, type(uint256).max, sdex.DOMAIN_SEPARATOR())
        );

        // PERMIT wsteth
        inputs[0] =
            abi.encode(address(wstETH), vm.addr(1), address(router), DEPOSIT_AMOUNT, type(uint256).max, v0, r0, s0);

        // TRANSFER_FROM wsteth
        inputs[1] = abi.encode(address(wstETH), address(router), DEPOSIT_AMOUNT);

        // PERMIT sdex
        inputs[2] = abi.encode(address(sdex), vm.addr(1), address(router), sdexAmount, type(uint256).max, v1, r1, s1);

        // TRANSFER_FROM sdex
        inputs[3] = abi.encode(address(sdex), address(router), sdexAmount);

        // deposit
        inputs[4] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                PaymentLib.TRANSFER_PAYMENT,
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
        vm.prank(vm.addr(1));
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(wstETH.balanceOf(vm.addr(1)), wstEthBalanceBefore - DEPOSIT_AMOUNT, "asset balance");
    }

    /**
     * @custom:scenario Initiating a deposit command from the user balance by calling permit
     * @custom:when The user calls the permit command
     * @custom:and The user calls a deposit through the router from the user balance
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkInitiateDepositPermitToUsdnProtocol() public {
        // commands building
        bytes memory commands = _getPermitCommandForUsdnProtocol();

        // inputs building
        bytes[] memory inputs = new bytes[](3);
        uint256 sdexAmount = _calcSdexToBurn(DEPOSIT_AMOUNT);
        // PERMIT signatures
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(
            1, _getDigest(vm.addr(1), address(router), DEPOSIT_AMOUNT, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR())
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(
            1, _getDigest(vm.addr(1), address(router), sdexAmount, 0, type(uint256).max, sdex.DOMAIN_SEPARATOR())
        );

        // PERMIT wsteth
        inputs[0] =
            abi.encode(address(wstETH), vm.addr(1), address(router), DEPOSIT_AMOUNT, type(uint256).max, v0, r0, s0);

        // PERMIT sdex
        inputs[1] = abi.encode(address(sdex), vm.addr(1), address(router), sdexAmount, type(uint256).max, v1, r1, s1);

        // deposit
        inputs[2] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                PaymentLib.TRANSFER_FROM_PAYMENT,
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
        vm.prank(vm.addr(1));
        router.execute{ value: _securityDeposit }(commands, inputs);

        DepositPendingAction memory action =
            protocol.i_toDepositPendingAction(protocol.getUserPendingAction(address(this)));

        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertEq(action.amount, DEPOSIT_AMOUNT, "pending action amount");
    }

    /**
     * @custom:scenario Initiating a deposit command from the user balance by calling permit2
     * @custom:when The user calls the permit2 command
     * @custom:and The user calls a deposit through the router from the user balance
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkInitiateDepositPermit2BatchToUsdnProtocol() public {
        uint256 sdexAmount = _calcSdexToBurn(DEPOSIT_AMOUNT);

        vm.startPrank(vm.addr(1));
        wstETH.approve(address(permit2), type(uint256).max);
        sdex.approve(address(permit2), type(uint256).max);

        // commands
        bytes memory commands = abi.encodePacked(uint8(Commands.PERMIT2_PERMIT_BATCH), uint8(Commands.INITIATE_DEPOSIT));

        // inputs
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](2);
        details[0] = IAllowanceTransfer.PermitDetails(address(wstETH), uint160(DEPOSIT_AMOUNT), type(uint48).max, 0);
        details[1] = IAllowanceTransfer.PermitDetails(address(sdex), uint160(sdexAmount), type(uint48).max, 0);

        IAllowanceTransfer.PermitBatch memory permitBatch =
            IAllowanceTransfer.PermitBatch(details, address(router), type(uint256).max);

        bytes memory signature = getPermitBatchSignature(permitBatch, 1, permit2.DOMAIN_SEPARATOR());

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitBatch, signature);

        // deposit
        inputs[1] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                PaymentLib.PERMIT2_PAYMENT,
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
        router.execute{ value: _securityDeposit }(commands, inputs);
        vm.stopPrank();

        DepositPendingAction memory action =
            protocol.i_toDepositPendingAction(protocol.getUserPendingAction(address(this)));

        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertEq(action.amount, DEPOSIT_AMOUNT, "pending action amount");
    }

    receive() external payable { }

    function _getPermitCommandForRouter() internal pure returns (bytes memory) {
        bytes memory commandPermitWsteth = abi.encodePacked(uint8(Commands.PERMIT) | uint8(Commands.FLAG_ALLOW_REVERT));
        bytes memory commandTransferFromWsteth =
            abi.encodePacked(uint8(Commands.TRANSFER_FROM) | uint8(Commands.FLAG_ALLOW_REVERT));
        bytes memory commandPermitSdex = abi.encodePacked(uint8(Commands.PERMIT) | uint8(Commands.FLAG_ALLOW_REVERT));
        bytes memory commandTransferFromSdex =
            abi.encodePacked(uint8(Commands.TRANSFER_FROM) | uint8(Commands.FLAG_ALLOW_REVERT));

        bytes memory commandInitiateDeposit = abi.encodePacked(uint8(Commands.INITIATE_DEPOSIT));

        return abi.encodePacked(
            commandPermitWsteth,
            commandTransferFromWsteth,
            commandPermitSdex,
            commandTransferFromSdex,
            commandInitiateDeposit
        );
    }

    function _getPermitCommandForUsdnProtocol() internal pure returns (bytes memory) {
        bytes memory commandPermitWsteth = abi.encodePacked(uint8(Commands.PERMIT) | uint8(Commands.FLAG_ALLOW_REVERT));
        bytes memory commandPermitSdex = abi.encodePacked(uint8(Commands.PERMIT) | uint8(Commands.FLAG_ALLOW_REVERT));
        bytes memory commandInitiateDeposit = abi.encodePacked(uint8(Commands.INITIATE_DEPOSIT));

        return abi.encodePacked(commandPermitWsteth, commandPermitSdex, commandInitiateDeposit);
    }
}
