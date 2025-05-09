// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { WETH } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { IOdosRouterV2 } from "./utils/IOdosRouterV2.sol";

import { Commands } from "../../src/libraries/Commands.sol";
import { Odos } from "../../src/modules/Odos.sol";

/**
 * @custom:feature Test the `ODOS` command
 * @custom:background A initiated universal router
 */
contract TestForkOdos is UniversalRouterBaseFixture {
    uint256 internal constant SWAP_AMOUNT = 1 ether;
    uint32 internal constant SWAP_REFERRAL_CODE = 0;
    address internal constant SWAP_EXECUTOR = 0x76edF8C155A1e0D9B2aD11B04d9671CBC25fEE99;

    function setUp() external {
        SetUpParams memory params = DEFAULT_PARAMS;
        params.forkBlock = 22_417_713;
        _setUp(params);

        deal(address(wstETH), address(this), SWAP_AMOUNT);
    }

    /**
     * @notice Test the token swaps via Odos router
     * @custom:given A data to send to Odos create via their API
     * @custom:when The `execute` function is called for `ODOS` command
     * @custom:then The `ODOS` command should swap the tokens
     */
    function test_forkOdosSwapToken() external {
        wstETH.transfer(address(router), SWAP_AMOUNT);
        uint256 balanceWethBefore = IERC20(WETH).balanceOf(address(router));
        // path to swap wstETH to WETH
        bytes memory SWAP_PATH =
            hex"010206006801010102030405ff00000000000000000000000000000000000000c4ce391d82d164c166df9c8336ddf84206b2f8127f39c581f595b53c5cb19bd0b3f8da6c935e2ca0c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2775f661b0bd1739349b9a2a3ef60be277c5d2d290fe906e030a44ef24ca8c7dc7b7c53a6c4f00ce9";

        IOdosRouterV2.swapTokenInfo memory params = IOdosRouterV2.swapTokenInfo({
            inputToken: address(wstETH),
            inputAmount: SWAP_AMOUNT,
            inputReceiver: SWAP_EXECUTOR,
            outputToken: WETH,
            outputQuote: SWAP_AMOUNT,
            outputMin: SWAP_AMOUNT,
            outputReceiver: address(router)
        });

        bytes memory commands = abi.encodePacked(uint8(Commands.ODOS));
        bytes[] memory inputs = new bytes[](1);
        bytes memory swapData =
            abi.encodeWithSelector(IOdosRouterV2.swap.selector, params, SWAP_PATH, SWAP_EXECUTOR, SWAP_REFERRAL_CODE);
        inputs[0] = abi.encode(address(wstETH), 0, swapData);

        router.execute(commands, inputs);

        assertEq(wstETH.balanceOf(address(router)), 0, "wstETH balance should be zero");
        assertGt(
            IERC20(WETH).balanceOf(address(router)), balanceWethBefore, "WETH balance should be greater than before"
        );
    }

    /**
     * @notice Test the ETH swaps via Odos router
     * @custom:given A data to send to Odos create via their API
     * @custom:when The `execute` function is called for `ODOS` command
     * @custom:then The `ODOS` command should swap the ether
     */
    function test_forkOdosSwapEth() external {
        uint256 routerWstethBalanceBefore = wstETH.balanceOf(address(router));
        uint256 thisEthBalanceBefore = address(this).balance;
        // path to swap ETH to wstETH
        bytes memory SWAP_PATH =
            hex"01020300690101010200ff0000000000000000000000000000000000000000000b1a513ee24972daef112bc777a5610d4325c9e70000000000000000000000000000000000000000";

        IOdosRouterV2.swapTokenInfo memory params = IOdosRouterV2.swapTokenInfo({
            inputToken: address(0),
            inputAmount: SWAP_AMOUNT,
            inputReceiver: SWAP_EXECUTOR,
            outputToken: address(wstETH),
            outputQuote: SWAP_AMOUNT,
            outputMin: 1,
            outputReceiver: address(router)
        });

        bytes memory commands = abi.encodePacked(uint8(Commands.ODOS));
        bytes[] memory inputs = new bytes[](1);
        bytes memory swapData =
            abi.encodeWithSelector(IOdosRouterV2.swap.selector, params, SWAP_PATH, SWAP_EXECUTOR, SWAP_REFERRAL_CODE);
        inputs[0] = abi.encode(address(0), SWAP_AMOUNT, swapData);

        router.execute{ value: SWAP_AMOUNT }(commands, inputs);

        assertEq(address(router).balance, 0, "ETH balance should be zero");
        assertGt(
            wstETH.balanceOf(address(router)), routerWstethBalanceBefore, "wstETH balance should be greater than before"
        );
        assertEq(address(this).balance, thisEthBalanceBefore - SWAP_AMOUNT, "ETH balance should be SWAP_AMOUNT less");
    }

    /**
     * @notice Test the swap via Odos router
     * @custom:given A data with the swap function selector and random data
     * @custom:when The `execute` function is called for `ODOS` command
     * @custom:then The `ODOS` command should revert with the error `OdosSwapFailed`
     */
    function test_Fork_RevertWhen_SwapFails() external {
        // function selector of the swap function of the Odos router with random data
        bytes memory data = hex"83bd37f900";
        bytes memory commands = abi.encodePacked(uint8(Commands.ODOS));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, 0, data);

        vm.expectRevert(Odos.OdosSwapFailed.selector);
        router.execute(commands, inputs);
    }
}
