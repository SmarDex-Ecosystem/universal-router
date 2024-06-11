#!/usr/bin/env bash
# Path of the script folder (so that the script can be invoked from somewhere else than the project's root)
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

# Anvil RPC URL
RPC_URL=http://localhost:8545
# Anvil first test private key
DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Setup deployment script environment variables
export DEPLOYER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export ETHERSCAN_API_KEY=XXXXXXXXXXXXXXXXX # not needed but needs to exist

# Execute in the context of the project's root
pushd $SCRIPT_DIR/..

forge script --non-interactive --private-key $DEPLOYER_PRIVATE_KEY -f $RPC_URL script/Deploy.s.sol:Deploy --broadcast

popd
