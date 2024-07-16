// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { IRebalancerTypes } from "usdn-contracts/src/interfaces/Rebalancer/IRebalancerTypes.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";

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
     * @custom:scenario The rebalancer initiate timestamp
     * @custom:when The command is triggered
     * @custom:then The transaction success
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
    }
}
