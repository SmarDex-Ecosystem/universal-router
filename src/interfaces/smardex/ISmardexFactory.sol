// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

interface ISmardexFactory {
    /**
     * @notice Emitted at each SmardexPair created
     * @param token0 The address of the token0
     * @param token1 The address of the token1
     * @param pair The address of the SmardexPair created
     * @param totalPair The number of SmardexPair created so far
     */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 totalPair);

    /**
     * @notice Emitted at each SmardexPair manually added
     * @param token0 The address of the token0
     * @param token1 The address of the token1
     * @param pair The address of the SmardexPair created
     * @param totalPair The number of SmardexPair created so far
     */
    event PairAdded(address indexed token0, address indexed token1, address pair, uint256 totalPair);

    /**
     * @notice Emitted each time feesLP and feesPool are changed
     * @param feesLP The new feesLP
     * @param feesPool The new feesPool
     */
    event FeesChanged(uint256 indexed feesLP, uint256 indexed feesPool);

    /**
     * @notice Emitted when the feeTo is updated
     * @param previousFeeTo The previous feeTo address
     * @param newFeeTo The new feeTo address
     */
    event FeeToUpdated(address indexed previousFeeTo, address indexed newFeeTo);

    /**
     * @notice Return the address fees will be transferred
     * @return Which the address fees will be transferred
     */
    function feeTo() external view returns (address);

    /**
     * @notice Get the pair address of 2 tokens
     * @param tokenA The token A of the pair
     * @param tokenB The token B of the pair
     * @return pair_ The address of the pair of 2 tokens
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair_);

    /**
     * @notice Return the address of the pair at index
     * @param index The index of the pair
     * @return pair_ The address of the pair
     */
    function allPairs(uint256 index) external view returns (address pair_);

    /**
     * @notice Get the quantity of pairs
     * @return The quantity of pairs
     */
    function allPairsLength() external view returns (uint256);

    /**
     * @notice Return numerators of pair fees, denominator is 1_000_000
     * @return feesLP_ The numerator of fees sent to LP at pair creation
     * @return feesPool_ The numerator of fees sent to Pool at pair creation
     */
    function getDefaultFees() external view returns (uint128 feesLP_, uint128 feesPool_);

    /**
     * @notice Whether whitelist is open
     * @return open_ True if the whitelist is open, false otherwise
     */
    function whitelistOpen() external view returns (bool open_);

    /**
     * @notice Create pair with 2 address
     * @param tokenA The address of tokenA
     * @param tokenB The address of tokenB
     * @return pair_ The address of the pair created
     */
    function createPair(address tokenA, address tokenB) external returns (address pair_);

    /**
     * @notice Set the address who will receive fees, can only be call by the owner
     * @param feeTo The address to replace
     */
    function setFeeTo(address feeTo) external;

    /**
     * @notice Set feesLP and feesPool for each new pair (onlyOwner)
     * @notice The sum of new feesLp and feesPool must be <= FEES_MAX = 10% FEES_BASE
     * @param feesLP The new numerator of fees sent to LP, must be >= 1
     * @param feesPool The new numerator of fees sent to Pool, could be = 0
     */
    function setFees(uint128 feesLP, uint128 feesPool) external;

    /**
     * @notice Disable whitelist (onlyOwner)
     * whitelist cannot be re-opened after that.
     */
    function closeWhitelist() external;

    /**
     * @notice Add a pair manually
     * @param pair The pair address to add (must be an ISmardexPair)
     */
    function addPair(address pair) external;
}
