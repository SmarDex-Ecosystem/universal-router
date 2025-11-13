// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Wusdn } from "@smardex-usdn-contracts-1/src/Usdn/Wusdn.sol";
import {
    UsdnProtocolUtilsLibrary as Utils
} from "@smardex-usdn-contracts-1/src/UsdnProtocol/libraries/UsdnProtocolUtilsLibrary.sol";
import { IUsdnProtocol } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocol.sol";
import {
    UsdnProtocolBaseIntegrationFixture
} from "@smardex-usdn-contracts-1/test/integration/UsdnProtocol/utils/Fixtures.sol";
import { DEPLOYER, WETH, WSTETH } from "@smardex-usdn-contracts-1/test/utils/Constants.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { PermitSignature } from "permit2/test/utils/PermitSignature.sol";

import { UniversalRouterHandler } from "./Handler.sol";
import { MockToken } from "./MockToken.sol";

import { RouterParameters } from "../../../src/base/RouterImmutables.sol";
import { ISmardexFactory } from "../../../src/interfaces/smardex/ISmardexFactory.sol";

/**
 * @title UniversalRouterBaseFixture
 * @dev Utils for testing the Universal Router
 */
contract UniversalRouterBaseFixture is UsdnProtocolBaseIntegrationFixture, PermitSignature {
    modifier prankUser(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    uint256 internal constant SIG_USER1_PK = 1;
    address internal sigUser1 = vm.addr(SIG_USER1_PK);
    UniversalRouterHandler public router;
    IAllowanceTransfer permit2;
    AggregatorV3Interface public priceFeed;
    Wusdn internal wusdn;
    uint256 internal maxLeverage;
    ISmardexFactory smardexFactory;
    uint256 internal constant INITIAL_SDEX_BALANCE = 100_000_000 ether;

    IERC20 internal token0;
    IERC20 internal token1;
    IERC20 internal token2;

    function _setUp(SetUpParams memory setupParams) public virtual override {
        setupParams.fork = true;
        setupParams.initialDeposit = 1000 ether;
        setupParams.initialLong = 1000 ether;
        super._setUp(setupParams);

        wusdn = new Wusdn(usdn);

        RouterParameters memory params = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: WETH,
            v2Factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
            v3Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            pairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, // v2 pair hash
            poolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, // v3 pool hash
            usdnProtocol: IUsdnProtocol(address(protocol)),
            wstEth: WSTETH,
            wusdn: wusdn,
            smardexFactory: ISmardexFactory(0xB878DC600550367e14220d4916Ff678fB284214F),
            ensoV2Router: 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559
        });

        vm.prank(DEPLOYER);
        router = new UniversalRouterHandler(params);

        permit2 = IAllowanceTransfer(params.permit2);
        priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        smardexFactory = params.smardexFactory;
        maxLeverage = protocol.getMaxLeverage();

        token0 = new MockToken();
        token1 = new MockToken();
        token2 = new MockToken();
    }

    /**
     * @notice get the first next chainlink price after the pending action timestamp
     * @dev binary search to find the first roundId after the pending action timestamp,
     * revert if roundId is not the first one after the low latency limit. This function
     * make a rollFork to the block where the roundId is found and return the roundId, price and timestamp
     */
    function getNextChainlinkPriceAfterTimestamp(uint256 pendingActionTimestamp, uint256 startBlock, uint256 endBlock)
        public
        returns (uint80 roundId_, int256 price_, uint256 timestamp_)
    {
        uint256 lowLatencyLimit = pendingActionTimestamp + oracleMiddleware.getLowLatencyDelay();
        // set the search range
        uint256 left = startBlock;
        uint256 right = endBlock;

        // perform binary search
        while (left < right) {
            uint256 mid = (left + right) / 2;
            vm.rollFork(mid);
            (roundId_,,, timestamp_,) = priceFeed.latestRoundData();

            if (timestamp_ < lowLatencyLimit) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }

        // final fork roll to the first round after the low latency limit
        vm.rollFork(left);
        (roundId_, price_,, timestamp_,) = priceFeed.latestRoundData();

        // ensure roundId is first one after the low latency limit
        (,, uint256 updateAtOne,,) = priceFeed.getRoundData(roundId_ - 1);
        (,, uint256 updateAtTwo,,) = priceFeed.getRoundData(roundId_);
        assertTrue(updateAtOne < lowLatencyLimit, "updateAtOne < lowLatencyLimit");
        assertTrue(updateAtTwo >= lowLatencyLimit, "updateAtTwo >= lowLatencyLimit");
        return (roundId_, price_, timestamp_);
    }

    /// @dev Calculate the amount of SDEX to burn
    function _calcSdexToBurn(uint256 depositAmount) internal view returns (uint256 sdexToBurn_) {
        uint128 lastPrice = protocol.getLastPrice();
        uint128 timestamp = protocol.getLastUpdateTimestamp();
        (, sdexToBurn_) = protocol.previewDeposit(depositAmount, lastPrice, timestamp);
    }
}
