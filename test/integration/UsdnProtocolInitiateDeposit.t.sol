// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { Constants } from "@uniswap/universal-router/contracts/libraries/Constants.sol";
import { DepositPendingAction } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { USER_1, PKEY_1 } from "./utils/Constants.sol";
import { UniversalRouterBaseFixture } from "./utils/Fixtures.sol";
import { SigUtils } from "./utils/SigUtils.sol";

import { Commands } from "../../src/libraries/Commands.sol";

/**
 * @custom:feature Initiating a deposit through the router
 * @custom:background Given a forked ethereum mainnet chain
 */
contract TestForkUniversalRouterInitiateDeposit is UniversalRouterBaseFixture {
    uint256 constant DEPOSIT_AMOUNT = 0.1 ether;
    uint256 internal _securityDeposit;
    SigUtils internal _sigUtils;

    function setUp() public {
        _setUp();
        deal(address(wstETH), address(this), DEPOSIT_AMOUNT * 2);
        deal(address(sdex), address(this), 1e6 ether);
        deal(address(wstETH), vm.addr(PKEY_1), DEPOSIT_AMOUNT * 2);
        deal(address(sdex), vm.addr(PKEY_1), 1e6 ether);
        deal(vm.addr(PKEY_1), 1e6 ether);
        _sigUtils = new SigUtils();
        _securityDeposit = protocol.getSecurityDepositValue();
    }

    /**
     * @custom:scenario Initiating a deposit through the router
     * @custom:given The user sent the exact amount of assets and exact amount of SDEX to the router
     * @custom:when The user initiates a deposit through the router
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkInitiateDeposit() public {
        wstETH.transfer(address(router), DEPOSIT_AMOUNT);
        sdex.transfer(address(router), _calculateBurnAmount(DEPOSIT_AMOUNT));

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.INITIATE_DEPOSIT)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] =
            abi.encode(DEPOSIT_AMOUNT, USER_1, address(this), NO_PERMIT2, "", EMPTY_PREVIOUS_DATA, _securityDeposit);
        router.execute{ value: _securityDeposit }(commands, inputs);

        DepositPendingAction memory action =
            protocol.i_toDepositPendingAction(protocol.getUserPendingAction(address(this)));

        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertEq(action.amount, DEPOSIT_AMOUNT, "pending action amount");
    }

    /**
     * @custom:scenario Initiating a deposit through the router with a "full balance" amount
     * @custom:given The user sent the `DEPOSIT_AMOUNT` of wstETH to the router
     * @custom:when The user initiates a deposit through the router with amount `CONTRACT_BALANCE`
     * @custom:then The deposit is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `DEPOSIT_AMOUNT`
     */
    function test_ForkInitiateDepositFullBalance() public {
        uint256 wstEthBalanceBefore = wstETH.balanceOf(address(this));

        wstETH.transfer(address(router), DEPOSIT_AMOUNT);
        sdex.transfer(address(router), _calculateBurnAmount(DEPOSIT_AMOUNT));

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.INITIATE_DEPOSIT)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            Constants.CONTRACT_BALANCE, USER_1, address(this), NO_PERMIT2, "", EMPTY_PREVIOUS_DATA, _securityDeposit
        );
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(wstETH.balanceOf(address(this)), wstEthBalanceBefore - DEPOSIT_AMOUNT, "asset balance");
    }

    /**
     * @custom:scenario Initiating a deposit through the router through a permit transfer
     * @custom:given The user sent the exact amount of assets and exact amount of SDEX to the router by doing a permit
     * transfer
     * @custom:when The user initiates a permit transfer to the router
     * @custom:and The user initiates a deposit through the router
     * @custom:then The deposit is initiated successfully
     */
    function test_ForkInitiateDepositWithPermit() public {
        // commands building
        bytes memory commands = _getPermitCommand();

        // inputs building
        bytes[] memory inputs = new bytes[](3);
        uint256 sdexAmount = _calculateBurnAmount(DEPOSIT_AMOUNT);
        // permits
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(
            PKEY_1,
            _sigUtils.getDigest(
                vm.addr(PKEY_1), address(router), DEPOSIT_AMOUNT, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR()
            )
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(
            PKEY_1,
            _sigUtils.getDigest(
                vm.addr(PKEY_1), address(router), sdexAmount, 0, type(uint256).max, sdex.DOMAIN_SEPARATOR()
            )
        );
        inputs[0] = abi.encode(address(wstETH), address(router), DEPOSIT_AMOUNT, type(uint256).max, v0, r0, s0);
        inputs[1] = abi.encode(address(sdex), address(router), sdexAmount, type(uint256).max, v1, r1, s1);
        // deposit
        inputs[2] =
            abi.encode(DEPOSIT_AMOUNT, USER_1, address(this), NO_PERMIT2, "", EMPTY_PREVIOUS_DATA, _securityDeposit);

        // execute
        vm.prank(vm.addr(PKEY_1));
        router.execute{ value: _securityDeposit }(commands, inputs);

        DepositPendingAction memory action =
            protocol.i_toDepositPendingAction(protocol.getUserPendingAction(address(this)));

        assertEq(action.to, USER_1, "pending action to");
        assertEq(action.validator, address(this), "pending action validator");
        assertEq(action.amount, DEPOSIT_AMOUNT, "pending action amount");
    }

    /**
     * @custom:scenario Initiating a deposit through the router with a "full balance" amount through a permit transfer
     * @custom:given The user sent the `DEPOSIT_AMOUNT` of wstETH to the router by doing a permit transfer
     * @custom:when The user initiates a permit transfer through the router with amount `CONTRACT_BALANCE`
     * @custom:and The user initiates a deposit through the router with amount `CONTRACT_BALANCE`
     * @custom:then The deposit is initiated successfully with the full balance of the router
     * @custom:and The user's asset balance is reduced by `DEPOSIT_AMOUNT`
     */
    function test_ForkInitiateDepositFullBalanceWithPermit() public {
        // initial state
        uint256 wstEthBalanceBefore = wstETH.balanceOf(vm.addr(PKEY_1));

        // commands building
        bytes memory commands = _getPermitCommand();

        // inputs building
        bytes[] memory inputs = new bytes[](3);
        uint256 sdexAmount = _calculateBurnAmount(DEPOSIT_AMOUNT);
        // permits
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(
            PKEY_1,
            _sigUtils.getDigest(
                vm.addr(PKEY_1), address(router), DEPOSIT_AMOUNT, 0, type(uint256).max, wstETH.DOMAIN_SEPARATOR()
            )
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(
            PKEY_1,
            _sigUtils.getDigest(
                vm.addr(PKEY_1), address(router), sdexAmount, 0, type(uint256).max, sdex.DOMAIN_SEPARATOR()
            )
        );
        inputs[0] = abi.encode(address(wstETH), address(router), DEPOSIT_AMOUNT, type(uint256).max, v0, r0, s0);
        inputs[1] = abi.encode(address(sdex), address(router), sdexAmount, type(uint256).max, v1, r1, s1);
        // deposit
        inputs[2] = abi.encode(
            Constants.CONTRACT_BALANCE, USER_1, address(this), NO_PERMIT2, "", EMPTY_PREVIOUS_DATA, _securityDeposit
        );

        // execute
        vm.prank(vm.addr(PKEY_1));
        router.execute{ value: _securityDeposit }(commands, inputs);

        assertEq(wstETH.balanceOf(vm.addr(PKEY_1)), wstEthBalanceBefore - DEPOSIT_AMOUNT, "asset balance");
    }

    receive() external payable { }

    function _calculateBurnAmount(uint256 depositAmount) internal view returns (uint256 sdexToBurn_) {
        uint256 usdnSharesToMintEstimated = protocol.i_calcMintUsdnShares(
            depositAmount, protocol.getBalanceVault(), usdn.totalShares(), params.initialPrice
        );
        uint256 usdnToMintEstimated = usdn.convertToTokens(usdnSharesToMintEstimated);
        sdexToBurn_ = protocol.i_calcSdexToBurn(usdnToMintEstimated, protocol.getSdexBurnOnDepositRatio());
    }

    function _getPermitCommand() internal pure returns (bytes memory) {
        bytes memory commandPermitWsteth = abi.encodePacked(bytes1(uint8(Commands.PERMIT_TRANSFER)));
        bytes memory commandPermitSdex = abi.encodePacked(bytes1(uint8(Commands.PERMIT_TRANSFER)));
        bytes memory commandInitiateDeposit = abi.encodePacked(bytes1(uint8(Commands.INITIATE_DEPOSIT)));
        return abi.encodePacked(commandPermitWsteth, commandPermitSdex, commandInitiateDeposit);
    }
}
