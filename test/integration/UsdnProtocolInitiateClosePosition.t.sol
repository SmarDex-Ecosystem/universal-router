// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";

import { PYTH_ETH_USD, USER_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { SigUtils } from "./utils/SigUtils.sol";

import { IUsdnProtocolRouterTypes } from "../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { Commands } from "../../src/libraries/Commands.sol";
import { LockAndMap } from "../../src/modules/usdn/LockAndMap.sol";

/**
 * @custom:feature Initiating a close position through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterInitiateClose is UniversalRouterBaseFixture, SigUtils {
    uint256 internal constant USER_PK = 1;
    address internal user = vm.addr(USER_PK);

    uint128 internal constant BASE_AMOUNT = 2 ether;
    uint256 internal _securityDeposit;
    IUsdnProtocolTypes.PositionId internal _posId;
    InitiateClosePositionDelegation internal _delegation;
    bytes internal _delegationSignature;

    function setUp() public {
        _setUp(DEFAULT_PARAMS);

        deal(address(wstETH), user, BASE_AMOUNT * 2);
        deal(user, 1e6 ether);

        _securityDeposit = protocol.getSecurityDepositValue();

        vm.startPrank(user);
        wstETH.approve(address(protocol), type(uint256).max);

        uint256 ts1 = block.timestamp;
        bool success;
        (success, _posId) = protocol.initiateOpenPosition{ value: _securityDeposit }(
            BASE_AMOUNT,
            params.initialLiqPrice,
            type(uint128).max,
            maxLeverage,
            user,
            payable(user),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA
        );

        assertTrue(success, "User position is not initiated");

        _waitDelay();

        (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, ts1 + oracleMiddleware.getValidationDelay());

        protocol.validateOpenPosition{
            value: oracleMiddleware.validationCost(data, IUsdnProtocolTypes.ProtocolAction.ValidateOpenPosition)
        }(payable(user), data, EMPTY_PREVIOUS_DATA);

        vm.stopPrank();

        _delegation = InitiateClosePositionDelegation(
            keccak256(abi.encode(_posId)),
            BASE_AMOUNT,
            0,
            address(this),
            type(uint256).max,
            user,
            address(router),
            protocol.getNonce(user)
        );

        _delegationSignature = _getInitiateCloseDelegationSignature(USER_PK, protocol.domainSeparatorV4(), _delegation);
    }

    /**
     * @custom:scenario Initiating a close position through the router using the delegation signature
     * @custom:given A validated open position
     * @custom:and A valid position owner signature
     * @custom:when The user initiates a close position through the router
     * @custom:then The close position is initiated successfully
     */
    function test_ForkInitiateClose() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_CLOSE));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateClosePositionData(
                _posId,
                _delegation.amountToClose,
                _delegation.userMinPrice,
                _delegation.to,
                address(this),
                _delegation.deadline,
                "",
                EMPTY_PREVIOUS_DATA,
                _delegationSignature,
                _securityDeposit
            )
        );

        router.execute{ value: _securityDeposit }(commands, inputs);

        IUsdnProtocolTypes.LongPendingAction memory action =
            protocol.i_toLongPendingAction(protocol.getUserPendingAction(address(this)));

        assertTrue(action.action == ProtocolAction.ValidateClosePosition, "The action type is wrong");
        assertEq(action.to, _delegation.to, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertEq(action.tickVersion, 0, "pending action tick version");
        assertEq(action.securityDepositValue, _securityDeposit, "pending action security deposit value");
    }

    /**
     * @custom:scenario A delegation signature front-running of a initiate close position through the router
     * @custom:given A validated open position
     * @custom:and A valid close position owner signature
     * @custom:and A delegation front-run as initiated the close position through the router
     * @custom:when The user initiates the same close position through the router
     * @custom:then The execution doesn't revert
     * @custom:and The initiated close position is still valid
     */
    function test_ForkInitiateCloseFrontRunning() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_CLOSE));
        bytes[] memory inputs = new bytes[](1);

        IUsdnProtocolRouterTypes.InitiateClosePositionData memory closeData = IUsdnProtocolRouterTypes
            .InitiateClosePositionData(
            _posId,
            _delegation.amountToClose,
            _delegation.userMinPrice,
            _delegation.to,
            USER_1,
            _delegation.deadline,
            "",
            EMPTY_PREVIOUS_DATA,
            _delegationSignature,
            _securityDeposit
        );

        inputs[0] = abi.encode(closeData);

        vm.prank(USER_1);
        router.execute{ value: _securityDeposit }(commands, inputs);

        closeData.validator = address(this);
        inputs[0] = abi.encode(closeData);

        commands = abi.encodePacked(uint8(Commands.INITIATE_CLOSE) | uint8(Commands.FLAG_ALLOW_REVERT));
        router.execute{ value: _securityDeposit }(commands, inputs);

        IUsdnProtocolTypes.LongPendingAction memory action =
            protocol.i_toLongPendingAction(protocol.getUserPendingAction(USER_1));

        assertTrue(action.action == ProtocolAction.ValidateClosePosition, "The action type is wrong");
        assertEq(action.to, _delegation.to, "pending action to");
        assertEq(action.validator, USER_1, "pending action validator");
        assertEq(action.tickVersion, 0, "pending action tick version");
        assertEq(action.securityDepositValue, _securityDeposit, "pending action security deposit value");
    }

    /**
     * @custom:scenario Initiating a close position through the router with the router as `to`
     * @custom:when The user initiates a close position through the router
     * @custom:then The transaction must revert with `LockAndMapInvalidRecipient`
     */
    function test_RevertWhen_ForkInitiateCloseInvalidRecipientTo() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_CLOSE));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateClosePositionData(
                IUsdnProtocolTypes.PositionId(0, 0, 0),
                0,
                0,
                address(router),
                address(this),
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                "",
                0
            )
        );

        vm.expectRevert(LockAndMap.LockAndMapInvalidRecipient.selector);
        router.execute{ value: _securityDeposit }(commands, inputs);
    }

    /**
     * @custom:scenario Initiating a close position through the router with the router as `validator`
     * @custom:when The user initiates a close position through the router
     * @custom:then The transaction must revert with `LockAndMapInvalidRecipient`
     */
    function test_RevertWhen_ForkInitiateCloseInvalidRecipientValidator() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.INITIATE_CLOSE));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateClosePositionData(
                IUsdnProtocolTypes.PositionId(0, 0, 0),
                0,
                0,
                address(this),
                address(router),
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                "",
                0
            )
        );

        vm.expectRevert(LockAndMap.LockAndMapInvalidRecipient.selector);
        router.execute{ value: _securityDeposit }(commands, inputs);
    }
}
