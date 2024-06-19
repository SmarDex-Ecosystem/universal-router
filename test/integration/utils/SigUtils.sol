// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";

contract SigUtils is Test {
    bytes32 internal immutable _domainSeparator;

    constructor(bytes32 domainSeparator) {
        _domainSeparator = domainSeparator;
    }

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
    function getTypedDataHash(Permit memory _permit) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator, getStructHash(_permit)));
    }

    function signPermit(uint256 _userPrivKey, address _spender, uint256 _value, uint256 _nonce, uint256 deadline)
        external
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: vm.addr(_userPrivKey),
            spender: _spender,
            value: _value,
            nonce: _nonce,
            deadline: deadline
        });
        bytes32 digest = getTypedDataHash(permit);
        return vm.sign(_userPrivKey, digest);
    }

    // force ignore from coverage report
    // until https://github.com/foundry-rs/foundry/issues/2988 is fixed
    function test() public { }
}
