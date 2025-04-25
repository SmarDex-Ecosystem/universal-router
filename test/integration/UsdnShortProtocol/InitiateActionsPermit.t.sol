// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { UsdnProtocolUtilsLibrary as Utils } from
    "@smardex-usdn-contracts-1/src/UsdnProtocol/libraries/UsdnProtocolUtilsLibrary.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import { Commands } from "../../../src/libraries/Commands.sol";
import { IUsdnProtocolRouterTypes } from "../../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { IPaymentLibTypes } from "../../../src/interfaces/usdn/IPaymentLibTypes.sol";
import { UniversalRouterUsdnShortProtocolBaseFixture } from "./utils/Fixtures.sol";
import { USER_1 } from "../utils/Constants.sol";
import { SigUtils } from "../utils/SigUtils.sol";

/**
 * @custom:feature Test the USDN short protocol initiate actions through the router using permit
 * @custom:background A deployed router
 */
contract TestForkUniversalRouterUsdnShortInitiateActionsPermit is
    UniversalRouterUsdnShortProtocolBaseFixture,
    SigUtils
{
    uint256 internal _baseUsdnShortShares;
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp();

        _baseUsdnShortShares = usdn.sharesOf(usdnShortDeployer) / 100;

        vm.prank(usdnShortDeployer);
        usdn.transferShares(sigUser1, _baseUsdnShortShares);
        _securityDeposit = protocol.getSecurityDepositValue();
    }

    /**
     * @custom:scenario Initiating an open position through the router with a permit transfer
     * @custom:given The user sent the exact amount of asset to the router by doing a permit transfer
     * @custom:when The user initiates a permit transfer to the router
     * @custom:and The user initiates a transferFrom through the router
     * @custom:and The user initiates an open position through the router
     * @custom:then The Open position is initiated successfully
     */
    function test_ForkUsdnShortInitiateOpenPositionWithPermitFromRouter() public {
        uint256 ethBalanceBefore = sigUser1.balance;
        uint256 wstETHBefore = asset.balanceOf(sigUser1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            SIG_USER1_PK,
            _getDigest(
                sigUser1,
                address(router),
                minLongPosition,
                0,
                type(uint256).max,
                IERC20Permit(address(asset)).DOMAIN_SEPARATOR()
            )
        );

        bytes memory commands =
            abi.encodePacked(uint8(Commands.PERMIT), uint8(Commands.TRANSFER_FROM), uint8(Commands.INITIATE_OPEN));

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(address(asset), sigUser1, address(router), minLongPosition, type(uint256).max, v, r, s);
        inputs[1] = abi.encode(address(asset), address(router), minLongPosition);
        inputs[2] = abi.encode(
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

        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(sigUser1.balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(asset.balanceOf(sigUser1), wstETHBefore - minLongPosition, "asset balance");

        IUsdnProtocolTypes.PendingAction memory action = protocol.getUserPendingAction(address(this));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating an open position through the router with a permit transfer
     * @custom:given A user permit signature
     * @custom:when The user initiates a permit through the router
     * @custom:and The user initiates an open position through the router
     * @custom:then The Open position is initiated successfully
     */
    function test_ForkUsdnShortInitiateOpenPositionWithPermitFromUser() public {
        uint256 ethBalanceBefore = sigUser1.balance;
        uint256 wstETHBefore = asset.balanceOf(sigUser1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            SIG_USER1_PK,
            _getDigest(
                sigUser1,
                address(router),
                minLongPosition,
                0,
                type(uint256).max,
                IERC20Permit(address(asset)).DOMAIN_SEPARATOR()
            )
        );

        bytes memory commands = abi.encodePacked(uint8(Commands.PERMIT), uint8(Commands.INITIATE_OPEN));

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(address(asset), sigUser1, address(router), minLongPosition, type(uint256).max, v, r, s);
        inputs[1] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateOpenPositionData(
                IPaymentLibTypes.PaymentType.TransferFrom,
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

        vm.prank(sigUser1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(sigUser1.balance, ethBalanceBefore - _securityDeposit, "ether balance");
        assertEq(asset.balanceOf(sigUser1), wstETHBefore - minLongPosition, "asset balance");

        IUsdnProtocolTypes.PendingAction memory action = protocol.getUserPendingAction(address(this));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router by doing a permit transfer
     * @custom:given The user sent the exact amount of usdn to the router through a permit transfer
     * @custom:when The user initiates a permit transfer to the router
     * @custom:and The user initiates a withdrawal through the router
     * @custom:then The withdrawal is initiated successfully
     */
    function test_ForkUsdnShortInitiateWithdrawWithPermitFromRouter() public {
        uint256 ethBalanceBefore = sigUser1.balance;
        uint256 usdnSharesBefore = usdn.sharesOf(sigUser1);
        uint256 usdnTokensToTransfer = usdn.convertToTokensRoundUp(_baseUsdnShortShares);

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
            _baseUsdnShortShares,
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
        assertEq(usdn.sharesOf(sigUser1), usdnSharesBefore - _baseUsdnShortShares, "usdn shares");

        IUsdnProtocolTypes.PendingAction memory action = protocol.getUserPendingAction(address(this));
        assertEq(action.to, USER_1, "pending action to");
    }

    /**
     * @custom:scenario Initiating a withdrawal through the router by doing a permit transfer
     * @custom:given The user gives a usdn approval to the router using permit command
     * @custom:when The user initiates a withdrawal through the router
     * @custom:then The withdrawal is initiated successfully
     */
    function test_ForkUsdnShortInitiateWithdrawWithPermitFromUser() public {
        uint256 ethBalanceBefore = sigUser1.balance;
        uint256 usdnSharesBefore = usdn.sharesOf(sigUser1);
        uint256 usdnTokensToTransfer = usdn.convertToTokensRoundUp(_baseUsdnShortShares);

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
            _baseUsdnShortShares,
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
        assertEq(usdn.sharesOf(sigUser1), usdnSharesBefore - _baseUsdnShortShares, "usdn shares");

        IUsdnProtocolTypes.PendingAction memory action = protocol.getUserPendingAction(address(this));
        assertEq(action.to, USER_1, "pending action to");
    }
}
