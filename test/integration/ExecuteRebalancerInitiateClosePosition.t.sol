// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IUsdnProtocolTypes } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { PYTH_ETH_USD, USER_1 } from "usdn-contracts/test/utils/Constants.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Test router commands rebalancer initiateClosePosition
 * @custom:background A initiated universal router
 */
contract TestForkUniversalRouterRebalancerInitiateClosePosition is UniversalRouterBaseFixture {
    struct InitiateClosePositionDelegation {
        uint88 amount;
        address to;
        uint256 userMinPrice;
        uint256 deadline;
        address depositOwner;
        address depositCloser;
        uint256 nonce;
    }

    uint88 internal constant BASE_AMOUNT = 2 ether;
    uint256 internal constant USER_PK = 1;
    address payable internal _user = payable(vm.addr(USER_PK));
    uint256 internal _securityDeposit;
    uint256 internal _initialNonce;
    bytes internal _signature;
    bytes internal _delegationData;
    IUsdnProtocolTypes.PositionId internal _posId;
    InitiateClosePositionDelegation internal _delegation;
    bytes internal _data;
    uint256 internal _oracleFee;

    function setUp() external {
        string memory url = vm.rpcUrl("mainnet");
        vm.createSelectFork(url);
        params = DEFAULT_PARAMS;
        params.forkWarp = block.timestamp - 8 hours; // 2024-01-01 07:00:00 UTC;
        params.forkBlock = block.number - 2400;
        _setUp(params);
        deal(_user, 10_000 ether);
        deal(address(rebalancer), 10 ether);
        _securityDeposit = protocol.getSecurityDepositValue();
        vm.startPrank(_user);
        (bool successUser,) = address(wstETH).call{ value: 100 ether }("");
        assertTrue(successUser, "user ETH should be transferred");
        wstETH.approve(address(rebalancer), type(uint256).max);
        rebalancer.initiateDepositAssets(BASE_AMOUNT, _user);
        skip(rebalancer.getTimeLimits().validationDelay);
        rebalancer.validateDepositAssets();
        vm.stopPrank();

        vm.startPrank(address(rebalancer));
        wstETH.approve(address(protocol), type(uint256).max);

        (, _posId) = protocol.initiateOpenPosition{ value: _securityDeposit }(
            BASE_AMOUNT,
            params.initialLiqPrice,
            type(uint128).max,
            maxLeverage,
            address(rebalancer),
            payable(rebalancer),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA
        );
        uint256 positionTimestamp = protocol.getUserPendingAction(address(rebalancer)).timestamp;

        _waitDelay();

        (,,,, _data) = getHermesApiSignature(PYTH_ETH_USD, positionTimestamp + oracleMiddleware.getValidationDelay());

        _oracleFee = oracleMiddleware.validationCost(_data, ProtocolAction.ValidateOpenPosition);
        protocol.validateOpenPosition{ value: _oracleFee }(payable(rebalancer), _data, EMPTY_PREVIOUS_DATA);
        vm.stopPrank();

        vm.prank(address(protocol));
        rebalancer.updatePosition(_posId, 0);

        _initialNonce = rebalancer.getNonce(_user);

        _delegation = InitiateClosePositionDelegation({
            amount: BASE_AMOUNT,
            to: _user,
            userMinPrice: 0,
            deadline: type(uint256).max,
            depositOwner: _user,
            depositCloser: address(router),
            nonce: _initialNonce
        });

        _signature = _getDelegationSignature(USER_PK, _delegation);
        _delegationData = abi.encode(_user, _signature);

        vm.warp(rebalancer.getCloseLockedUntil() + 1);
        (,,,, _data) = getHermesApiSignature(PYTH_ETH_USD, block.timestamp);
        _oracleFee = oracleMiddleware.validationCost(_data, ProtocolAction.InitiateClosePosition);
    }

    /**
     * @custom:scenario Initiating a rebalancer close position through the router using the delegation signature
     * @custom:given A user rebalancer deposit
     * @custom:and A validated rebalancer open position
     * @custom:and A valid rebalancer close position delegation
     * @custom:when The user initiates a rebalancer close position through the router
     * @custom:then The close position is initiated successfully
     */
    function test_ForkRebalancerInitiateClosePositionDelegation() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.REBALANCER_INITIATE_CLOSE));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(
            _delegation.amount,
            _delegation.to,
            Constants.MSG_SENDER,
            _delegation.userMinPrice,
            _delegation.deadline,
            _data,
            EMPTY_PREVIOUS_DATA,
            _delegationData,
            _securityDeposit + _oracleFee
        );

        router.execute{ value: _securityDeposit + _oracleFee }(commands, inputs);

        assertEq(
            rebalancer.getUserDepositData(_user).amount, 0, "The user's deposited amount in rebalancer should be zero"
        );

        assertTrue(
            protocol.getUserPendingAction(address(this)).action == ProtocolAction.ValidateClosePosition,
            "The validator protocol action should pending"
        );

        assertEq(rebalancer.getNonce(_user), _initialNonce + 1, "The user nonce should be incremented");
    }

    /**
     * @custom:scenario A delegation signature front-running of a rebalancer initiate close position through the router
     * @custom:given A user rebalancer deposit
     * @custom:and A validated rebalancer open position
     * @custom:and A valid rebalancer close position delegation
     * @custom:and A delegation front-running through the router
     * @custom:when The user initiates the same rebalancer close position through the router
     * @custom:then The execution doesn't revert
     * @custom:and The initiated close position is still valid
     */
    function test_ForkRebalancerInitiateClosePositionDelegationFrontRunning() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.REBALANCER_INITIATE_CLOSE));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(
            _delegation.amount,
            _delegation.to,
            Constants.MSG_SENDER,
            _delegation.userMinPrice,
            _delegation.deadline,
            _data,
            EMPTY_PREVIOUS_DATA,
            _delegationData,
            _securityDeposit + _oracleFee
        );

        vm.prank(USER_1);
        router.execute{ value: _securityDeposit + _oracleFee }(commands, inputs);

        commands = abi.encodePacked(uint8(Commands.REBALANCER_INITIATE_CLOSE) | uint8(Commands.FLAG_ALLOW_REVERT));
        router.execute{ value: _securityDeposit + _oracleFee }(commands, inputs);

        assertEq(
            rebalancer.getUserDepositData(_user).amount, 0, "The user's deposited amount in rebalancer should be zero"
        );

        assertTrue(
            protocol.getUserPendingAction(USER_1).action == ProtocolAction.ValidateClosePosition,
            "The validator protocol action should pending"
        );

        assertEq(rebalancer.getNonce(_user), _initialNonce + 1, "The user nonce should be incremented");
    }

    /**
     * @notice Get the delegation signature
     * @param privateKey The signer private key
     * @param delegationToSign The delegation struct to sign
     * @return delegationSignature_ The initiateClosePosition eip712 delegation signature
     */
    function _getDelegationSignature(uint256 privateKey, InitiateClosePositionDelegation memory delegationToSign)
        internal
        view
        returns (bytes memory delegationSignature_)
    {
        bytes32 digest = MessageHashUtils.toTypedDataHash(
            rebalancer.domainSeparatorV4(),
            keccak256(
                abi.encode(
                    rebalancer.INITIATE_CLOSE_TYPEHASH(),
                    delegationToSign.amount,
                    delegationToSign.to,
                    delegationToSign.userMinPrice,
                    delegationToSign.deadline,
                    delegationToSign.depositOwner,
                    delegationToSign.depositCloser,
                    delegationToSign.nonce
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        delegationSignature_ = abi.encodePacked(r, s, v);
    }
}
