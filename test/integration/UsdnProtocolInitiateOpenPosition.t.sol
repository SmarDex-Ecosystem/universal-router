// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { USER_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { SigUtils } from "./utils/SigUtils.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { IUsdnProtocolRouterTypes } from "../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { LockAndMap } from "../../src/modules/usdn/LockAndMap.sol";

/**
 * @custom:feature Initiating an open position through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterInitiateOpenPosition is UniversalRouterBaseFixture, SigUtils {
    uint256 constant OPEN_POSITION_AMOUNT = 2 ether;
    uint256 constant DESIRED_LIQUIDATION = 2500 ether;
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp(DEFAULT_PARAMS);
        deal(address(wstETH), address(this), OPEN_POSITION_AMOUNT * 2);
        deal(address(wstETH), vm.addr(1), OPEN_POSITION_AMOUNT * 2);
        deal(vm.addr(1), 1e6 ether);
        _securityDeposit = protocol.getSecurityDepositValue();
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

        wstETH.transfer(address(router), OPEN_POSITION_AMOUNT);

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_OPEN));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                OPEN_POSITION_AMOUNT,
                DESIRED_LIQUIDATION,
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
        assertEq(wstETH.balanceOf(address(this)), wstETHBefore - OPEN_POSITION_AMOUNT, "wstETH balance");
    }

    /**
     * @custom:scenario Initiating an open position through the router with a "full balance" amount
     * @custom:given The user sent the `OPEN_POSITION_AMOUNT` of wstETH to the router
     * @custom:when The user initiates an open position through the router with the amount `CONTRACT_BALANCE`
     * @custom:then The open position is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `OPEN_POSITION_AMOUNT`
     */
    function test_ForkInitiateOpenPositionFullBalance() public {
        uint256 ethBalanceBefore = address(this).balance;
        uint256 wstETHBefore = wstETH.balanceOf(address(this));

        wstETH.transfer(address(router), OPEN_POSITION_AMOUNT);

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_OPEN));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                Constants.CONTRACT_BALANCE,
                DESIRED_LIQUIDATION,
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
        assertEq(wstETH.balanceOf(address(this)), wstETHBefore - OPEN_POSITION_AMOUNT, "wstETH balance");
    }

    /**
     * @custom:scenario Initiating an open position through the router with a permit transfer
     * @custom:given The user sent the exact amount of wstETH to the router by doing a permit transfer
     * @custom:when The user initiates a permit transfer to the router
     * @custom:and The user initiates an open position through the router
     * @custom:then Open position is initiated successfully
     */
    function test_ForkInitiateOpenPositionWithPermit() public {
        uint256 ethBalanceBefore = vm.addr(1).balance;
        uint256 wstETHBefore = wstETH.balanceOf(vm.addr(1));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            _getDigest(
                vm.addr(1), address(router), OPEN_POSITION_AMOUNT, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR()
            )
        );

        bytes memory commands = _getPermitCommand();
        bytes[] memory inputs = new bytes[](3);
        inputs[0] =
            abi.encode(address(wstETH), vm.addr(1), address(router), OPEN_POSITION_AMOUNT, type(uint256).max, v, r, s);

        inputs[1] = abi.encode(address(wstETH), address(router), OPEN_POSITION_AMOUNT);

        inputs[2] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                OPEN_POSITION_AMOUNT,
                DESIRED_LIQUIDATION,
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

        vm.prank(vm.addr(1));
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(vm.addr(1).balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(wstETH.balanceOf(vm.addr(1)), wstETHBefore - OPEN_POSITION_AMOUNT, "wstETH balance");
    }

    /**
     * @custom:scenario Initiating an open position through the router with a "full balance" amount with a permit
     * transfer
     * @custom:given The user sent the `OPEN_POSITION_AMOUNT` of wstETH to the router by doing a permit transfer
     * @custom:when The user initiates a permit transfer to the router
     * @custom:and The user initiates an open position through the router with the amount `CONTRACT_BALANCE`
     * @custom:then The open position is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `OPEN_POSITION_AMOUNT`
     */
    function test_ForkInitiateOpenPositionFullBalanceWithPermit() public {
        uint256 ethBalanceBefore = vm.addr(1).balance;
        uint256 wstETHBefore = wstETH.balanceOf(vm.addr(1));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            _getDigest(
                vm.addr(1), address(router), OPEN_POSITION_AMOUNT, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR()
            )
        );

        bytes memory commands = _getPermitCommand();

        bytes[] memory inputs = new bytes[](3);
        inputs[0] =
            abi.encode(address(wstETH), vm.addr(1), address(router), OPEN_POSITION_AMOUNT, type(uint256).max, v, r, s);

        inputs[1] = abi.encode(address(wstETH), address(router), OPEN_POSITION_AMOUNT);

        inputs[2] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                Constants.CONTRACT_BALANCE,
                DESIRED_LIQUIDATION,
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
        vm.prank(vm.addr(1));
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(vm.addr(1).balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(wstETH.balanceOf(vm.addr(1)), wstETHBefore - OPEN_POSITION_AMOUNT, "wstETH balance");
    }

    /**
     * @custom:scenario Initiating an open position through the router with an invalid recipient
     * @custom:when The user calls the `INITIATE_OPEN` command
     * @custom:then The call reverts with `InvalidRecipient`
     */
    function test_RevertWhen_initiateOpenPositionInvalidRecipient() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_OPEN));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                0, 0, 0, 0, address(router), address(0), 0, "", EMPTY_PREVIOUS_DATA, 0
            )
        );
        vm.expectRevert(LockAndMap.LockAndMapInvalidRecipient.selector);
        router.execute(commands, inputs);

        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                0, 0, 0, 0, Constants.ADDRESS_THIS, address(0), 0, "", EMPTY_PREVIOUS_DATA, 0
            )
        );
        vm.expectRevert(LockAndMap.LockAndMapInvalidRecipient.selector);
        router.execute(commands, inputs);

        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                0, 0, 0, 0, address(0), address(router), 0, "", EMPTY_PREVIOUS_DATA, 0
            )
        );
        vm.expectRevert(LockAndMap.LockAndMapInvalidRecipient.selector);
        router.execute(commands, inputs);

        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                0, 0, 0, 0, address(0), Constants.ADDRESS_THIS, 0, "", EMPTY_PREVIOUS_DATA, 0
            )
        );
        vm.expectRevert(LockAndMap.LockAndMapInvalidRecipient.selector);
        router.execute(commands, inputs);
    }

    function _getPermitCommand() internal pure returns (bytes memory) {
        bytes memory commandPermitWsteth = abi.encodePacked(uint8(Commands.PERMIT) | uint8(Commands.FLAG_ALLOW_REVERT));
        bytes memory commandTransferFromWsteth =
            abi.encodePacked(uint8(Commands.TRANSFER_FROM) | uint8(Commands.FLAG_ALLOW_REVERT));
        bytes memory commandInitiateDeposit = abi.encodePacked(uint8(Commands.INITIATE_OPEN));
        return abi.encodePacked(commandPermitWsteth, commandTransferFromWsteth, commandInitiateDeposit);
    }
}
