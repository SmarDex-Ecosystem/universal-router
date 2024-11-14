#!/usr/bin/env bash
red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
nc='\033[0m'


# Path of the script folder (so that the script can be invoked from somewhere else than the project's root)
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

# Enter usdn-contracts folder
pushd $SCRIPT_DIR/.. > /dev/null

# Deploy USDN contracts
pushd dependencies/@smardex-usdn-contracts-* > /dev/null
usdnFolder=$(pwd)

npm ci
forge soldeer install

script/deployFork.sh

rpcUrl=http://localhost:8545
deployerPrivateKey=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
chainId=$(cast chain-id -r "$rpcUrl")
broadcastUsdn="$usdnFolder/broadcast/01_Deploy.s.sol/$chainId/run-latest.json"
export DEPLOYER_ADDRESS=$(cast wallet address "$deployerPrivateKey")

printf "$green USDN protocol has been deployed !\n"
sleep 1s

for i in {1..15}; do
    printf "$green Trying to fetch WUSDN address... (attempt $i/15)$nc\n"
    WUSDN_ADDRESS=$(cat "$broadcastUsdn" | jq -r '.returns.Wusdn_.value')
    wusdnCode=$(cast code -r "$rpcUrl" "$WUSDN_ADDRESS")

    if [[ ! -z $wusdnCode ]]; then
        printf "\n$green WUSDN contract found on blockchain$nc\n\n"
        export WUSDN_ADDRESS=$WUSDN_ADDRESS
        export USDN_PROTOCOL_ADDRESS=$(cat "$broadcastUsdn" | jq -r '.returns.UsdnProtocol_.value')
        cat "$usdnFolder/.env.fork" > .env.fork
        break
    fi

    if [ $i -eq 15 ]; then
        printf "\n$red Failed to fetch WUSDN address$nc\n\n"
        exit 1
    fi

    sleep 2s
done

# Enter universal-router folder
popd  > /dev/null

# Deploy Router
# npm ci
# forge soldeer install

forge script --via-ir --non-interactive --private-key "$deployerPrivateKey" -f "$rpcUrl" script/01_Deploy.s.sol:Deploy --broadcast

# Check logs
DEPLOYMENT_LOG=$(cat "./broadcast/01_DeployProtocol.s.sol/31337/run-latest.json")
FORK_ENV_DUMP=$(
    cat <<EOF
UNIVERSAL_ROUTER=$(echo "$DEPLOYMENT_LOG" | jq '.returns.UniversalRouter_.value' | xargs printf "%s\n")
EOF
)
echo "$FORK_ENV_DUMP" >> .env.fork

popd  > /dev/null
