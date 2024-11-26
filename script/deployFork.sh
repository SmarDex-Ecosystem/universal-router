#!/usr/bin/env bash
red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
nc='\033[0m'


echo "here 0"


# Path of the script folder (so that the script can be invoked from somewhere else than the project's root)
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
echo "here 1"
echo "Path=$PWD"

# Enter usdn-contracts folder
pushd $SCRIPT_DIR/.. > /dev/null

# # Deploy USDN contracts
# pushd $SCRIPT_DIR/../dependencies/@smardex-usdn-contracts-* > /dev/null

echo "here 2"
echo "path=$PWD"
script/deployFork.sh
echo "here 3"

rpcUrl=http://localhost:8545
deployerPrivateKey=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
chainId=$(cast chain-id -r "$rpcUrl")
broadcastUsdn="$PWD/broadcast/01_DeployProtocol.s.sol/$chainId/run-latest.json"
echo "broadcastUsdn=$broadcastUsdn"
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
        break
    fi

    if [ $i -eq 15 ]; then
        printf "\n$red Failed to fetch WUSDN address$nc\n\n"
        exit 1
    fi

    sleep 2s
done

echo "path=$PWD"

# Add USDN protocol address to .env.fork of universal-router
cat ".env.fork" > "../../.env.fork"

# Enter universal-router folder
popd > /dev/null

# Deploy Router
forge script --via-ir --non-interactive --private-key "$deployerPrivateKey" -f "$rpcUrl" script/01_Deploy.s.sol:Deploy --broadcast

# Check logs
DEPLOYMENT_LOG=$(cat "broadcast/01_DeployProtocol.s.sol/$chainId/run-latest.json")
FORK_ENV_DUMP=$(
    cat <<EOF
$(cat .env.fork)
UNIVERSAL_ROUTER=$(echo "$DEPLOYMENT_LOG" | jq '.returns.UniversalRouter_.value' | xargs printf "%s\n")
EOF
)

echo "$FORK_ENV_DUMP" > .env.fork

