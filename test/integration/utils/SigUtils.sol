// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";

import { UsdnProtocolConstantsLibrary as Constants } from
    "@smardex-usdn-contracts-1/src/UsdnProtocol/libraries/UsdnProtocolConstantsLibrary.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SigUtils is Test {
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

    /**
     * @notice A struct to use with `_getInitiateCloseDelegationSignature`
     * @param posIdHash The position id hash
     * @param amountToClose The position amountToClose
     * @param userMinPrice The position userMinPrice
     * @param to The position to
     * @param deadline The position deadline
     * @param positionOwner The position owner
     * @param positionCloser The position closer
     * @param nonce The position owner nonce
     */
    struct InitiateClosePositionDelegation {
        bytes32 posIdHash;
        uint128 amountToClose;
        uint256 userMinPrice;
        address to;
        uint256 deadline;
        address positionOwner;
        address positionCloser;
        uint256 nonce;
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

    /**
     * @notice Get the signature to perform a delegated initiate close position
     * @param privateKey The signer private key
     * @param domainSeparator The domain separator v4
     * @param delegationToSign The delegation struct to sign
     * @return delegationSignature_ The initiateClosePosition eip712 delegation signature
     */
    function _getInitiateCloseDelegationSignature(
        uint256 privateKey,
        bytes32 domainSeparator,
        InitiateClosePositionDelegation memory delegationToSign
    ) internal pure returns (bytes memory delegationSignature_) {
        bytes32 digest = MessageHashUtils.toTypedDataHash(
            domainSeparator,
            keccak256(
                abi.encode(
                    Constants.INITIATE_CLOSE_TYPEHASH,
                    delegationToSign.posIdHash,
                    delegationToSign.amountToClose,
                    delegationToSign.userMinPrice,
                    delegationToSign.to,
                    delegationToSign.deadline,
                    delegationToSign.positionOwner,
                    delegationToSign.positionCloser,
                    delegationToSign.nonce
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        delegationSignature_ = abi.encodePacked(r, s, v);
    }
}
