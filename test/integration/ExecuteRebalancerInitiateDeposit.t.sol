// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IRebalancerTypes } from "@smardex-usdn-contracts-1/src/interfaces/Rebalancer/IRebalancerTypes.sol";
import { IRebalancer } from "@smardex-usdn-contracts-1/src/interfaces/Rebalancer/IRebalancer.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { IUniversalRouter } from "../../src/interfaces/IUniversalRouter.sol";
import { Commands } from "../../src/libraries/Commands.sol";
import { LockAndMap } from "../../src/modules/usdn/LockAndMap.sol";

/**
 * @custom:feature Test router commands rebalancer initiateDeposit
 * @custom:background A initiated universal router
 */
contract TestForkUniversalRouterRebalancerInitiateDeposit is UniversalRouterBaseFixture {
    uint256 constant BASE_AMOUNT = 10 ether;

    function setUp() external {
        _setUp(DEFAULT_PARAMS);
        deal(address(wstETH), address(this), BASE_AMOUNT * 10);
    }

    /**
     * @custom:scenario The rebalancer initiate deposit
     * @custom:when The router command is triggered
     * @custom:then The transaction should be successful
     */
    function test_executeRebalancerInitiateDeposit() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.REBALANCER_INITIATE_DEPOSIT));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.CONTRACT_BALANCE, Constants.MSG_SENDER);

        wstETH.transfer(address(router), BASE_AMOUNT);
        router.execute(commands, inputs);

        IRebalancerTypes.UserDeposit memory userDeposit = rebalancer.getUserDepositData(address(this));

        assertEq(userDeposit.amount, BASE_AMOUNT, "Amount should be base amount");
        assertGt(userDeposit.initiateTimestamp, 0, "Initial timestamp should be greater than 0");

        // validate
        skip(25);
        rebalancer.validateDepositAssets();
    }

    /**
     * @custom:scenario The rebalancer initiate deposit
     * @custom:when The router command is triggered without rebalancer address
     * @custom:then The transaction should revert
     */
    function test_RevertWhen_executeRebalancerInitiateDepositNoRebalancer() external {
        vm.prank(managers.setExternalManager);
        protocol.setRebalancer(IRebalancer(address(0)));

        bytes memory commands = abi.encodePacked(uint8(Commands.REBALANCER_INITIATE_DEPOSIT));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.CONTRACT_BALANCE, Constants.MSG_SENDER);

        vm.expectRevert(abi.encodeWithSelector(IUniversalRouter.ExecutionFailed.selector, 0, ""));
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario The rebalancer initiate deposit
     * @custom:when The router command is triggered without assets
     * @custom:then The transaction should revert
     */
    function test_RevertWhen_executeRebalancerInitiateDepositZero() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.REBALANCER_INITIATE_DEPOSIT));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.CONTRACT_BALANCE, Constants.MSG_SENDER);

        vm.expectRevert(abi.encodeWithSelector(IUniversalRouter.ExecutionFailed.selector, 0, ""));
        router.execute(commands, inputs);
    }

    /**
     * @custom:scenario Tests the rebalancer initiate deposit though the router with an invalid `to`
     * @custom:when The user executes the rebalancer initiate deposit though the router
     * @custom:then The transaction must revert with `LockAndMapInvalidRecipient`
     */
    function test_RevertWhen_executeRebalancerInitiateDepositInvalidRecipient() external {
        bytes memory commands = abi.encodePacked(uint8(Commands.REBALANCER_INITIATE_DEPOSIT));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(0, address(router));

        vm.expectRevert(LockAndMap.LockAndMapInvalidRecipient.selector);
        router.execute(commands, inputs);
    }
}
