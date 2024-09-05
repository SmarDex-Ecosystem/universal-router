// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { DEPLOYER, WETH, WSTETH } from "usdn-contracts/test/utils/Constants.sol";
import { Wusdn } from "usdn-contracts/src/Usdn/Wusdn.sol";
import { UsdnProtocolBaseIntegrationFixture } from "usdn-contracts/test/integration/UsdnProtocol/utils/Fixtures.sol";

import { UniversalRouterHandler } from "./Handler.sol";
import { RouterParameters } from "../../../src/base/RouterImmutables.sol";
import { ISmardexFactory } from "../../../src/interfaces/smardex/ISmardexFactory.sol";

/**
 * @title UniversalRouterBaseFixture
 * @dev Utils for testing the Universal Router
 */
contract UniversalRouterBaseFixture is UsdnProtocolBaseIntegrationFixture {
    UniversalRouterHandler public router;
    IAllowanceTransfer permit2;
    AggregatorV3Interface public priceFeed;
    Wusdn internal wusdn;

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
            usdnProtocol: protocol,
            wstEth: WSTETH,
            wusdn: wusdn,
            smardexFactory: ISmardexFactory(0xB878DC600550367e14220d4916Ff678fB284214F)
        });

        vm.prank(DEPLOYER);
        router = new UniversalRouterHandler(params);

        permit2 = IAllowanceTransfer(params.permit2);
        priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
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
}
