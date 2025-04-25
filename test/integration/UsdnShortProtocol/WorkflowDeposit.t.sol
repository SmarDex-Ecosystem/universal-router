// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { WETH, SDEX, USER_1 } from "@smardex-usdn-contracts-1/test/utils/Constants.sol";
import { UsdnProtocolUtilsLibrary as Utils } from
    "@smardex-usdn-contracts-1/src/UsdnProtocol/libraries/UsdnProtocolUtilsLibrary.sol";

import { UniversalRouterUsdnShortProtocolBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../../src/libraries/Commands.sol";
import { IUsdnProtocolRouterTypes } from "../../../src/interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { ISmardexRouterErrors } from "../../../src/interfaces/smardex/ISmardexRouterErrors.sol";
import { IPaymentLibTypes } from "../../../src/interfaces/usdn/IPaymentLibTypes.sol";

/**
 * @custom:feature Entire workflow of deposit through the router
 * @custom:background An initiated universal router
 */
contract TestForkWorkflowUsdnShortDeposit is UniversalRouterUsdnShortProtocolBaseFixture, ISmardexRouterErrors {
    uint256 constant DEPOSIT_AMOUNT = 0.1 ether;
    uint256 internal _securityDeposit;
    uint256 internal _sdexToBurn;

    function setUp() external {
        _setUp();
        _securityDeposit = protocol.getSecurityDepositValue();
        _sdexToBurn = Utils._calcSdexToBurn(DEPOSIT_AMOUNT, protocol.getSdexBurnOnDepositRatio());
        sdex.approve(address(router), type(uint256).max);
        asset.approve(address(router), type(uint256).max);
    }

    /**
     * @custom:action Entire workflow of deposit through the router with Uniswap
     * @custom:given The user has some ETH
     * @custom:when The user run some commands to deposit through the router
     * @custom:then The deposit is initiated successfully
     * @custom:and All tokens are returned to the user
     */
    function test_ForkUsdnShortWorkflowDepositThroughUniswap() external {
        _workflowsDeposit(
            abi.encodePacked(uint8(Commands.V3_SWAP_EXACT_OUT)),
            abi.encode(
                Constants.ADDRESS_THIS, _sdexToBurn, DEPOSIT_AMOUNT, abi.encodePacked(SDEX, uint24(10_000), WETH), false
            )
        );
    }

    /**
     * @custom:action Entire workflow of deposit through the router with smardex
     * @custom:given The user has some ETH
     * @custom:when The user run some commands to deposit through the router
     * @custom:then The deposit is initiated successfully
     * @custom:and All tokens are returned to the user
     */
    function test_ForkUsdnShortWorkflowDepositThroughSmardex() external {
        _workflowsDeposit(
            abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT)),
            abi.encode(Constants.ADDRESS_THIS, _sdexToBurn, DEPOSIT_AMOUNT, abi.encodePacked(WETH, SDEX), false)
        );
    }

    /// @dev Execute the deposit workflow
    function _workflowsDeposit(bytes memory command, bytes memory input) internal {
        bytes memory commands = abi.encodePacked(
            uint8(Commands.TRANSFER),
            command,
            uint8(Commands.TRANSFER_FROM),
            uint8(Commands.INITIATE_DEPOSIT),
            uint8(Commands.SWEEP),
            uint8(Commands.SWEEP),
            uint8(Commands.SWEEP),
            uint8(Commands.SWEEP)
        );

        bytes[] memory inputs = new bytes[](8);
        inputs[0] = abi.encode(Constants.ETH, WETH, DEPOSIT_AMOUNT);
        inputs[1] = input;
        inputs[2] = abi.encode(address(asset), address(router), DEPOSIT_AMOUNT);
        inputs[3] = abi.encode(
            IUsdnProtocolRouterTypes.InitiateDepositData(
                IPaymentLibTypes.PaymentType.Transfer,
                Constants.CONTRACT_BALANCE,
                0,
                USER_1,
                USER_1,
                type(uint256).max,
                "",
                EMPTY_PREVIOUS_DATA,
                _securityDeposit
            )
        );
        inputs[4] = abi.encode(Constants.ETH, address(this), 0, 0);
        inputs[5] = abi.encode(asset, address(this), 0, 0);
        inputs[6] = abi.encode(WETH, address(this), 0, 0);
        inputs[7] = abi.encode(SDEX, address(this), 0, 0);

        router.execute{ value: _securityDeposit + DEPOSIT_AMOUNT * 2 }(commands, inputs);

        DepositPendingAction memory action = toDepositPendingAction(protocol.getUserPendingAction(USER_1));

        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, USER_1, "pending action validator");
        assertGt(action.amount, 0, "pending action amount");
        assertEq(address(router).balance, 0, "ETH balance");
        assertEq(IERC20(asset).balanceOf(address(router)), 0, "WETH balance");
        assertEq(IERC20(SDEX).balanceOf(address(router)), 0, "SDEX balance");
        assertEq(IERC20(WETH).balanceOf(address(router)), 0, "WETH balance");
    }

    /// @notice To receive ETH
    receive() external payable { }
}
