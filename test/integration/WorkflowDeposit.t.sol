// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { DepositPendingAction } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { WETH, SDEX, USER_1 } from "usdn-contracts/test/utils/Constants.sol";

import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { ISmardexSwapRouterErrors } from "../../src/interfaces/smardex/ISmardexSwapRouterErrors.sol";

/**
 * @custom:feature Entire workflow of deposit through the router
 * @custom:background An initiated universal router
 */
contract TestForkWorkflowDeposit is UniversalRouterBaseFixture, ISmardexSwapRouterErrors {
    uint256 constant DEPOSIT_AMOUNT = 0.1 ether;
    uint256 internal _securityDeposit;
    uint256 internal _sdexToBurn;

    function setUp() external {
        _setUp();
        _securityDeposit = protocol.getSecurityDepositValue();
        _sdexToBurn = _calcSdexToBurn(DEPOSIT_AMOUNT);
    }

    function test_ForkWorkflowDepositThroughUniswap() external {
        _workflowsDeposit(
            abi.encodePacked(uint8(Commands.V3_SWAP_EXACT_OUT)),
            abi.encode(
                Constants.ADDRESS_THIS, _sdexToBurn, DEPOSIT_AMOUNT, abi.encodePacked(SDEX, uint24(10_000), WETH), false
            )
        );
    }

    function test_ForkWorkflowDepositThroughSmardex() external {
        _workflowsDeposit(
            abi.encodePacked(uint8(Commands.SMARDEX_SWAP_EXACT_OUT)),
            abi.encode(Constants.ADDRESS_THIS, _sdexToBurn, DEPOSIT_AMOUNT, abi.encodePacked(WETH, SDEX), false)
        );
    }

    function _calcSdexToBurn(uint256 depositAmount) internal view returns (uint256 sdexToBurn_) {
        uint256 usdnSharesToMintEstimated = protocol.i_calcMintUsdnShares(
            depositAmount, protocol.getBalanceVault(), usdn.totalShares(), params.initialPrice
        );
        uint256 usdnToMintEstimated = usdn.convertToTokens(usdnSharesToMintEstimated);
        sdexToBurn_ = protocol.i_calcSdexToBurn(usdnToMintEstimated, protocol.getSdexBurnOnDepositRatio());
    }

    function _workflowsDeposit(bytes memory command, bytes memory input) internal {
        bytes memory commands = abi.encodePacked(
            uint8(Commands.TRANSFER),
            command,
            uint8(Commands.TRANSFER),
            uint8(Commands.INITIATE_DEPOSIT),
            uint8(Commands.SWEEP),
            uint8(Commands.SWEEP),
            uint8(Commands.SWEEP),
            uint8(Commands.SWEEP)
        );

        bytes[] memory inputs = new bytes[](8);
        inputs[0] = abi.encode(Constants.ETH, WETH, DEPOSIT_AMOUNT);
        inputs[1] = input;
        inputs[2] = abi.encode(Constants.ETH, wstETH, DEPOSIT_AMOUNT);
        inputs[3] = abi.encode(
            Constants.CONTRACT_BALANCE, USER_1, USER_1, NO_PERMIT2, "", EMPTY_PREVIOUS_DATA, _securityDeposit
        );
        inputs[4] = abi.encode(Constants.ETH, address(this), 0);
        inputs[5] = abi.encode(wstETH, address(this), 0);
        inputs[6] = abi.encode(WETH, address(this), 0);
        inputs[7] = abi.encode(SDEX, address(this), 0);

        router.execute{ value: _securityDeposit + DEPOSIT_AMOUNT * 2 }(commands, inputs);

        DepositPendingAction memory action = protocol.i_toDepositPendingAction(protocol.getUserPendingAction(USER_1));

        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, USER_1, "pending action validator");
        assertGt(action.amount, 0, "pending action amount");
        assertEq(address(router).balance, 0, "ETH balance");
        assertEq(IERC20(wstETH).balanceOf(address(router)), 0, "WETH balance");
        assertEq(IERC20(SDEX).balanceOf(address(router)), 0, "SDEX balance");
        assertEq(IERC20(WETH).balanceOf(address(router)), 0, "WETH balance");
    }
}
