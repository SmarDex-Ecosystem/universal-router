// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { Commands } from "../../../src/libraries/Commands.sol";

import { PYTH_ETH_USD } from "../utils/Constants.sol";
import { UniversalRouterUsdnShortProtocolBaseFixture } from "./utils/Fixtures.sol";

/**
 * @custom:feature Test liquidate command of universal router
 * @custom:background A initiated universal router
 */
contract TestForkUniversalRouterUsdnShortLiquidate is UniversalRouterUsdnShortProtocolBaseFixture {
    PositionId internal _posId;
    uint256 _securityDeposit;

    function setUp() external {
        _setUp();
        asset.approve(address(protocol), type(uint256).max);
        _securityDeposit = protocol.getSecurityDepositValue();

        // (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, block.timestamp);

        (, _posId) = protocol.initiateOpenPosition{
            value: _securityDeposit + oracleMiddleware.validationCost("", ProtocolAction.InitiateOpenPosition)
        }(
            minLongPosition,
            initialPrice / 2,
            type(uint128).max,
            maxLeverage,
            address(this),
            payable(address(this)),
            type(uint256).max,
            "",
            EMPTY_PREVIOUS_DATA
        );
        _waitDelay();
        uint256 ts1 = protocol.getUserPendingAction(address(this)).timestamp;
        (,,,, bytes memory actionData) =
            getHermesApiSignature(PYTH_ETH_USD, ts1 + oracleMiddleware.getValidationDelay());

        protocol.validateOpenPosition{
            value: oracleMiddleware.validationCost(actionData, ProtocolAction.ValidateOpenPosition)
        }(payable(address(this)), actionData, EMPTY_PREVIOUS_DATA);
    }

    /**
     * @custom:scenario Test the `LIQUIDATE`command of the universal router
     * @custom:given A initiated universal router
     * @custom:and A recent pyth price
     * @custom:when The command is executed
     * @custom:then The transaction should be executed
     */
    function test_ForkUsdnShortExecuteLiquidate() external {
        vm.skip(true);
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
