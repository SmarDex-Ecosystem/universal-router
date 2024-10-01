// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { DEPLOYER, USER_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { SigUtils } from "./utils/SigUtils.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { IPaymentLibTypes } from "../../src/interfaces/usdn/IPaymentLibTypes.sol";

/**
 * @custom:feature Initiating a withdrawal through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterInitiateWithdrawal is UniversalRouterBaseFixture, SigUtils {
    uint256 internal WITHDRAW_SHARES_AMOUNT;
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp(DEFAULT_PARAMS);
        WITHDRAW_SHARES_AMOUNT = usdn.sharesOf(DEPLOYER) / 100;
        vm.startPrank(DEPLOYER);
        usdn.transferShares(address(this), WITHDRAW_SHARES_AMOUNT);
        usdn.transferShares(sigUser1, WITHDRAW_SHARES_AMOUNT);
        vm.stopPrank();
        deal(sigUser1, 1e6 ether);
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

        usdn.transferShares(address(router), WITHDRAW_SHARES_AMOUNT);

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_WITHDRAWAL));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IPaymentLibTypes.PaymentTypes.Transfer,
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
        assertEq(usdn.sharesOf(address(this)), usdnSharesBefore - WITHDRAW_SHARES_AMOUNT, "usdn shares");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router with a "full balance" amount
     * @custom:given The user sent the `WITHDRAW_SHARES_AMOUNT` of USDN to the router
     * @custom:when The user initiates a withdrawal through the router with amount `CONTRACT_BALANCE`
     * @custom:then The withdrawal is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `WITHDRAW_SHARES_AMOUNT`
     */
    function test_ForkInitiateWithdrawFullBalance() public {
        uint256 ethBalanceBefore = address(this).balance;
        uint256 usdnSharesBefore = usdn.sharesOf(address(this));

        usdn.transferShares(address(router), WITHDRAW_SHARES_AMOUNT);

        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_WITHDRAWAL));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            IPaymentLibTypes.PaymentTypes.Transfer,
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
        assertEq(usdn.sharesOf(address(this)), usdnSharesBefore - WITHDRAW_SHARES_AMOUNT, "usdn shares");
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

        uint256 usdnTokensToTransfer = usdn.convertToTokens(WITHDRAW_SHARES_AMOUNT);

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
            IPaymentLibTypes.PaymentTypes.Transfer,
            WITHDRAW_SHARES_AMOUNT,
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
        assertEq(usdn.sharesOf(sigUser1), usdnSharesBefore - WITHDRAW_SHARES_AMOUNT, "usdn shares");
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

        uint256 usdnTokensToTransfer = usdn.convertToTokens(WITHDRAW_SHARES_AMOUNT);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            SIG_USER1_PK,
            _getDigest(sigUser1, address(router), usdnTokensToTransfer, 0, type(uint256).max, usdn.DOMAIN_SEPARATOR())
        );

        bytes memory commands = abi.encodePacked(uint8(Commands.PERMIT), uint8(Commands.INITIATE_WITHDRAWAL));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] =
            abi.encode(address(usdn), sigUser1, address(router), usdnTokensToTransfer, type(uint256).max, v, r, s);

        inputs[1] = abi.encode(
            IPaymentLibTypes.PaymentTypes.TransferFrom,
            WITHDRAW_SHARES_AMOUNT,
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
        assertEq(usdn.sharesOf(sigUser1), usdnSharesBefore - WITHDRAW_SHARES_AMOUNT, "usdn shares");
    }
}
