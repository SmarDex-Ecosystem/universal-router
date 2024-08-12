#!/usr/bin/env bash
# Path of the script folder (so that the script can be invoked from somewhere else than the project's root)
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

pushd $SCRIPT_DIR/..
pushd lib/usdn-contracts/

npm ci
forge soldeer install

script/deployFork.sh

popd
npm ci
forge soldeer install

export USDN=$(cat lib/usdn-contracts/broadcast/02_Deploy.s.sol/"$FORK_CHAIN_ID"/run-latest.json | jq -r '.returns.Usdn_.value')
export USDN_PROTOCOL=$(cat lib/usdn-contracts/broadcast/02_Deploy.s.sol/"$FORK_CHAIN_ID"/run-latest.json | jq -r '.returns.UsdnProtocol_.value')

script/deployFork.sh

popd
