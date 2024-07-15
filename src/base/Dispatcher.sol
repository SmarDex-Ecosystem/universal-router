// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { LockAndMsgSender } from "@uniswap/universal-router/contracts/base/LockAndMsgSender.sol";
import { Payments } from "@uniswap/universal-router/contracts/modules/Payments.sol";
import { BytesLib } from "@uniswap/universal-router/contracts/modules/uniswap/v3/BytesLib.sol";
import { V3SwapRouter } from "@uniswap/universal-router/contracts/modules/uniswap/v3/V3SwapRouter.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { IUsdnProtocolTypes } from "usdn-contracts/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";
import { Permit2TokenBitfield } from "usdn-contracts/src/libraries/Permit2TokenBitfield.sol";

import { Commands } from "../libraries/Commands.sol";
import { Sweep } from "../libraries/Sweep.sol";
import { V2SwapRouter } from "../modules/uniswap/v2/V2SwapRouter.sol";
import { UsdnProtocolRouter } from "../modules/usdn/UsdnProtocolRouter.sol";
import { LidoRouter } from "../modules/lido/LidoRouter.sol";
import { SmardexSwapRouter } from "../modules/smardex/SmardexSwapRouter.sol";

/**
 * @title Decodes and Executes Commands
 * @notice Called by the UniversalRouter contract to efficiently decode and execute a singular command
 */
abstract contract Dispatcher is
    Payments,
    V2SwapRouter,
    V3SwapRouter,
    UsdnProtocolRouter,
    LidoRouter,
    SmardexSwapRouter,
    LockAndMsgSender
{
    using BytesLib for bytes;

    /**
     * @notice Indicates that the command type is invalid
     * @param commandType The command type
     */
    error InvalidCommandType(uint256 commandType);

    /**
     * @notice Decodes and executes the given command with the given inputs
     * @dev 2 masks are used to enable use of a nested-if statement in execution for efficiency reasons
     * @param commandType The command type to execute
     * @param inputs The inputs to execute the command with
     * @return success_ True on success of the command, false on failure
     * @return output_ The outputs or error messages, if any, from the command
     */
    function dispatch(bytes1 commandType, bytes calldata inputs)
        internal
        returns (bool success_, bytes memory output_)
    {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);

        success_ = true;

        if (command < Commands.FOURTH_IF_BOUNDARY) {
            if (command < Commands.THIRD_IF_BOUNDARY) {
                if (command < Commands.SECOND_IF_BOUNDARY) {
                    if (command < Commands.FIRST_IF_BOUNDARY) {
                        if (command == Commands.V3_SWAP_EXACT_IN) {
                            // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                            address recipient;
                            uint256 amountIn;
                            uint256 amountOutMin;
                            bool payerIsUser;
                            assembly {
                                recipient := calldataload(inputs.offset)
                                amountIn := calldataload(add(inputs.offset, 0x20))
                                amountOutMin := calldataload(add(inputs.offset, 0x40))
                                // 0x60 offset is the path, decoded below
                                payerIsUser := calldataload(add(inputs.offset, 0x80))
                            }
                            bytes calldata path = inputs.toBytes(3);
                            address payer = payerIsUser ? lockedBy : address(this);
                            v3SwapExactInput(map(recipient), amountIn, amountOutMin, path, payer);
                        } else if (command == Commands.V3_SWAP_EXACT_OUT) {
                            // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                            address recipient;
                            uint256 amountOut;
                            uint256 amountInMax;
                            bool payerIsUser;
                            assembly {
                                recipient := calldataload(inputs.offset)
                                amountOut := calldataload(add(inputs.offset, 0x20))
                                amountInMax := calldataload(add(inputs.offset, 0x40))
                                // 0x60 offset is the path, decoded below
                                payerIsUser := calldataload(add(inputs.offset, 0x80))
                            }
                            bytes calldata path = inputs.toBytes(3);
                            address payer = payerIsUser ? lockedBy : address(this);
                            v3SwapExactOutput(map(recipient), amountOut, amountInMax, path, payer);
                        } else if (command == Commands.PERMIT2_TRANSFER_FROM) {
                            // equivalent: abi.decode(inputs, (address, address, uint160))
                            address token;
                            address recipient;
                            uint160 amount;
                            assembly {
                                token := calldataload(inputs.offset)
                                recipient := calldataload(add(inputs.offset, 0x20))
                                amount := calldataload(add(inputs.offset, 0x40))
                            }
                            permit2TransferFrom(token, lockedBy, map(recipient), amount);
                        } else if (command == Commands.PERMIT2_PERMIT_BATCH) {
                            (IAllowanceTransfer.PermitBatch memory permitBatch,) =
                                abi.decode(inputs, (IAllowanceTransfer.PermitBatch, bytes));
                            bytes calldata data = inputs.toBytes(1);
                            PERMIT2.permit(lockedBy, permitBatch, data);
                        } else if (command == Commands.SWEEP) {
                            // equivalent:  abi.decode(inputs, (address, address, uint256, uint256))
                            address token;
                            address recipient;
                            uint256 amountOutMin;
                            uint256 amountTokenThreshold;
                            assembly {
                                token := calldataload(inputs.offset)
                                recipient := calldataload(add(inputs.offset, 0x20))
                                amountOutMin := calldataload(add(inputs.offset, 0x40))
                                amountTokenThreshold := calldataload(add(inputs.offset, 0x60))
                            }
                            Sweep.sweep(token, map(recipient), amountOutMin, amountTokenThreshold);
                        } else if (command == Commands.TRANSFER) {
                            // equivalent:  abi.decode(inputs, (address, address, uint256))
                            address token;
                            address recipient;
                            uint256 value;
                            assembly {
                                token := calldataload(inputs.offset)
                                recipient := calldataload(add(inputs.offset, 0x20))
                                value := calldataload(add(inputs.offset, 0x40))
                            }
                            Payments.pay(token, map(recipient), value);
                        } else if (command == Commands.PAY_PORTION) {
                            // equivalent:  abi.decode(inputs, (address, address, uint256))
                            address token;
                            address recipient;
                            uint256 bips;
                            assembly {
                                token := calldataload(inputs.offset)
                                recipient := calldataload(add(inputs.offset, 0x20))
                                bips := calldataload(add(inputs.offset, 0x40))
                            }
                            Payments.payPortion(token, map(recipient), bips);
                        } else {
                            revert InvalidCommandType(command);
                        }
                    } else {
                        if (command == Commands.V2_SWAP_EXACT_IN) {
                            // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                            address recipient;
                            uint256 amountIn;
                            uint256 amountOutMin;
                            bool payerIsUser;
                            assembly {
                                recipient := calldataload(inputs.offset)
                                amountIn := calldataload(add(inputs.offset, 0x20))
                                amountOutMin := calldataload(add(inputs.offset, 0x40))
                                // 0x60 offset is the path, decoded below
                                payerIsUser := calldataload(add(inputs.offset, 0x80))
                            }
                            address[] calldata path = inputs.toAddressArray(3);
                            address payer = payerIsUser ? lockedBy : address(this);
                            v2SwapExactInput(map(recipient), amountIn, amountOutMin, path, payer);
                        } else if (command == Commands.V2_SWAP_EXACT_OUT) {
                            // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                            address recipient;
                            uint256 amountOut;
                            uint256 amountInMax;
                            bool payerIsUser;
                            assembly {
                                recipient := calldataload(inputs.offset)
                                amountOut := calldataload(add(inputs.offset, 0x20))
                                amountInMax := calldataload(add(inputs.offset, 0x40))
                                // 0x60 offset is the path, decoded below
                                payerIsUser := calldataload(add(inputs.offset, 0x80))
                            }
                            address[] calldata path = inputs.toAddressArray(3);
                            address payer = payerIsUser ? lockedBy : address(this);
                            v2SwapExactOutput(map(recipient), amountOut, amountInMax, path, payer);
                        } else if (command == Commands.PERMIT2_PERMIT) {
                            // equivalent: abi.decode(inputs, (IAllowanceTransfer.PermitSingle, bytes))
                            IAllowanceTransfer.PermitSingle calldata permitSingle;
                            assembly {
                                permitSingle := inputs.offset
                            }
                            bytes calldata data = inputs.toBytes(6); // permitSingle takes first 6 slots (0..5)
                            PERMIT2.permit(lockedBy, permitSingle, data);
                        } else if (command == Commands.WRAP_ETH) {
                            // equivalent: abi.decode(inputs, (address, uint256))
                            address recipient;
                            uint256 amountMin;
                            assembly {
                                recipient := calldataload(inputs.offset)
                                amountMin := calldataload(add(inputs.offset, 0x20))
                            }
                            Payments.wrapETH(map(recipient), amountMin);
                        } else if (command == Commands.UNWRAP_WETH) {
                            // equivalent: abi.decode(inputs, (address, uint256))
                            address recipient;
                            uint256 amountMin;
                            assembly {
                                recipient := calldataload(inputs.offset)
                                amountMin := calldataload(add(inputs.offset, 0x20))
                            }
                            Payments.unwrapWETH9(map(recipient), amountMin);
                        } else if (command == Commands.PERMIT2_TRANSFER_FROM_BATCH) {
                            // TODO PERMIT2_TRANSFER_FROM_BATCH
                        } else if (command == Commands.PERMIT) {
                            /*
                                equivalent: abi.decode(
                                    inputs, (
                                        address, 
                                        address, 
                                        address, 
                                        uint256, 
                                        uint256, 
                                        uint8,
                                        bytes32,
                                        bytes32
                                    )
                                )
                            */
                            address token;
                            address owner;
                            address spender;
                            uint256 amount;
                            uint256 deadline;
                            uint8 v;
                            bytes32 r;
                            bytes32 s;
                            assembly {
                                token := calldataload(inputs.offset)
                                owner := calldataload(add(inputs.offset, 0x20))
                                spender := calldataload(add(inputs.offset, 0x40))
                                amount := calldataload(add(inputs.offset, 0x60))
                                deadline := calldataload(add(inputs.offset, 0x80))
                                v := calldataload(add(inputs.offset, 0xa0))
                                r := calldataload(add(inputs.offset, 0xc0))
                                s := calldataload(add(inputs.offset, 0xe0))
                            }
                            // protect against griefing
                            (success_, output_) = token.call(
                                abi.encodeWithSelector(
                                    IERC20Permit.permit.selector, owner, spender, amount, deadline, v, r, s
                                )
                            );
                        } else if (command == Commands.PERMIT_TRANSFER_FROM) {
                            /*
                                equivalent: abi.decode(
                                    inputs, (
                                        address, 
                                        address, 
                                        address, 
                                        uint256, 
                                        uint256, 
                                        uint8,
                                        bytes32,
                                        bytes32
                                    )
                                )
                            */
                            address token;
                            address owner;
                            address spender;
                            uint256 amount;
                            uint256 deadline;
                            uint8 v;
                            bytes32 r;
                            bytes32 s;
                            assembly {
                                token := calldataload(inputs.offset)
                                owner := calldataload(add(inputs.offset, 0x20))
                                spender := calldataload(add(inputs.offset, 0x40))
                                amount := calldataload(add(inputs.offset, 0x60))
                                deadline := calldataload(add(inputs.offset, 0x80))
                                v := calldataload(add(inputs.offset, 0xa0))
                                r := calldataload(add(inputs.offset, 0xc0))
                                s := calldataload(add(inputs.offset, 0xe0))
                            }
                            (success_, output_) = token.call(
                                abi.encodeWithSelector(
                                    IERC20Permit.permit.selector, owner, spender, amount, deadline, v, r, s
                                )
                            );
                            // slither-disable-next-line unchecked-transfer,arbitrary-send-erc20
                            IERC20(token).transferFrom(owner, spender, amount);
                        } else {
                            revert InvalidCommandType(command);
                        }
                    }
                } else {
                    // comment for the eights actions(INITIATE and VALIDATE) of the USDN protocol
                    // we don't allow the transaction to revert if the actions was not successful (due to pending
                    // liquidations), so we ignore the success boolean. This is because it's important to perform
                    // liquidations if they are needed, and it would be a big waste of gas for the user to revert
                    if (command == Commands.INITIATE_DEPOSIT) {
                        (
                            uint256 amount,
                            address to,
                            address validator,
                            Permit2TokenBitfield.Bitfield permit2TokenBitfield,
                            bytes memory currentPriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(
                            inputs,
                            (
                                uint256,
                                address,
                                address,
                                Permit2TokenBitfield.Bitfield,
                                bytes,
                                IUsdnProtocolTypes.PreviousActionsData,
                                uint256
                            )
                        );
                        _usdnInitiateDeposit(
                            amount,
                            map(to),
                            map(validator),
                            permit2TokenBitfield,
                            currentPriceData,
                            previousActionsData,
                            ethAmount
                        );
                    } else if (command == Commands.INITIATE_WITHDRAWAL) {
                        (
                            uint256 usdnShares,
                            address to,
                            address validator,
                            bytes memory currentPriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(
                            inputs, (uint256, address, address, bytes, IUsdnProtocolTypes.PreviousActionsData, uint256)
                        );
                        _usdnInitiateWithdrawal(
                            usdnShares, map(to), map(validator), currentPriceData, previousActionsData, ethAmount
                        );
                    } else if (command == Commands.INITIATE_OPEN) {
                        (
                            uint256 amount,
                            uint128 desiredLiqPrice,
                            address to,
                            address validator,
                            Permit2TokenBitfield.Bitfield permit2TokenBitfield,
                            bytes memory currentPriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(
                            inputs,
                            (
                                uint256,
                                uint128,
                                address,
                                address,
                                Permit2TokenBitfield.Bitfield,
                                bytes,
                                IUsdnProtocolTypes.PreviousActionsData,
                                uint256
                            )
                        );
                        _usdnInitiateOpenPosition(
                            amount,
                            desiredLiqPrice,
                            map(to),
                            map(validator),
                            permit2TokenBitfield,
                            currentPriceData,
                            previousActionsData,
                            ethAmount
                        );
                    } else if (command == Commands.VALIDATE_DEPOSIT) {
                        (
                            address validator,
                            bytes memory depositPriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(inputs, (address, bytes, IUsdnProtocolTypes.PreviousActionsData, uint256));
                        _usdnValidateDeposit(map(validator), depositPriceData, previousActionsData, ethAmount);
                    } else if (command == Commands.VALIDATE_WITHDRAWAL) {
                        (
                            address validator,
                            bytes memory withdrawalPriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(inputs, (address, bytes, IUsdnProtocolTypes.PreviousActionsData, uint256));
                        _usdnValidateWithdrawal(map(validator), withdrawalPriceData, previousActionsData, ethAmount);
                    } else if (command == Commands.VALIDATE_OPEN) {
                        (
                            address validator,
                            bytes memory depositPriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(inputs, (address, bytes, IUsdnProtocolTypes.PreviousActionsData, uint256));
                        _usdnValidateOpenPosition(map(validator), depositPriceData, previousActionsData, ethAmount);
                    } else if (command == Commands.VALIDATE_CLOSE) {
                        (
                            address validator,
                            bytes memory closePriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(inputs, (address, bytes, IUsdnProtocolTypes.PreviousActionsData, uint256));
                        _usdnValidateClosePosition(map(validator), closePriceData, previousActionsData, ethAmount);
                    } else if (command == Commands.LIQUIDATE) {
                        // equivalent: abi.decode(inputs, (bytes, uint16, uint256))
                        uint16 iterations;
                        uint256 ethAmount;
                        assembly {
                            // 0x00 offset is the currentPriceData, decoded below
                            iterations := calldataload(add(inputs.offset, 0x20))
                            ethAmount := calldataload(add(inputs.offset, 0x40))
                        }
                        bytes memory currentPriceData = inputs.toBytes(0);
                        _usdnLiquidate(currentPriceData, iterations, ethAmount);
                    } else if (command == Commands.VALIDATE_PENDING) {
                        (
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 maxValidations,
                            uint256 ethAmount
                        ) = abi.decode(inputs, (IUsdnProtocolTypes.PreviousActionsData, uint256, uint256));
                        _usdnValidateActionablePendingActions(previousActionsData, maxValidations, ethAmount);
                    } else {
                        revert InvalidCommandType(command);
                    }
                }
            } else {
                if (command == Commands.WRAP_USDN) {
                    // equivalent: abi.decode(inputs, (uint256, address))
                    uint256 usdnSharesAmount;
                    address recipient;
                    assembly {
                        usdnSharesAmount := calldataload(inputs.offset)
                        recipient := calldataload(add(inputs.offset, 0x20))
                    }
                    _wrapUSDNShares(usdnSharesAmount, map(recipient));
                } else if (command == Commands.UNWRAP_WUSDN) {
                    // equivalent: abi.decode(inputs, (uint256, address))
                    uint256 wusdnAmount;
                    address recipient;
                    assembly {
                        wusdnAmount := calldataload(inputs.offset)
                        recipient := calldataload(add(inputs.offset, 0x20))
                    }
                    _unwrapUSDN(wusdnAmount, map(recipient));
                } else if (command == Commands.WRAP_STETH) {
                    // equivalent: abi.decode(inputs, address)
                    address recipient;
                    assembly {
                        recipient := calldataload(inputs.offset)
                    }
                    success_ = LidoRouter._wrapSTETH(map(recipient));
                } else if (command == Commands.UNWRAP_WSTETH) {
                    // equivalent: abi.decode(inputs, address)
                    address recipient;
                    assembly {
                        recipient := calldataload(inputs.offset)
                    }
                    success_ = LidoRouter._unwrapSTETH(map(recipient));
                } else {
                    revert InvalidCommandType(command);
                }
            }
        } else {
            if (command == Commands.SMARDEX_SWAP_EXACT_IN) {
                // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                address recipient;
                uint256 amountIn;
                uint256 amountOutMin;
                bool payerIsUser;
                assembly {
                    recipient := calldataload(inputs.offset)
                    amountIn := calldataload(add(inputs.offset, 0x20))
                    amountOutMin := calldataload(add(inputs.offset, 0x40))
                    // 0x60 offset is the path, decoded below
                    payerIsUser := calldataload(add(inputs.offset, 0x80))
                }
                bytes calldata path = inputs.toBytes(3);
                address payer = payerIsUser ? lockedBy : address(this);
                _smardexSwapExactInput(map(recipient), amountIn, amountOutMin, path, payer);
            } else if (command == Commands.SMARDEX_SWAP_EXACT_OUT) {
                // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                address recipient;
                uint256 amountOut;
                uint256 amountInMax;
                bool payerIsUser;
                assembly {
                    recipient := calldataload(inputs.offset)
                    amountOut := calldataload(add(inputs.offset, 0x20))
                    amountInMax := calldataload(add(inputs.offset, 0x40))
                    // 0x60 offset is the path, decoded below
                    payerIsUser := calldataload(add(inputs.offset, 0x80))
                }
                bytes calldata path = inputs.toBytes(3);
                address payer = payerIsUser ? lockedBy : address(this);
                _smardexSwapExactOutput(map(recipient), amountOut, amountInMax, path, payer);
            } else {
                revert InvalidCommandType(command);
            }
        }
    }
}
