# <h1 align="center">Universal Router</h1>

[![Main workflow](https://github.com/SmarDex-Ecosystem/universal-router/actions/workflows/ci.yml/badge.svg)](https://github.com/SmarDex-Ecosystem/universal-router/actions/workflows/ci.yml)
[![Release Workflow](https://github.com/SmarDex-Ecosystem/universal-router/actions/workflows/release.yml/badge.svg)](https://github.com/SmarDex-Ecosystem/universal-router/actions/workflows/release.yml)

## Contract Overview

The Universal Router codebase consists of the `UniversalRouter` contract, and all of its dependencies. The purpose of the `UniversalRouter` is to allow users to execute a series of commands in a single transaction. This is achieved by encoding the commands and their inputs into a single transaction, which is then executed by the `UniversalRouter` contract.

`UniversalRouter` integrates with [Permit2](https://github.com/Uniswap/permit2), to enable users to have more safety, flexibility, and control over their ERC20 token approvals.

### UniversalRouter command encoding

Calls to `UniversalRouter.execute`, the entrypoint to the contracts, provide 2 main parameters:

- `bytes commands`: A bytes string. Each individual byte represents 1 command that the transaction will execute.
- `bytes[] inputs`: An array of bytes strings. Each element in the array is the encoded parameters for a command.

`commands[i]` is the command that will use `inputs[i]` as its encoded input parameters.

Through function overloading there is also an optional third parameter for the `execute` function:

- `uint256 deadline`: The timestamp deadline by which this transaction must be executed. Transactions executed after this specified deadline will revert.

#### How the command byte is structured

Each command is a `bytes1` containing the following 8 bits:

```
 0 1 2 3 4 5 6 7
┌─┬─┬───────────┐
│f│r|  command  │
└─┴─┴───────────┘
```

- `f` is a single bit flag, that signals whether or not the command should be allowed to revert. If `f` is `false`, and the command reverts, then the entire transaction will revert. If `f` is `true` and the command reverts then the transaction will continue, allowing us to achieve partial fills. If using this flag, be careful to include further commands that will remove any funds that could be left unused in the `UniversalRouter` contract.

- `r` is one bit of reserved space. This will allow us to increase the space used for commands, or add new flags in future.

- `command` is a 6 bit unique identifier for the command that should be carried out. The values of these commands can be found within Commands.sol, or can be viewed in the table below.

```
   ┌──────┬───────────────────────────────┐
   │ 0x00 │  V3_SWAP_EXACT_IN             │
   ├──────┼───────────────────────────────┤
   │ 0x01 │  V3_SWAP_EXACT_OUT            │
   ├──────┼───────────────────────────────┤
   │ 0x02 │  PERMIT2_TRANSFER_FROM        │
   ├──────┼───────────────────────────────┤
   │ 0x03 │  PERMIT2_PERMIT_BATCH         │
   ├──────┼───────────────────────────────┤
   │ 0x04 │  SWEEP                        │
   ├──────┼───────────────────────────────┤
   │ 0x05 │  TRANSFER                     │
   ├──────┼───────────────────────────────┤
   │ 0x06 │  PAY_PORTION                  │
   ├──────┼───────────────────────────────┤
   │ 0x07 │  -------                      │
   ├──────┼───────────────────────────────┤
   │ 0x08 │  V2_SWAP_EXACT_IN             │
   ├──────┼───────────────────────────────┤
   │ 0x09 │  V2_SWAP_EXACT_OUT            │
   ├──────┼───────────────────────────────┤
   │ 0x0a │  PERMIT2_PERMIT               │
   ├──────┼───────────────────────────────┤
   │ 0x0b │  WRAP_ETH                     │
   ├──────┼───────────────────────────────┤
   │ 0x0c │  UNWRAP_WETH                  │
   ├──────┼───────────────────────────────┤
   │ 0x0d │  PERMIT2_TRANSFER_FROM_BATCH  │
   ├──────┼───────────────────────────────┤
   │ 0x0e │  PERMIT                       │
   ├──────┼───────────────────────────────┤
   │ 0x0f │  PERMIT_TRANSFER_FROM         │
   ├──────┼───────────────────────────────┤
   │ 0x10 │  INITIATE_DEPOSIT             │
   ├──────┼───────────────────────────────┤
   │ 0x11 │  INITIATE_WITHDRAWAL          │
   ├──────┼───────────────────────────────┤
   │ 0x12 │  INITIATE_OPEN                │
   ├──────┼───────────────────────────────┤
   │ 0x13 │  VALIDATE_DEPOSIT             │
   ├──────┼───────────────────────────────┤
   │ 0x14 │  VALIDATE_WITHDRAWAL          │
   ├──────┼───────────────────────────────┤
   │ 0x15 │  VALIDATE_OPEN                │
   ├──────┼───────────────────────────────┤
   │ 0x16 │  VALIDATE_CLOSE               │
   ├──────┼───────────────────────────────┤
   │ 0x17 │  LIQUIDATE                    │
   ├──────┼───────────────────────────────┤
   │ 0x18 │  VALIDATE_PENDING             │
   ├──────┼───────────────────────────────┤
   │ 0x19 │  -------                      │
   ├──────┼───────────────────────────────┤
   │ 0x1a │  -------                      │
   ├──────┼───────────────────────────────┤
   │ 0x1b │  WRAP_USDN                    │
   ├──────┼───────────────────────────────┤
   │ 0x1c │  UNWRAP_WUSDN                 │
   ├──────┼───────────────────────────────┤
   │ 0x1d │  WRAP_STETH                   │
   ├──────┼───────────────────────────────┤
   │ 0x1e │  UNWRAP_WSTETH                │
   ├──────┼───────────────────────────────┤
   │ 0x1f │  -------                      │
   ├──────┼───────────────────────────────┤
   │ 0x20 │  SMARDEX_SWAP_EXACT_IN        │
   ├──────┼───────────────────────────────┤
   │ 0x21 │  SMARDEX_SWAP_EXACT_OUT       │
   ├──────┼───────────────────────────────┤
   │ 0x22-│  -------                      │
   │ 0x3f │                               │
   └──────┴───────────────────────────────┘
```

Note that some of the commands in the middle of the series are unused. These gaps allowed us to create gas-efficiencies when selecting which command to execute.

#### How the input bytes are structures

Each input bytes string is merely the abi encoding of a set of parameters. Depending on the command chosen, the input bytes string will be different. For example:

The inputs for `SMARDEX_SWAP_EXACT_IN` is the encoding of 4 parameters:

- `address` The recipient of the output of the trade
- `uint256` The amount of input tokens for the trade
- `uint256` The minimum amount of output tokens the user wants
- `bool` A flag for whether the input funds should come from the caller (through Permit2) or whether the funds are already in the UniversalRouter

Whereas in contrast `WRAP_ETH` has just 2 parameters encoded:

- `address` The recipient of the wrapped ETH
- `uint256` The minimum amount of wrapped ETH the user wants

Encoding parameters in a bytes string in this way gives us maximum flexiblity to be able to support many commands which require different datatypes in a gas-efficient way.

For a more detailed breakdown of which parameters you should provide for each command take a look at the `Dispatcher.dispatch` function, or alternatively at the `ABI_DEFINITION` mapping in `planner.ts`.

Developer documentation to give a detailed explanation of the inputs for every command will be coming soon!

### UniversalRouter workflow commands

You can run a series of commands in a single transaction. The commands are executed in the order they are provided in the `commands` parameter. If a command reverts, the transaction will revert, unless the command has the `f` flag set to `true`.
For example, if you want to make a Deposit in the protocol, you would need to run the following steps: `eth -> wEth`, `wEth -> sdex`,`eth -> wstEth`, `INITIATE_DEPOSIT`, `sweep(wstEth)`, `sweep(sdex)`, `sweep(wEth)`.
If you want to make a OpenPosition in the protocol, you would need to run the following steps: `eth -> wEth`, `INITIATE_OPEN`, `sweep(eth)`, `sweep(wEth)`.

### Commands

Some commands explained :

- `SWEEP` : This command is used to sweep the remaining funds in the UniversalRouter contract to the recipient address. This is useful to ensure that no funds are left in the contract after the transaction is executed. Need to be executed for every token that was sent to the UniversalRouter contract.
- `INITIATE_DEPOSIT` : Initiate a deposit in the protocol. The user must have already sent wsEth and sdex to the UniversalRouter contract.
- `INITIATE_WITHDRAWAL` : Initiate a withdrawal in the protocol. The user must have already sent usdn to the UniversalRouter contract.
- `INITIATE_OPEN` : Initiate an open in the protocol. The user must have already sent wstEth to the UniversalRouter contract.
- `VALIDATE_DEPOSIT` : Validate a deposit in the protocol.
- `VALIDATE_WITHDRAWAL` : Validate a withdrawal in the protocol.
- `VALIDATE_OPEN` : Validate an open in the protocol.

## Installation

### Foundry

To install Foundry, run the following commands in your terminal:

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

### Dependencies

To install existing dependencies, run the following commands:

```bash
forge install
npm install
```

The `forge install` command is only used to add the forge standard library. Other dependencies should be managed with
npm.

In order to add a new dependency, use the `npm i [packagename]` command with any package from the
[npm registry](https://www.npmjs.com/).

For instance, to add the latest [OpenZeppelin library](https://github.com/OpenZeppelin/openzeppelin-contracts):

```bash
npm i @openzeppelin/contracts
```

### Nix

If using [`nix`](https://nixos.org/), the repository provides a development shell in the form of a flake.

The devshell can be activated with the `nix develop` command.

To automatically activate the dev shell when opening the workspace, install [`direnv`](https://direnv.net/)
(available on nixpkgs) and run the following command inside this folder:

```console
direnv allow
```

The environment provides the following tools:

- load `.env` file as environment variables
- foundry
- solc v0.8.20
- slither
- Node 18

## Usage

### Tests

To run tests you need to to build `test_utils`. To do so, we need to run `cargo build --release` at the root of the
repo.
You also need an archive rpc in the`.env` file (infura, alchemy, ...).

### Snapshots

The CI checks that there was no unintended regression in gas usage. To do so, it relies on the `.gas-snapshot` file
which records gas usage for all tests. When tests have changed, a new snapshot should be generated with the
`npm run snapshot` command and commited to the repo.

### Deployment scripts

Deployment for anvil forks should be done with a custom bash script at `script/deployFork.sh` which can be run without
arguments. It must set up any environment variable required by the foundry deployment script.

Common arguments to `forge script` are described in
[the documentation](https://book.getfoundry.sh/reference/forge/forge-script#forge-script).

Notably, the `--rpc-url` argument allows to choose which RPC will receive the transactions. The available shorthand
names are defined in [`foundry.toml`](https://github.com/SmarDex-Ecosystem/universal-router/blob/master/foundry.toml),
(e.g. `mainnet`, `goerli`) and use URLs defined as environment variables (see `.env.example`).

## Foundry Documentation

For comprehensive details on Foundry, refer to the [Foundry book](https://book.getfoundry.sh/).

### Helpful Resources

- [Forge Cheat Codes](https://book.getfoundry.sh/cheatcodes/)
- [Forge Commands](https://book.getfoundry.sh/reference/forge/)
- [Cast Commands](https://book.getfoundry.sh/reference/cast/)

## Code Standards and Tools

### Forge Formatter

Foundry comes with a built-in code formatter that we configured like this (default values were omitted):

```toml
[profile.default.fmt]
line_length = 120 # Max line length
bracket_spacing = true # Spacing the brackets in the code
wrap_comments = true # use max line length for comments as well
number_underscore = "thousands" # add underscore separators in large numbers
```

### Husky

The pre-commit configuration for Husky runs `forge fmt --check` to check the code formatting before each commit. It also
checks the gas snapshot and prevents committing if it has changed.

In order to setup the git pre-commit hook, run `npm install`.

### Slither

Slither is integrated into a GitHub workflow and runs on every push to the master branch.
