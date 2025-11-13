// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { Commands } from "../../src/libraries/Commands.sol";

import { PYTH_ETH_USD } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

/**
 * @custom:feature Test liquidate command of universal router
 * @custom:background A initiated universal router
 */
contract TestForkUniversalRouterLiquidate is UniversalRouterBaseFixture {
    uint128 constant OPEN_POSITION_AMOUNT = 2 ether;
    uint128 constant DESIRED_LIQUIDATION = 4000 ether;
    PositionId internal _posId;
    uint256 _securityDeposit;

    function setUp() external {
        SetUpParams memory liquidateParams = DEFAULT_PARAMS;
        // Tuesday 12 March 2024 15:12:11
        liquidateParams.forkWarp = 1_710_256_331;
        _setUp(liquidateParams);
        // block 19_420_000 at Mar-12-2024 03:49:35
        vm.rollFork(19_420_000);
        deal(address(wstETH), address(this), OPEN_POSITION_AMOUNT * 2);
        wstETH.approve(address(protocol), type(uint256).max);
        _securityDeposit = protocol.getSecurityDepositValue();

        (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, block.timestamp);

        (, _posId) = protocol.initiateOpenPosition{
            value: _securityDeposit + oracleMiddleware.validationCost(data, ProtocolAction.InitiateOpenPosition)
        }(
            OPEN_POSITION_AMOUNT,
            DESIRED_LIQUIDATION,
            type(uint128).max,
            maxLeverage,
            address(this),
            payable(address(this)),
            type(uint256).max,
            data,
            EMPTY_PREVIOUS_DATA
        );
        _waitDelay();
        uint256 ts1 = protocol.getUserPendingAction(address(this)).timestamp;
        (,,,, bytes memory actionData) =
            getHermesApiSignature(PYTH_ETH_USD, ts1 + oracleMiddleware.getValidationDelay());

        protocol.validateOpenPosition{
            value: oracleMiddleware.validationCost(actionData, ProtocolAction.ValidateOpenPosition)
        }(
            payable(address(this)), actionData, EMPTY_PREVIOUS_DATA
        );
    }

    /**
     * @custom:scenario Test the `LIQUIDATE`command of the universal router
     * @custom:given A initiated universal router
     * @custom:and A recent pyth price
     * @custom:when The command is executed
     * @custom:then The transaction should be executed
     */
    function test_ForkExecuteLiquidate() external {
        // skip 658_069 seconds to Mar-19-2024 15:41:24
        skip(658_069);
        uint256 tickVersionBefore = protocol.getTickVersion(_posId.tick);
        bytes memory commands = abi.encodePacked(uint8(Commands.LIQUIDATE));
        (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, block.timestamp);
        uint256 validationCost = oracleMiddleware.validationCost(data, IUsdnProtocolTypes.ProtocolAction.Liquidation);
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(data, validationCost);
        router.execute{ value: validationCost }(commands, inputs);
        assertLt(
            protocol.getHighestPopulatedTick(),
            _posId.tick,
            "The highest populated tick should be lower than the last liquidated tick"
        );
        assertEq(
            protocol.getTickVersion(_posId.tick), tickVersionBefore + 1, "The tick version should be incremented by 1"
        );
    }

    receive() external payable { }
}
