#!/usr/bin/env bash
# Path of the script folder (so that the script can be invoked from somewhere else than the project's root)
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

pushd $SCRIPT_DIR/.. > /dev/null

# Deploy USDN contracts
pushd lib/usdn-contracts/ > /dev/null

npm ci
forge soldeer install

script/deployFork.sh

popd  > /dev/null

# Deploy Router
npm ci
forge soldeer install

rpcUrl=http://localhost:8545
deployerPrivateKey=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
chainId=$(cast chain-id -r "$rpcUrl")

export WUSDN_ADDRESS=$(cat dependencies/usdn-contracts/broadcast/01_Deploy.s.sol/"$chainId"/run-latest.json | jq -r '.returns.Wusdn_.value')
export USDN_PROTOCOL_ADDRESS=$(cat lib/usdn-contracts/broadcast/01_Deploy.s.sol/"$chainId"/run-latest.json | jq -r '.returns.UsdnProtocol_.value')

forge script --via-ir --non-interactive --private-key "$deployerPrivateKey" -f "$rpcUrl" script/01_Deploy.s.sol:Deploy --broadcast

popd  > /dev/null
