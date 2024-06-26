// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IUsdnProtocolTypes } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { DEPLOYER } from "usdn-contracts/test/utils/Constants.sol";

import { Commands } from "../../src/libraries/Commands.sol";

import { PYTH_ETH_USD } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

/**
 * @custom:feature Test liquidate command of universal router
 * @custom:background A initiated universal router
 */
contract TestForkUniversalRouterLiquidate is UniversalRouterBaseFixture {
    using SafeCast for uint256;

    uint256 constant OPEN_POSITION_AMOUNT = 2 ether;
    uint256 constant DESIRED_LIQUIDATION = 4000 ether;
    PositionId internal _posId;
    uint256 _securityDeposit;

    function setUp() external {
        params.forkWarp = 1_710_256_331;
        _setUp();
        vm.rollFork(19_420_000);
        deal(address(wstETH), address(this), OPEN_POSITION_AMOUNT * 2);
        wstETH.approve(address(protocol), type(uint256).max);
        _securityDeposit = protocol.getSecurityDepositValue();
        (, _posId) = protocol.initiateOpenPosition{ value: _securityDeposit }(
            OPEN_POSITION_AMOUNT.toUint128(),
            DESIRED_LIQUIDATION.toUint128(),
            address(this),
            payable(address(this)),
            NO_PERMIT2,
            "",
            EMPTY_PREVIOUS_DATA
        );
        _waitDelay();
        uint256 ts1 = protocol.getUserPendingAction(address(this)).timestamp;
        (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, ts1 + oracleMiddleware.getValidationDelay());
        protocol.validateOpenPosition{
            value: oracleMiddleware.validationCost(data, ProtocolAction.ValidateOpenPosition)
        }(payable(address(this)), data, EMPTY_PREVIOUS_DATA);
    }

    /**
     * @custom:scenario Test the `LIQUIDATE`command of the universal router
     * @custom:given A initiated universal router
     * @custom:and A recent pyth price
     * @custom:when The command is executed
     * @custom:then The transaction should be executed
     */
    function test_ForkExecuteLiquidate() external {
        skip(658_069);
        bytes memory commands = abi.encodePacked(uint8(Commands.LIQUIDATE));
        (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, block.timestamp);
        uint256 validationCost = oracleMiddleware.validationCost(data, ProtocolAction.Liquidation);
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(data, 10, validationCost);
        router.execute{ value: validationCost }(commands, inputs);
        assertLt(
            protocol.getHighestPopulatedTick(),
            _posId.tick,
            "The highest populated tick should be lower than the last liquidated tick"
        );
    }

    receive() external payable { }
}
