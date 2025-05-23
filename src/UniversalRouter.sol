// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import {
    PaymentsImmutables, PaymentsParameters
} from "@uniswap/universal-router/contracts/modules/PaymentsImmutables.sol";
import {
    UniswapImmutables,
    UniswapParameters
} from "@uniswap/universal-router/contracts/modules/uniswap/UniswapImmutables.sol";

import { Dispatcher } from "./base/Dispatcher.sol";
import { RouterParameters } from "./base/RouterImmutables.sol";
import { IUniversalRouter } from "./interfaces/IUniversalRouter.sol";
import { Commands } from "./libraries/Commands.sol";
import { Odos } from "./modules/Odos.sol";
import { LidoImmutables } from "./modules/lido/LidoImmutables.sol";
import { SmardexRouter } from "./modules/smardex/SmardexRouter.sol";
import { UsdnProtocolImmutables, UsdnProtocolParameters } from "./modules/usdn/UsdnProtocolImmutables.sol";

contract UniversalRouter is IUniversalRouter, Dispatcher {
    /**
     * @notice Reverts if the transaction deadline has passed
     * @param deadline The deadline to check
     */
    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert TransactionDeadlinePassed();
        _;
    }

    /**
     * @param params The immutable parameters of the router
     */
    constructor(RouterParameters memory params)
        UniswapImmutables(
            UniswapParameters(params.v2Factory, params.v3Factory, params.pairInitCodeHash, params.poolInitCodeHash)
        )
        PaymentsImmutables(PaymentsParameters(params.permit2, params.weth9, address(0), address(0)))
        UsdnProtocolImmutables(UsdnProtocolParameters(params.usdnProtocol, params.wusdn))
        LidoImmutables(params.wstEth)
        SmardexRouter(params.smardexFactory)
        Odos(params.odosSorRouter)
    { }

    /// @inheritdoc IUniversalRouter
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline)
        external
        payable
        checkDeadline(deadline)
    {
        execute(commands, inputs);
    }

    /// @inheritdoc IUniversalRouter
    function execute(bytes calldata commands, bytes[] calldata inputs) public payable isNotLocked {
        bool success;
        bytes memory output;
        uint256 numCommands = commands.length;
        if (inputs.length != numCommands) {
            revert LengthMismatch();
        }

        // loop through all given commands, execute them and pass along outputs as defined
        for (uint256 commandIndex = 0; commandIndex < numCommands;) {
            bytes1 command = commands[commandIndex];

            bytes calldata input = inputs[commandIndex];

            (success, output) = dispatch(command, input);

            if (!success && successRequired(command)) {
                revert ExecutionFailed({ commandIndex: commandIndex, message: output });
            }

            unchecked {
                commandIndex++;
            }
        }
    }

    /**
     * @notice Verifies if a command requires success or not
     * @param command The command to check
     * @return True if the command requires success, false otherwise
     */
    function successRequired(bytes1 command) internal pure returns (bool) {
        return command & Commands.FLAG_ALLOW_REVERT == 0;
    }

    /// @notice To receive ETH from WETH
    receive() external payable { }
}
