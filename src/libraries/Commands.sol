// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

/**
 * @title Commands Library
 * @notice Command Flags used to decode commands.
 */
library Commands {
    // masks to extract certain bits of commands
    bytes1 internal constant FLAG_ALLOW_REVERT = 0x80;
    bytes1 internal constant COMMAND_TYPE_MASK = 0x3f;

    uint256 constant V3_SWAP_EXACT_IN = 0x00;
    uint256 constant V3_SWAP_EXACT_OUT = 0x01;
    uint256 constant PERMIT2_TRANSFER_FROM = 0x02;
    uint256 constant PERMIT2_PERMIT_BATCH = 0x03;
    uint256 constant SWEEP = 0x04;
    uint256 constant TRANSFER = 0x05;
    uint256 constant PAY_PORTION = 0x06;
    // COMMAND_PLACEHOLDER from 0x07 to 0x0f (all unused)

    // the commands are executed in nested if blocks to minimize gas consumption
    // the following constant defines one of the boundaries where the if blocks split commands
    uint256 constant FIRST_IF_BOUNDARY = 0x10;

    uint256 constant V2_SWAP_EXACT_IN = 0x10;
    uint256 constant V2_SWAP_EXACT_OUT = 0x11;
    uint256 constant PERMIT2_PERMIT = 0x12;
    uint256 constant WRAP_ETH = 0x13;
    uint256 constant UNWRAP_WETH = 0x14;
    uint256 constant PERMIT2_TRANSFER_FROM_BATCH = 0x15;
    uint256 constant PERMIT = 0x16;
    uint256 constant TRANSFER_FROM = 0x17;
    // COMMAND_PLACEHOLDER from 0x18 to 0x1f (all unused)

    // the commands are executed in nested if blocks to minimize gas consumption
    // the following constant defines one of the boundaries where the if blocks split commands
    uint256 constant SECOND_IF_BOUNDARY = 0x20;

    uint256 constant INITIATE_DEPOSIT = 0x20;
    uint256 constant INITIATE_WITHDRAWAL = 0x21;
    uint256 constant INITIATE_OPEN = 0x22;
    uint256 constant INITIATE_CLOSE = 0x23;
    uint256 constant VALIDATE_DEPOSIT = 0x24;
    uint256 constant VALIDATE_WITHDRAWAL = 0x25;
    uint256 constant VALIDATE_OPEN = 0x26;
    uint256 constant VALIDATE_CLOSE = 0x27;
    uint256 constant LIQUIDATE = 0x28;
    uint256 constant TRANSFER_POSITION_OWNERSHIP = 0x29;
    uint256 constant VALIDATE_PENDING = 0x2a;
    uint256 constant REBALANCER_INITIATE_DEPOSIT = 0x2b;
    uint256 constant REBALANCER_INITIATE_CLOSE = 0x2c;
    // COMMAND_PLACEHOLDER from 0x2d to 0x2f (all unused)

    // the commands are executed in nested if blocks to minimize gas consumption
    // the following constant defines one of the boundaries where the if blocks split commands
    uint256 constant THIRD_IF_BOUNDARY = 0x30;

    uint256 constant WRAP_USDN = 0x30;
    uint256 constant UNWRAP_WUSDN = 0x31;
    uint256 constant WRAP_STETH = 0x32;
    uint256 constant UNWRAP_WSTETH = 0x33;
    uint256 constant USDN_TRANSFER_SHARES_FROM = 0x34;
    // COMMAND_PLACEHOLDER from 0x35 to 0x37 (all unused)

    // the commands are executed in nested if blocks to minimize gas consumption
    // the following constant defines one of the boundaries where the if blocks split commands
    uint256 constant FOURTH_IF_BOUNDARY = 0x38;

    uint256 constant SMARDEX_SWAP_EXACT_IN = 0x38;
    uint256 constant SMARDEX_SWAP_EXACT_OUT = 0x39;
    uint256 constant SMARDEX_ADD_LIQUIDITY = 0x3a;
    // COMMAND_PLACEHOLDER from 0x3b to 0x3f (all unused)
}
