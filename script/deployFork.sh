#!/usr/bin/env bash
# Path of the script folder (so that the script can be invoked from somewhere else than the project's root)
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

# Anvil RPC URL
RPC_URL=http://localhost:8545
# Anvil first test private key
DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Setup deployment script environment variables
export ETHERSCAN_API_KEY=XXXXXXXXXXXXXXXXX # not needed but needs to exist

export DEPLOYER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export SDEX_ADDRESS=0x5de8ab7e27f6e7a1fff3e5b337584aa43961beef
export WSTETH_ADDRESS=0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
export WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
export PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3
export UNISWAP_V2_FACTORY=0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
export UNISWAP_V3_FACTORY=0x1F98431c8aD98523631AE4a59f267346ea31F984
export UNISWAP_PAIR_INIT_HASH=0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f
export UNISWAP_POOL_INIT_HASH=0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54
export SMARDEX_FACTORY=0xB878DC600550367e14220d4916Ff678fB284214F

export HERMES_RA2_NODE_URL="https://hermes.pyth.network/"

export USDN=
export USDN_PROTOCOL=

# Execute in the context of the project's root
pushd $SCRIPT_DIR/..

forge script --non-interactive --private-key $DEPLOYER_PRIVATE_KEY -f $RPC_URL ./script/DeployRouter.s.sol:DeployRouter --broadcast

popd
