// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { PYTH_ETH_USD, USER_1, USER_2 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Validating a deposit through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterValidateDeposit is UniversalRouterBaseFixture {
    uint256 internal _securityDeposit;

    function setUp() public {
        _setUp(DEFAULT_PARAMS);
        deal(address(wstETH), address(this), 1e6 ether);
        deal(address(sdex), address(this), INITIAL_SDEX_BALANCE);
        wstETH.approve(address(protocol), type(uint256).max);
        sdex.approve(address(protocol), type(uint256).max);
        _securityDeposit = protocol.getSecurityDepositValue();
        protocol.initiateDeposit{ value: _securityDeposit }(
            0.1 ether, 0, USER_2, USER_1, type(uint256).max, "", EMPTY_PREVIOUS_DATA
        );
    }

    /**
     * @custom:scenario Validating a deposit through the router
     * @custom:given The user has initiated a deposit and we have price know by the oracle
     * @custom:when The user validates a deposit through the router
     * @custom:then The deposit is validated successfully
     */
    function test_ForkValidateDeposit() public {
        _waitDelay(); //to be realistic because not mandatory
        uint256 ts1 = protocol.getUserPendingAction(USER_1).timestamp;
        (,,,, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, ts1 + oracleMiddleware.getValidationDelay());

        uint256 ethBalanceBefore = address(this).balance;
        uint256 ethBalanceBeforeUser = USER_1.balance;
        uint256 validationCost =
            oracleMiddleware.validationCost(data, IUsdnProtocolTypes.ProtocolAction.ValidateDeposit);

        bytes memory commands = abi.encodePacked(uint8(Commands.VALIDATE_DEPOSIT));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(USER_1, data, EMPTY_PREVIOUS_DATA, validationCost);
        router.execute{ value: validationCost }(commands, inputs);

        assertEq(address(this).balance, ethBalanceBefore - validationCost, "ether balance");
        assertEq(USER_1.balance, ethBalanceBeforeUser + _securityDeposit, "user balance");
        assertEq(usdn.sharesOf(address(this)), 0, "usdn shares");
        assertEq(usdn.sharesOf(USER_1), 0, "usdn shares USER_1");
        assertGt(usdn.sharesOf(USER_2), 0, "usdn shares USER_2");
    }
}
