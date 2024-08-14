// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract SigUtils {
    /**
     * @notice A struct that represents a permit
     * @param owner The owner of the tokens
     * @param spender The spender
     * @param value The amount of tokens
     * @param nonce The nonce of the permit
     * @param deadline The deadline of the permit
     */
    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    /// @dev EIP712 domain separator
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @notice Returns the EIP712 permit signature
     * @param owner The owner of the tokens
     * @param spender The spender
     * @param value The amount of tokens
     * @param nonce The nonce of the permit
     * @param deadline The deadline of the permit
     * @param domainSeparator The domain separator of the token
     */
    function _getDigest(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        bytes32 domainSeparator
    ) internal pure returns (bytes32) {
        Permit memory permit =
            Permit({ owner: owner, spender: spender, value: value, nonce: nonce, deadline: deadline });
        return _getTypedDataHash(permit, domainSeparator);
    }

    /**
     * @dev computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the
     * signer
     * @param permit The permit struct
     * @param domainSeparator The domain separator of the token
     */
    function _getTypedDataHash(Permit memory permit, bytes32 domainSeparator) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, _getStructHash(permit)));
    }

    /// @dev computes the hash of a permit
    function _getStructHash(Permit memory permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(PERMIT_TYPEHASH, permit.owner, permit.spender, permit.value, permit.nonce, permit.deadline)
        );
    }
}
