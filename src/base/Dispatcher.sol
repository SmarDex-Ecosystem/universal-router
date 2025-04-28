// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { Payments } from "@uniswap/universal-router/contracts/modules/Payments.sol";
import { BytesLib } from "@uniswap/universal-router/contracts/modules/uniswap/v3/BytesLib.sol";
import { V3SwapRouter } from "@uniswap/universal-router/contracts/modules/uniswap/v3/V3SwapRouter.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { IUsdnProtocolTypes } from "@smardex-usdn-contracts-1/src/interfaces/UsdnProtocol/IUsdnProtocolTypes.sol";

import { IUsdnProtocolRouterTypes } from "../interfaces/usdn/IUsdnProtocolRouterTypes.sol";
import { IPaymentLibTypes } from "../interfaces/usdn/IPaymentLibTypes.sol";
import { ISmardexRouter } from "../interfaces/smardex/ISmardexRouter.sol";
import { Commands } from "../libraries/Commands.sol";
import { UsdnProtocolRouterLib } from "../libraries/usdn/UsdnProtocolRouterLib.sol";
import { SmardexRouterLib } from "../libraries/smardex/SmardexRouterLib.sol";
import { LidoRouterLib } from "../libraries/lido/LidoRouterLib.sol";
import { UniswapV2RouterLib } from "../libraries/uniswap/UniswapV2RouterLib.sol";
import { LidoImmutables } from "../modules/lido/LidoImmutables.sol";
import { SmardexRouter } from "../modules/smardex/SmardexRouter.sol";
import { UsdnProtocolRouter } from "../modules/usdn/UsdnProtocolRouter.sol";
import { Sweep } from "../modules/Sweep.sol";
import { LockAndMap } from "../modules/usdn/LockAndMap.sol";

/**
 * @title Decodes and Executes Commands
 * @notice Called by the UniversalRouter contract to efficiently decode and execute a singular command
 */
abstract contract Dispatcher is
    Payments,
    Sweep,
    V3SwapRouter,
    SmardexRouter,
    LockAndMap,
    UsdnProtocolRouter,
    LidoImmutables
{
    using BytesLib for bytes;

    /**
     * @notice Indicates that the command type is invalid
     * @param commandType The command type
     */
    error InvalidCommandType(uint256 commandType);

    /// @notice Indicates that the USDN token does not have a wrapped version
    error NoWusdn();

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
                            uint256 amountOutThreshold;
                            assembly {
                                token := calldataload(inputs.offset)
                                recipient := calldataload(add(inputs.offset, 0x20))
                                amountOutMin := calldataload(add(inputs.offset, 0x40))
                                amountOutThreshold := calldataload(add(inputs.offset, 0x60))
                            }
                            Sweep.sweep(token, map(recipient), amountOutMin, amountOutThreshold);
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
                            UniswapV2RouterLib.v2SwapExactInput(
                                UNISWAP_V2_FACTORY,
                                UNISWAP_V2_PAIR_INIT_CODE_HASH,
                                PERMIT2,
                                map(recipient),
                                amountIn,
                                amountOutMin,
                                path,
                                payer
                            );
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
                            UniswapV2RouterLib.v2SwapExactOutput(
                                UNISWAP_V2_FACTORY,
                                UNISWAP_V2_PAIR_INIT_CODE_HASH,
                                PERMIT2,
                                map(recipient),
                                amountOut,
                                amountInMax,
                                path,
                                payer
                            );
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
                            uint256 amount;
                            assembly {
                                recipient := calldataload(inputs.offset)
                                amount := calldataload(add(inputs.offset, 0x20))
                            }
                            Payments.wrapETH(map(recipient), amount);
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
                            (IAllowanceTransfer.AllowanceTransferDetails[] memory batchDetails) =
                                abi.decode(inputs, (IAllowanceTransfer.AllowanceTransferDetails[]));
                            permit2TransferFrom(batchDetails, lockedBy);
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
                        } else if (command == Commands.TRANSFER_FROM) {
                            // equivalent:  abi.decode(inputs, (address, address, uint256))
                            address token;
                            address recipient;
                            uint256 amount;
                            assembly {
                                token := calldataload(inputs.offset)
                                recipient := calldataload(add(inputs.offset, 0x20))
                                amount := calldataload(add(inputs.offset, 0x40))
                            }

                            (success_, output_) = token.call(
                                abi.encodeWithSelector(IERC20.transferFrom.selector, lockedBy, map(recipient), amount)
                            );
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
                        IUsdnProtocolRouterTypes.InitiateDepositData memory data =
                            abi.decode(inputs, (IUsdnProtocolRouterTypes.InitiateDepositData));
                        data.to = _mapSafe(data.to);
                        data.validator = _mapSafe(data.validator);
                        UsdnProtocolRouterLib.usdnInitiateDeposit(PROTOCOL_ASSET, USDN_PROTOCOL, data);
                    } else if (command == Commands.INITIATE_WITHDRAWAL) {
                        (
                            IPaymentLibTypes.PaymentType payment,
                            uint256 usdnShares,
                            uint256 amountOutMin,
                            address to,
                            address validator,
                            uint256 deadline,
                            bytes memory currentPriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(
                            inputs,
                            (
                                IPaymentLibTypes.PaymentType,
                                uint256,
                                uint256,
                                address,
                                address,
                                uint256,
                                bytes,
                                IUsdnProtocolTypes.PreviousActionsData,
                                uint256
                            )
                        );
                        UsdnProtocolRouterLib.usdnInitiateWithdrawal(
                            USDN,
                            USDN_PROTOCOL,
                            payment,
                            usdnShares,
                            amountOutMin,
                            _mapSafe(to),
                            _mapSafe(validator),
                            deadline,
                            currentPriceData,
                            previousActionsData,
                            ethAmount
                        );
                    } else if (command == Commands.INITIATE_OPEN) {
                        IUsdnProtocolRouterTypes.InitiateOpenPositionData memory data =
                            abi.decode(inputs, (IUsdnProtocolRouterTypes.InitiateOpenPositionData));
                        data.to = _mapSafe(data.to);
                        data.validator = _mapSafe(data.validator);
                        UsdnProtocolRouterLib.usdnInitiateOpenPosition(PROTOCOL_ASSET, USDN_PROTOCOL, data);
                    } else if (command == Commands.INITIATE_CLOSE) {
                        (IUsdnProtocolRouterTypes.InitiateClosePositionData memory data) =
                            abi.decode(inputs, (IUsdnProtocolRouterTypes.InitiateClosePositionData));
                        (success_, output_) = address(USDN_PROTOCOL).call{ value: data.ethAmount }(
                            abi.encodeWithSelector(
                                USDN_PROTOCOL.initiateClosePosition.selector,
                                data.posId,
                                data.amountToClose,
                                data.userMinPrice,
                                _mapSafe(data.to),
                                payable(_mapSafe(data.validator)),
                                data.deadline,
                                data.currentPriceData,
                                data.previousActionsData,
                                data.delegationSignature
                            )
                        );
                    } else if (command == Commands.VALIDATE_DEPOSIT) {
                        (
                            address validator,
                            bytes memory depositPriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(inputs, (address, bytes, IUsdnProtocolTypes.PreviousActionsData, uint256));
                        UsdnProtocolRouterLib.usdnValidateDeposit(
                            USDN_PROTOCOL, map(validator), depositPriceData, previousActionsData, ethAmount
                        );
                    } else if (command == Commands.VALIDATE_WITHDRAWAL) {
                        (
                            address validator,
                            bytes memory withdrawalPriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(inputs, (address, bytes, IUsdnProtocolTypes.PreviousActionsData, uint256));
                        UsdnProtocolRouterLib.usdnValidateWithdrawal(
                            USDN_PROTOCOL, map(validator), withdrawalPriceData, previousActionsData, ethAmount
                        );
                    } else if (command == Commands.VALIDATE_OPEN) {
                        (
                            address validator,
                            bytes memory depositPriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(inputs, (address, bytes, IUsdnProtocolTypes.PreviousActionsData, uint256));
                        UsdnProtocolRouterLib.usdnValidateOpenPosition(
                            USDN_PROTOCOL, map(validator), depositPriceData, previousActionsData, ethAmount
                        );
                    } else if (command == Commands.VALIDATE_CLOSE) {
                        (
                            address validator,
                            bytes memory closePriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 ethAmount
                        ) = abi.decode(inputs, (address, bytes, IUsdnProtocolTypes.PreviousActionsData, uint256));
                        UsdnProtocolRouterLib.usdnValidateClosePosition(
                            USDN_PROTOCOL, map(validator), closePriceData, previousActionsData, ethAmount
                        );
                    } else if (command == Commands.LIQUIDATE) {
                        // equivalent: abi.decode(inputs, (bytes, uint256))
                        uint256 ethAmount;
                        assembly {
                            // 0x00 offset is the currentPriceData, decoded below
                            ethAmount := calldataload(add(inputs.offset, 0x20))
                        }
                        bytes memory currentPriceData = inputs.toBytes(0);
                        UsdnProtocolRouterLib.usdnLiquidate(USDN_PROTOCOL, currentPriceData, ethAmount);
                    } else if (command == Commands.VALIDATE_PENDING) {
                        (
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            uint256 maxValidations,
                            uint256 ethAmount
                        ) = abi.decode(inputs, (IUsdnProtocolTypes.PreviousActionsData, uint256, uint256));
                        UsdnProtocolRouterLib.usdnValidateActionablePendingActions(
                            USDN_PROTOCOL, previousActionsData, maxValidations, ethAmount
                        );
                    } else if (command == Commands.TRANSFER_POSITION_OWNERSHIP) {
                        (IUsdnProtocolTypes.PositionId memory posId, address newOwner, bytes memory delegationSignature)
                        = abi.decode(inputs, (IUsdnProtocolTypes.PositionId, address, bytes));
                        (success_, output_) = address(USDN_PROTOCOL).call(
                            abi.encodeWithSelector(
                                USDN_PROTOCOL.transferPositionOwnership.selector,
                                posId,
                                _mapSafe(newOwner),
                                delegationSignature
                            )
                        );
                    } else if (command == Commands.REBALANCER_INITIATE_DEPOSIT) {
                        // equivalent: abi.decode(inputs, (uint256, address))
                        uint256 amount;
                        address to;
                        assembly {
                            amount := calldataload(inputs.offset)
                            to := calldataload(add(inputs.offset, 0x20))
                        }
                        (success_, output_) =
                            UsdnProtocolRouterLib.rebalancerInitiateDeposit(USDN_PROTOCOL, amount, _mapSafe(to));
                    } else if (command == Commands.REBALANCER_INITIATE_CLOSE) {
                        (
                            uint88 amount,
                            address to,
                            address validator,
                            uint256 userMinPrice,
                            uint256 deadline,
                            bytes memory currentPriceData,
                            IUsdnProtocolTypes.PreviousActionsData memory previousActionsData,
                            bytes memory delegationData,
                            uint256 ethAmount
                        ) = abi.decode(
                            inputs,
                            (
                                uint88,
                                address,
                                address,
                                uint256,
                                uint256,
                                bytes,
                                IUsdnProtocolTypes.PreviousActionsData,
                                bytes,
                                uint256
                            )
                        );
                        (success_, output_) = UsdnProtocolRouterLib.rebalancerInitiateClosePosition(
                            USDN_PROTOCOL,
                            amount,
                            _mapSafe(to),
                            payable(_mapSafe(validator)),
                            userMinPrice,
                            deadline,
                            currentPriceData,
                            previousActionsData,
                            delegationData,
                            ethAmount
                        );
                    } else {
                        revert InvalidCommandType(command);
                    }
                }
            } else {
                if (command == Commands.WRAP_USDN) {
                    if (address(WUSDN) == address(0)) {
                        revert NoWusdn();
                    }
                    // equivalent: abi.decode(inputs, (uint256, address))
                    uint256 usdnSharesAmount;
                    address recipient;
                    assembly {
                        usdnSharesAmount := calldataload(inputs.offset)
                        recipient := calldataload(add(inputs.offset, 0x20))
                    }
                    UsdnProtocolRouterLib.wrapUSDNShares(USDN, WUSDN, usdnSharesAmount, map(recipient));
                } else if (command == Commands.UNWRAP_WUSDN) {
                    if (address(WUSDN) == address(0)) {
                        revert NoWusdn();
                    }
                    // equivalent: abi.decode(inputs, (uint256, address))
                    uint256 wusdnAmount;
                    address recipient;
                    assembly {
                        wusdnAmount := calldataload(inputs.offset)
                        recipient := calldataload(add(inputs.offset, 0x20))
                    }
                    UsdnProtocolRouterLib.unwrapUSDN(WUSDN, wusdnAmount, map(recipient));
                } else if (command == Commands.WRAP_STETH) {
                    // equivalent: abi.decode(inputs, (uint256, address))
                    uint256 stethAmount;
                    address recipient;
                    assembly {
                        stethAmount := calldataload(inputs.offset)
                        recipient := calldataload(add(inputs.offset, 0x20))
                    }
                    success_ = LidoRouterLib.wrapSTETH(STETH, WSTETH, stethAmount, map(recipient));
                } else if (command == Commands.UNWRAP_WSTETH) {
                    // equivalent: abi.decode(inputs, (uint256, address))
                    uint256 wstethAmount;
                    address recipient;
                    assembly {
                        wstethAmount := calldataload(inputs.offset)
                        recipient := calldataload(add(inputs.offset, 0x20))
                    }
                    success_ = LidoRouterLib.unwrapWSTETH(STETH, WSTETH, wstethAmount, map(recipient));
                } else if (command == Commands.USDN_TRANSFER_SHARES_FROM) {
                    // equivalent:  abi.decode(inputs, (address, uint256))
                    address recipient;
                    uint256 sharesAmount;
                    assembly {
                        recipient := calldataload(inputs.offset)
                        sharesAmount := calldataload(add(inputs.offset, 0x20))
                    }
                    (success_, output_) = address(USDN).call(
                        abi.encodeWithSelector(USDN.transferSharesFrom.selector, lockedBy, map(recipient), sharesAmount)
                    );
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
            } else if (command == Commands.SMARDEX_ADD_LIQUIDITY) {
                (ISmardexRouter.AddLiquidityParams memory params, address to, bool payerIsUser, uint256 deadline) =
                    abi.decode(inputs, (ISmardexRouter.AddLiquidityParams, address, bool, uint256));
                address payer = payerIsUser ? lockedBy : address(this);
                (success_, output_) = SmardexRouterLib.addLiquidity(SMARDEX_FACTORY, params, map(to), payer, deadline);
            } else if (command == Commands.SMARDEX_REMOVE_LIQUIDITY) {
                (ISmardexRouter.RemoveLiquidityParams memory params, address to, bool payerIsUser, uint256 deadline) =
                    abi.decode(inputs, (ISmardexRouter.RemoveLiquidityParams, address, bool, uint256));
                address payer = payerIsUser ? lockedBy : address(this);
                (success_, output_) =
                    SmardexRouterLib.removeLiquidity(SMARDEX_FACTORY, PERMIT2, params, map(to), payer, deadline);
            } else {
                revert InvalidCommandType(command);
            }
        }
    }
}
