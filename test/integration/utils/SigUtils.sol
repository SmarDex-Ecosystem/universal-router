// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract SigUtils {
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    // computes the hash of a permit
    function getStructHash(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline)
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Permit memory _permit, bytes32 domainSeparator) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, getStructHash(_permit)));
    }

    function getDigest(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 deadline,
        bytes32 domainSeparator
    ) external pure returns (bytes32) {
        SigUtils.Permit memory permit =
            SigUtils.Permit({ owner: _owner, spender: _spender, value: _value, nonce: _nonce, deadline: deadline });
        return getTypedDataHash(permit, domainSeparator);
    }

    // force ignore from coverage report
    // until https://github.com/foundry-rs/foundry/issues/2988 is fixed
    function test() public { }
}
