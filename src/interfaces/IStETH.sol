// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface IStETH is IERC20Metadata, IERC20Permit {
    /// @notice The operation failed because the contract is paused
    error EnforcedPause();

    /// @notice The operation failed because the contract is not paused
    error ExpectedPause();

    /**
     * @notice Service event for initialization
     * @param eip712StETH The EIP712 helper contract for StETH
     */
    event EIP712StETHInitialized(address eip712StETH);

    /**
     * @notice Emitted when the pause is triggered by `account`
     * @param account The caller address
     */
    event Paused(address account);

    /**
     * @notice Emitted when the pause is lifted by `account`
     * @param account The caller address
     */
    event Unpaused(address account);

    /**
     * @notice An executed shares transfer from `sender` to `recipient`
     * @dev Emitted in pair with an ERC20-defined `Transfer` event
     * @param from The from address
     * @param to The to address
     * @param sharesValue The amount of transferred shares
     */
    event TransferShares(address indexed from, address indexed to, uint256 sharesValue);

    /**
     * @notice An executed `burnShares` request
     * @dev Reports simultaneously burnt shares amount
     * and corresponding stETH amount
     * The stETH amount is calculated twice: before and after the burning incurred rebase.
     * @param account The holder of the burnt shares
     * @param preRebaseTokenAmount The amount of stETH the burnt shares corresponded to before the burn
     * @param postRebaseTokenAmount The amount of stETH the burnt shares corresponded to after the burn
     * @param sharesAmount The amount of burnt shares
     */
    event SharesBurnt(
        address indexed account, uint256 preRebaseTokenAmount, uint256 postRebaseTokenAmount, uint256 sharesAmount
    );

    /**
     * @notice Get the sum of all ETH balances in the protocol
     * @dev Equals to the total supply of stETH
     * @return The entire amount of Ether controlled by the protocol
     */
    function getTotalPooledEther() external view returns (uint256);

    /**
     * @notice Atomically increases the allowance granted to `_spender` by the caller by `_addedValue`
     * @dev This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
     * Emits an `Approval` event indicating the updated allowance
     * Requirements:
     * - `_spender` cannot be the the zero address
     * @param _spender The token spender
     * @param _addedValue The token allowance amount to add
     * @return Whether the call is successful
     */
    function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool);

    /**
     * @notice Atomically decreases the allowance granted to `_spender` by the caller by `_subtractedValue`
     * @dev This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
     * Emits an `Approval` event indicating the updated allowance
     * Requirements:
     * - `_spender` cannot be the zero address
     * - `_spender` must have allowance for the caller of at least `_subtractedValue`
     * @param _spender The token spender
     * @param _subtractedValue The token allowance amount to subtract
     * @return Whether the call is successful
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool);

    /**
     * @notice Get the total amount of shares
     * @dev The sum of all accounts' shares can be an arbitrary number, therefore
     * it is necessary to store it in order to calculate each account's relative share
     * @return The total amount of shares in existence
     */
    function getTotalShares() external view returns (uint256);

    /**
     * @notice Get the stEth shares of an address
     * @param _account The _account address
     * @return The amount of shares owned by `_account`
     */
    function sharesOf(address _account) external view returns (uint256);

    /**
     * @notice Get the amount of shares by protocol-controlled Ether
     * @return The amount of shares that corresponds to `_ethAmount` protocol-controlled Ether
     */
    function getSharesByPooledEth(uint256 _ethAmount) external view returns (uint256);

    /**
     * @notice Get the amount of protocol-controlled Ether by shares
     * @return The amount of Ether that corresponds to `_sharesAmount` token shares
     */
    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);

    /**
     * @notice Moves `_sharesAmount` token shares from the caller's account to the `_recipient` account
     * @dev The `_sharesAmount` argument is the amount of shares, not tokens
     * Emits a `TransferShares` event
     * Emits a `Transfer` event
     * Requirements:
     * - `_recipient` cannot be the zero address
     * - the caller must have at least `_sharesAmount` shares
     * - the contract must not be paused
     * @param _recipient The recipient address
     * @param _sharesAmount The shares amount
     * @return The amount of transferred tokens
     */
    function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256);

    /**
     * @notice Moves `_sharesAmount` token shares from the `_sender` account to the `_recipient` account
     * @dev The `_sharesAmount` argument is the amount of shares, not tokens
     * Emits a `TransferShares` event
     * Emits a `Transfer` event
     * Requirements:
     * - `_sender` and `_recipient` cannot be the zero addresses
     * - `_sender` must have at least `_sharesAmount` shares
     * - the caller must have allowance for `_sender`'s tokens of at least `getPooledEthByShares(_sharesAmount)`
     * - the contract must not be paused
     * @param _sender The sender address
     * @param _recipient The recipient address
     * @param _sharesAmount The shares amount
     * @return The amount of transferred tokens
     */
    function transferSharesFrom(address _sender, address _recipient, uint256 _sharesAmount)
        external
        returns (uint256);

    /**
     * @notice Get whether the contract is paused
     * @return The `pause` value, true if the contract is paused, and false otherwise
     */
    function paused() external returns (bool);

    /**
     * @notice Get the EIP712 domain values
     * @dev returns the fields and values that describe the domain separator used by this contract for EIP712
     * signature
     * NB: comparing to the full-fledged ERC-5267 version:
     * - `salt` and `extensions` are unused
     * - `flags` is hex"0f" or 01111b
     * using shortened returns to reduce a bytecode size
     * @return name The domain name
     * @return version The domain version
     * @return chainId The domain chainId
     * @return verifyingContract The domain contract address
     */
    function eip712Domain()
        external
        view
        returns (string memory name, string memory version, uint256 chainId, address verifyingContract);
}
