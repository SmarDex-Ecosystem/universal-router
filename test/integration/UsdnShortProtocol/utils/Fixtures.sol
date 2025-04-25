// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { WETH, WSTETH, PYTH_ETH_USD } from "@smardex-usdn-contracts-1/test/utils/Constants.sol";
import { IUsdnProtocol } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";
import { Wusdn } from "@smardex-usdn-contracts-1/src/Usdn/Wusdn.sol";
import { Usdn } from "@smardex-usdn-contracts-1/src/Usdn/Usdn.sol";
import { UsdnNoRebase } from "@smardex-usdn-contracts-1/src/Usdn/UsdnNoRebase.sol";
import { UsdnProtocolBaseIntegrationFixture } from
    "@smardex-usdn-contracts-1/test/integration/UsdnProtocol/utils/Fixtures.sol";
import { UsdnProtocolUtilsLibrary as Utils } from
    "@smardex-usdn-contracts-1/src/UsdnProtocol/libraries/UsdnProtocolUtilsLibrary.sol";
import { WusdnToEthOracleMiddlewareWithPyth } from
    "@smardex-usdn-contracts-1/src/OracleMiddleware/WusdnToEthOracleMiddlewareWithPyth.sol";
import { PermitSignature } from "permit2/test/utils/PermitSignature.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { PriceInfo } from "@smardex-usdn-contracts-1/src/interfaces/OracleMiddleware/IOracleMiddlewareTypes.sol";
import { Rebalancer } from "@smardex-usdn-contracts-1/src/Rebalancer/Rebalancer.sol";

import { UniversalRouterHandler } from "../../utils/Handler.sol";
import { MockToken } from "../../utils/MockToken.sol";

import { RouterParameters } from "../../../../src/base/RouterImmutables.sol";
import { ISmardexFactory } from "../../../../src/interfaces/smardex/ISmardexFactory.sol";

/**
 * @title UniversalRouterUsdnShortProtocolBaseFixture
 * @dev Utils for testing the universal router for usdn
 */
contract UniversalRouterUsdnShortProtocolBaseFixture is Test, PermitSignature, IUsdnProtocolTypes {
    uint256 internal constant SIG_USER1_PK = 1;
    address internal sigUser1 = vm.addr(SIG_USER1_PK);
    UniversalRouterHandler internal router;
    IAllowanceTransfer internal permit2;
    uint256 internal maxLeverage;
    uint256 internal constant INITIAL_SDEX_BALANCE = 100_000_000 ether;
    IUsdnProtocol internal protocol;
    WusdnToEthOracleMiddlewareWithPyth oracleMiddleware;
    IERC20Metadata internal asset;
    IERC20Metadata internal sdex;
    UsdnNoRebase internal usdn;
    uint128 internal initialPrice;
    uint128 internal minLongPosition;
    address internal usdnShortDeployer;

    PreviousActionsData internal EMPTY_PREVIOUS_DATA =
        PreviousActionsData({ priceData: new bytes[](0), rawIndices: new uint128[](0) });

    function _setUp() public virtual {
        string memory url = vm.rpcUrl("tenderly");
        vm.createSelectFork(url, 22_280_955);

        protocol = IUsdnProtocol(0xda97775826AC9F997f42bB804BdB5BAF93080382);

        RouterParameters memory params = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: WETH,
            v2Factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
            v3Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            pairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, // v2 pair hash
            poolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, // v3 pool hash
            usdnProtocol: protocol,
            wstEth: WSTETH,
            wusdn: Wusdn(address(0)),
            smardexFactory: ISmardexFactory(0xB878DC600550367e14220d4916Ff678fB284214F)
        });

        router = new UniversalRouterHandler(params);

        usdn = UsdnNoRebase(address(protocol.getUsdn()));
        Rebalancer rebalancer = Rebalancer(payable(0xCe16b62B19E6E64815A3631EfbDBb3F4312a6Db9));
        usdnShortDeployer = rebalancer.owner();
        permit2 = IAllowanceTransfer(params.permit2);
        maxLeverage = protocol.getMaxLeverage();
        minLongPosition = uint128(protocol.getMinLongPosition());
        asset = protocol.getAsset();
        sdex = protocol.getSdex();
        oracleMiddleware = WusdnToEthOracleMiddlewareWithPyth(address(protocol.getOracleMiddleware()));

        (,,, uint256 timestamp, bytes memory data) = getHermesApiSignature(PYTH_ETH_USD, block.timestamp);
        uint256 validationCost = oracleMiddleware.validationCost(data, ProtocolAction.InitiateOpenPosition);
        PriceInfo memory price = oracleMiddleware.parseAndValidatePrice{ value: validationCost }(
            "", uint128(timestamp), ProtocolAction.InitiateOpenPosition, data
        );
        initialPrice = uint128(price.neutralPrice);

        deal(address(this), 10_000 ether);
        deal(address(asset), address(this), minLongPosition * 100);
        deal(address(sdex), address(this), INITIAL_SDEX_BALANCE);

        deal(sigUser1, 10_000 ether);
        deal(address(asset), sigUser1, minLongPosition * 100);
        deal(address(sdex), sigUser1, INITIAL_SDEX_BALANCE);
    }

    function getHermesApiSignature(bytes32 feed, uint256 timestamp)
        internal
        returns (uint256 price_, uint256 conf_, uint256 decimals_, uint256 timestamp_, bytes memory data_)
    {
        bytes memory result = vmFFIRustCommand("pyth-price", vm.toString(feed), vm.toString(timestamp));

        require(keccak256(result) != keccak256(""), "Rust command returned an error");

        return abi.decode(result, (uint256, uint256, uint256, uint256, bytes));
    }

    function _waitDelay() internal {
        skip(oracleMiddleware.getValidationDelay() + 1);
    }

    /**
     * @notice Call the test_utils rust command via vm.ffi
     * @dev You need to run `cargo build --release` at the root of the repo before executing your test
     * @param commandName The name of the command to call
     * @param parameter1 The first parameter for the command
     * @param parameter2 The second parameter for the command
     * @param parameter3 The third parameter for the command
     */
    function vmFFIRustCommand(
        string memory commandName,
        string memory parameter1,
        string memory parameter2,
        string memory parameter3
    ) internal returns (bytes memory result_) {
        return vmFFIRustCommand(commandName, parameter1, parameter2, parameter3, "");
    }

    /**
     * @notice Call the test_utils rust command via vm.ffi
     * @dev You need to run `cargo build --release` at the root of the repo before executing your test
     * @param commandName The name of the command to call
     * @param parameter1 The first parameter for the command
     * @param parameter2 The second parameter for the command
     * @param parameter3 The third parameter for the command
     * @param parameter4 The fourth parameter for the command
     */
    function vmFFIRustCommand(
        string memory commandName,
        string memory parameter1,
        string memory parameter2,
        string memory parameter3,
        string memory parameter4
    ) internal returns (bytes memory result_) {
        string[] memory cmds = new string[](6);

        cmds[0] = "./target/release/test_utils";
        cmds[1] = commandName;
        cmds[2] = parameter1;
        cmds[3] = parameter2;
        cmds[4] = parameter3;
        cmds[5] = parameter4;

        // As of now, the first 3 arguments are always used
        uint8 usedParametersCount = 3;
        if (bytes(parameter2).length > 0) ++usedParametersCount;
        if (bytes(parameter3).length > 0) ++usedParametersCount;
        if (bytes(parameter4).length > 0) ++usedParametersCount;

        result_ = _vmFFIRustCommand(cmds, usedParametersCount);
    }

    /**
     * @notice Execute the given command
     * @dev Will shrink the cmds array to a length of `argsCount`
     * @param cmds The different parts of the command to execute
     * @param argsCount The number of used parameters
     */
    function _vmFFIRustCommand(string[] memory cmds, uint8 argsCount) private returns (bytes memory) {
        assembly {
            // shrink the array to avoid passing too many arguments to the command
            mstore(cmds, argsCount)
        }

        return vm.ffi(cmds);
    }

    /**
     * @notice Call the test_utils rust command via vm.ffi
     * @dev You need to run `cargo build --release` at the root of the repo before executing your test
     * @param commandName The name of the command to call
     * @param parameter1 The first parameter for the command
     * @param parameter2 The second parameter for the command
     */
    function vmFFIRustCommand(string memory commandName, string memory parameter1, string memory parameter2)
        internal
        returns (bytes memory)
    {
        return vmFFIRustCommand(commandName, parameter1, parameter2, "");
    }

    function toDepositPendingAction(IUsdnProtocolTypes.PendingAction memory pendingAction)
        internal
        pure
        returns (IUsdnProtocolTypes.DepositPendingAction memory depositPendingAction_)
    {
        assembly {
            depositPendingAction_ := pendingAction
        }
    }

    function toLongPendingAction(IUsdnProtocolTypes.PendingAction memory pendingAction)
        internal
        pure
        returns (IUsdnProtocolTypes.LongPendingAction memory longPendingAction_)
    {
        assembly {
            longPendingAction_ := pendingAction
        }
    }
}
