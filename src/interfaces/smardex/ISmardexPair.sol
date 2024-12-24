// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

// interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface ISmardexPair is IERC20, IERC20Permit {
    /**
     * @notice Swap parameters used by function swap.
     * @param amountCalculated The return amount from getAmountIn/Out is always positive but to avoid too much cast, is
     * int.
     * @param fictiveReserveIn The fictive reserve of the in-token of the pair.
     * @param fictiveReserveOut The fictive reserve of the out-token of the pair.
     * @param priceAverageIn The in-token ratio component of the price average.
     * @param priceAverageOut The out-token ratio component of the price average.
     * @param token0 The address of the token0.
     * @param token1 The address of the token1.
     * @param balanceIn The contract balance of the in-token.
     * @param balanceOut The contract balance of the out-token.
     */
    struct SwapParams {
        int256 amountCalculated;
        uint256 fictiveReserveIn;
        uint256 fictiveReserveOut;
        uint256 priceAverageIn;
        uint256 priceAverageOut;
        address token0;
        address token1;
        uint256 balanceIn;
        uint256 balanceOut;
    }

    /**
     * @notice Emitted at each mint
     * @dev The amount of LP-token sent can be caught using the transfer event of the pair
     * @param sender The address calling the mint function (usually the Router contract)
     * @param to The address that receives the LP-tokens
     * @param amount0 The amount of token0 to be added in liquidity
     * @param amount1 The amount of token1 to be added in liquidity
     */
    event Mint(address indexed sender, address indexed to, uint256 amount0, uint256 amount1);

    /**
     * @notice Emitted at each burn
     * @dev The amount of LP-token sent can be caught using the transfer event of the pair
     * @param sender The address calling the burn function (usually the Router contract)
     * @param to The address that receives the tokens
     * @param amount0 The amount of token0 to be withdrawn
     * @param amount1 The amount of token1 to be withdrawn
     */
    event Burn(address indexed sender, address indexed to, uint256 amount0, uint256 amount1);

    /**
     * @notice Emitted at each swap
     * @dev One of the 2 amount is always negative, the other one is always positive. The positive one is the one that
     * the user send to the contract, the negative one is the one that the contract send to the user.
     * @param sender The address calling the swap function (usually the Router contract)
     * @param to The address that receives the out-tokens
     * @param amount0 The amount of token0 to be swapped
     * @param amount1 The amount of token1 to be swapped
     */
    event Swap(address indexed sender, address indexed to, int256 amount0, int256 amount1);

    /**
     * @notice Emitted each time the fictive reserves are changed (mint, burn, swap)
     * @param reserve0 The new reserve of token0
     * @param reserve1 The new reserve of token1
     * @param fictiveReserve0 The new fictive reserve of token0
     * @param fictiveReserve1 The new fictive reserve of token1
     * @param priceAverage0 The new priceAverage of token0
     * @param priceAverage1 The new priceAverage of token1
     */
    event Sync(
        uint256 reserve0,
        uint256 reserve1,
        uint256 fictiveReserve0,
        uint256 fictiveReserve1,
        uint256 priceAverage0,
        uint256 priceAverage1
    );

    /**
     * @notice Emitted each time feesLP and feesPool are changed
     * @param feesLP The new feesLP
     * @param feesPool The new feesPool
     */
    event FeesChanged(uint256 indexed feesLP, uint256 indexed feesPool);

    /**
     * @notice Get the factory address
     * @return The address of the factory
     */
    function factory() external view returns (address);

    /**
     * @notice Get the token0 address
     * @return The address of the token0
     */
    function token0() external view returns (address);

    /**
     * @notice Get the token1 address
     * @return The address of the token1
     */
    function token1() external view returns (address);

    /**
     * @notice Called once by the factory at time of deployment
     * @param token0 The address of token0
     * @param token1 The address of token1
     * @param feesLP The feesLP numerator
     * @param feesPool The feesPool numerator
     */
    function initialize(address token0, address token1, uint128 feesLP, uint128 feesPool) external;

    /**
     * @notice Return current Reserves of both token in the pair,
     *  corresponding to token balance - pending fees
     * @return reserve0_ The current reserve of token0 - pending fee0
     * @return reserve1_ The current reserve of token1 - pending fee1
     */
    function getReserves() external view returns (uint256 reserve0_, uint256 reserve1_);

    /**
     * @notice Return current fictive reserves of both token in the pair
     * @return fictiveReserve0_ The current fictive reserve of token0
     * @return fictiveReserve1_ The current fictive reserve of token1
     */
    function getFictiveReserves() external view returns (uint256 fictiveReserve0_, uint256 fictiveReserve1_);

    /**
     * @notice Return current pending fees of both token in the pair
     * @return fees0_ The current pending fees of token0
     * @return fees1_ The current pending fees of token1
     */
    function getFeeToAmounts() external view returns (uint256 fees0_, uint256 fees1_);

    /**
     * @notice Return numerators of pair fees, denominator is 1_000_000
     * @return feesLP_ The numerator of fees sent to LP
     * @return feesPool_ The numerator of fees sent to Pool
     */
    function getPairFees() external view returns (uint128 feesLP_, uint128 feesPool_);

    /**
     * @notice Return last updated price average at timestamp of both token in the pair,
     *  read price0Average/price1Average for current price of token0/token1
     * @return priceAverage0_ The current price for token0
     * @return priceAverage1_ The current price for token1
     * @return blockTimestampLast_ The last block timestamp when price was updated
     */
    function getPriceAverage()
        external
        view
        returns (uint256 priceAverage0_, uint256 priceAverage1_, uint256 blockTimestampLast_);

    /**
     * @notice Return current price average of both token in the pair for provided currentTimeStamp
     *  read price0Average/price1Average for current price of token0/token1
     * @param fictiveReserveIn The fictive reserve of the tokenIn
     * @param fictiveReserveOut The fictive reserve of the tokenOut
     * @param priceAverageLastTimestamp The price average of the last timestamp
     * @param priceAverageIn The current price for token0
     * @param priceAverageOut The current price for token1
     * @param currentTimestamp The block timestamp to get price
     * @return priceAverageIn_ The current price for token0
     * @return priceAverageOut_ The current price for token1
     */
    function getUpdatedPriceAverage(
        uint256 fictiveReserveIn,
        uint256 fictiveReserveOut,
        uint256 priceAverageLastTimestamp,
        uint256 priceAverageIn,
        uint256 priceAverageOut,
        uint256 currentTimestamp
    ) external pure returns (uint256 priceAverageIn_, uint256 priceAverageOut_);

    /**
     * @notice Mint lp tokens proportionally of added tokens in balance. Should be called from a contract
     * that makes safety checks like the SmardexRouter
     * @param to The address who will receive minted tokens
     * @param amount0 The amount of token0 to provide
     * @param amount1 The amount of token1 to provide
     * @param payer The address that will be paying the input
     * @return liquidity_ The amount of lp tokens minted and sent to the address defined in parameter
     */
    function mint(address to, uint256 amount0, uint256 amount1, address payer) external returns (uint256 liquidity_);

    /**
     * @notice Burn lp tokens in the balance of the contract. Sends to the defined address the amount of token0 and
     * token1 proportionally of the amount burned. Should be called from a contract that makes safety checks like the
     * SmardexRouter
     * @param to The address who will receive tokens
     * @return amount0_ The amount of token0 sent to the address defined in parameter
     * @return amount1_ The amount of token0 sent to the address defined in parameter
     */
    function burn(address to) external returns (uint256 amount0_, uint256 amount1_);

    /**
     * @notice Swaps tokens. Sends to the defined address the amount of token0 and token1 defined in parameters.
     * Tokens to trade should be already sent in the contract.
     * Swap function will check if the resulted balance is correct with current reserves and reserves fictive.
     * Should be called from a contract that makes safety checks like the SmardexRouter
     * @param to The address who will receive tokens
     * @param zeroForOne The token0 to token1
     * @param amountSpecified The amount of token wanted
     * @param data The used for flash swap, data.length must be 0 for regular swap
     * @return amount0_ The amount0
     * @return amount1_ The amount1
     */
    function swap(address to, bool zeroForOne, int256 amountSpecified, bytes calldata data)
        external
        returns (int256 amount0_, int256 amount1_);

    /**
     * @notice Set feesLP and feesPool of the pair
     * @dev The sum of new feesLp and feesPool must be <= 100_000
     * @param feesLP The new numerator of fees sent to LP, must be >= 1
     * @param feesPool The new numerator of fees sent to Pool, could be = 0
     */
    function setFees(uint128 feesLP, uint128 feesPool) external;

    /**
     * @notice Withdraw all reserve on the pair in case no liquidity has never been provided
     * @param to The address who will receive tokens
     */
    function skim(address to) external;
}
