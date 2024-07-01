// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { DEPLOYER, USER_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { SigUtils } from "./utils/SigUtils.sol";

import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Initiating a withdrawal through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterInitiateWithdrawal is UniversalRouterBaseFixture, SigUtils {
    uint256 internal WITHDRAW_AMOUNT;
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp(DEFAULT_PARAMS);
        WITHDRAW_AMOUNT = usdn.sharesOf(DEPLOYER) / 100;
        vm.startPrank(DEPLOYER);
        usdn.transferShares(address(this), WITHDRAW_AMOUNT);
        usdn.transferShares(vm.addr(1), WITHDRAW_AMOUNT);
        vm.stopPrank();
        deal(vm.addr(1), 1e6 ether);
        _securityDeposit = protocol.getSecurityDepositValue();
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

        usdn.transferShares(address(router), WITHDRAW_AMOUNT);

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_WITHDRAWAL));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(WITHDRAW_AMOUNT, USER_1, address(this), "", EMPTY_PREVIOUS_DATA, _securityDeposit);
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(address(this).balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(usdn.sharesOf(address(this)), usdnSharesBefore - WITHDRAW_AMOUNT, "usdn shares");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router with a "full balance" amount
     * @custom:given The user sent the `WITHDRAW_AMOUNT` of USDN to the router
     * @custom:when The user initiates a withdrawal through the router with amount `CONTRACT_BALANCE`
     * @custom:then The withdrawal is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `WITHDRAW_AMOUNT`
     */
    function test_ForkInitiateWithdrawFullBalance() public {
        uint256 ethBalanceBefore = address(this).balance;
        uint256 usdnSharesBefore = usdn.sharesOf(address(this));

        usdn.transferShares(address(router), WITHDRAW_AMOUNT);

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_WITHDRAWAL));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] =
            abi.encode(Constants.CONTRACT_BALANCE, USER_1, address(this), "", EMPTY_PREVIOUS_DATA, _securityDeposit);
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(address(this).balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(usdn.sharesOf(address(this)), usdnSharesBefore - WITHDRAW_AMOUNT, "usdn shares");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router by doing a permit transfer
     * @custom:given The user sent the exact amount of USDN to the router through a permit transfer
     * @custom:when The user initiates a permit transfer to the router
     * @custom:and The user initiates a withdrawal through the router
     * @custom:then The withdrawal is initiated successfully
     */
    function test_ForkInitiateWithdrawWithPermit() public {
        uint256 ethBalanceBefore = vm.addr(1).balance;
        uint256 usdnSharesBefore = usdn.sharesOf(vm.addr(1));

        uint256 usdnTokensToTransfer = usdn.convertToTokens(WITHDRAW_AMOUNT);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            _getDigest(vm.addr(1), address(router), usdnTokensToTransfer, 0, type(uint256).max, usdn.DOMAIN_SEPARATOR())
        );

        bytes memory commands = _getPermitCommand();
        bytes[] memory inputs = new bytes[](2);
        inputs[0] =
            abi.encode(address(usdn), vm.addr(1), address(router), usdnTokensToTransfer, type(uint256).max, v, r, s);
        inputs[1] = abi.encode(WITHDRAW_AMOUNT, USER_1, address(this), "", EMPTY_PREVIOUS_DATA, _securityDeposit);

        vm.prank(vm.addr(1));
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(vm.addr(1).balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(usdn.sharesOf(vm.addr(1)), usdnSharesBefore - WITHDRAW_AMOUNT, "usdn shares");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router with a "full balance" amount by doing a permit
     * transfer
     * @custom:given The user sent the `WITHDRAW_AMOUNT` of USDN to the router through a permit transfer
     * @custom:when The user initiates a permit transfer to the router
     * @custom:qnd The user initiates a withdrawal through the router with amount `CONTRACT_BALANCE`
     * @custom:then The withdrawal is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `WITHDRAW_AMOUNT`
     */
    function test_ForkInitiateWithdrawFullBalanceWithPermit() public {
        uint256 ethBalanceBefore = vm.addr(1).balance;
        uint256 usdnSharesBefore = usdn.sharesOf(vm.addr(1));

        uint256 usdnTokensToTransfer = usdn.convertToTokensRoundUp(WITHDRAW_AMOUNT);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            _getDigest(vm.addr(1), address(router), usdnTokensToTransfer, 0, type(uint256).max, usdn.DOMAIN_SEPARATOR())
        );

        bytes memory commands = _getPermitCommand();
        bytes[] memory inputs = new bytes[](2);
        inputs[0] =
            abi.encode(address(usdn), vm.addr(1), address(router), usdnTokensToTransfer, type(uint256).max, v, r, s);
        inputs[1] =
            abi.encode(Constants.CONTRACT_BALANCE, USER_1, address(this), "", EMPTY_PREVIOUS_DATA, _securityDeposit);

        vm.prank(vm.addr(1));
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(vm.addr(1).balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(usdn.sharesOf(vm.addr(1)), usdnSharesBefore - WITHDRAW_AMOUNT, "usdn shares");
    }

    function _getPermitCommand() internal pure returns (bytes memory) {
        bytes memory commandPermitWsteth =
            abi.encodePacked(uint8(Commands.PERMIT_TRANSFER_FROM) | uint8(Commands.FLAG_ALLOW_REVERT));
        bytes memory commandInitiateDeposit = abi.encodePacked(uint8(Commands.INITIATE_WITHDRAWAL));
        return abi.encodePacked(commandPermitWsteth, commandInitiateDeposit);
    }
}
