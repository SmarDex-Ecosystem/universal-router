// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { DelegationSignatureUtils } from "@smardex-usdn-contracts-1/test/utils/DelegationSignatureUtils.sol";
import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { USER_1, USER_2, PYTH_ETH_USD } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature The usdn {transferPositionOwnership} function through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterTransferPositionOwnership is UniversalRouterBaseFixture, DelegationSignatureUtils {
    uint256 internal constant USER_PK = 1;
    address internal user = vm.addr(USER_PK);

    uint256 internal constant BASE_AMOUNT = 2 ether;
    uint256 internal _securityDeposit;
    uint256 internal _initialNonce;
    bytes internal _signature;

    TransferPositionOwnershipDelegation internal _delegation;
    IUsdnProtocolTypes.PositionId internal _posId;
    IUsdnProtocolTypes.Position internal _pos;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);
        _securityDeposit = protocol.getSecurityDepositValue();

        deal(address(wstETH), address(this), 10_000 ether);
        wstETH.approve(address(protocol), type(uint256).max);

        (, _posId) = protocol.initiateOpenPosition{ value: _securityDeposit }(
            2 ether,
            params.initialLiqPrice,
            type(uint128).max,
            maxLeverage,
            user,
            payable(this),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA
        );
        _waitDelay();
        uint256 ts1 = protocol.getUserPendingAction(address(this)).timestamp;
        (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, ts1 + oracleMiddleware.getValidationDelay());
        protocol.validateOpenPosition{
            value: oracleMiddleware.validationCost(data, IUsdnProtocolTypes.ProtocolAction.ValidateOpenPosition)
        }(payable(this), data, EMPTY_PREVIOUS_DATA);

        (_pos,) = protocol.getLongPosition(_posId);
        assertEq(_pos.user, user, "position should be owned by the user");

        _initialNonce = protocol.getNonce(user);

        _delegation = TransferPositionOwnershipDelegation({
            posIdHash: keccak256(abi.encode(_posId)),
            positionOwner: user,
            newPositionOwner: USER_1,
            delegatedAddress: address(router),
            nonce: _initialNonce
        });

        _signature = _getTransferPositionDelegationSignature(USER_PK, protocol.domainSeparatorV4(), _delegation);
    }

    /**
     * @custom:scenario Transfer a position ownership through the router using the delegation signature
     * @custom:given A validated user open position
     * @custom:and A valid {transferPositionOwnership} delegation signature
     * @custom:when The user transfer the position ownership through the router
     * @custom:then The position ownership is transferred successfully
     */
    function test_ForkTransferPositionOwnershipDelegation() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.TRANSFER_POSITION_OWNERSHIP));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(_posId, USER_1, _signature);
        router.execute(commands, inputs);

        (_pos,) = protocol.getLongPosition(_posId);
        assertEq(_pos.user, USER_1, "position ownership should be transferred to `USER_1`");
    }

    /**
     * @custom:scenario A delegation signature front-running of a transfer position ownership through the router
     * @custom:given A validated user open position
     * @custom:and A valid {transferPositionOwnership} delegation signature
     * @custom:and A delegation front-running through the router
     * @custom:when The user try to transfer the position ownership through the router
     * @custom:then The execution doesn't revert
     * @custom:and The transfer position ownership is still valid
     */
    function test_ForkTransferPositionOwnershipDelegationFrontRunning() public {
        bytes memory commands = abi.encodePacked(uint8(Commands.TRANSFER_POSITION_OWNERSHIP));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(_posId, USER_1, _signature);

        vm.prank(USER_2);
        router.execute(commands, inputs);

        (_pos,) = protocol.getLongPosition(_posId);
        assertEq(_pos.user, USER_1, "position ownership should be transferred to `USER_1`");

        commands = abi.encodePacked(uint8(Commands.TRANSFER_POSITION_OWNERSHIP) | uint8(Commands.FLAG_ALLOW_REVERT));
        router.execute(commands, inputs);

        (_pos,) = protocol.getLongPosition(_posId);
        assertEq(_pos.user, USER_1, "position owner should still be the `USER_1`");
    }

    receive() external payable { }
}
