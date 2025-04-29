#!/usr/bin/env bash
red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
nc='\033[0m'

# Deploy USDN contracts
pushd dependencies/@smardex-usdn-contracts-* > /dev/null

script/deployFork.sh

rpcUrl=http://localhost:8545
deployerPrivateKey=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
chainId=$(cast chain-id -r "$rpcUrl")
usdnProtocolBroadcast="./broadcast/01_DeployProtocol.s.sol/$chainId/run-latest.json"
export DEPLOYER_ADDRESS=$(cast wallet address "$deployerPrivateKey")

printf "$green USDN protocol has been deployed !\n"
sleep 1s

for i in {1..15}; do
    printf "$green Trying to fetch WUSDN address... (attempt $i/15)$nc\n"
    WUSDN_ADDRESS=$(cat "$usdnProtocolBroadcast" | jq -r '.returns.Wusdn_.value')
    wusdnCode=$(cast code -r "$rpcUrl" "$WUSDN_ADDRESS")

    if [[ ! -z $wusdnCode ]]; then
        printf "\n$green WUSDN contract found on blockchain$nc\n\n"
        export WUSDN_ADDRESS=$WUSDN_ADDRESS
        export USDN_PROTOCOL_ADDRESS=$(cat "$usdnProtocolBroadcast" | jq -r '.returns.UsdnProtocol_.value')
        break
    fi

    if [ $i -eq 15 ]; then
        printf "\n$red Failed to fetch WUSDN address$nc\n\n"
        exit 1
    fi

    sleep 2s
done

# Add USDN protocol address to .env.fork of universal-router
cat ".env.fork" > "/usr/app/.env.fork"

# Enter universal-router folder
popd > /dev/null

# Deploy Router
forge script --non-interactive --private-key "$deployerPrivateKey" -f "$rpcUrl" script/01_Deploy.s.sol:Deploy --broadcast

# Check logs
DEPLOYMENT_LOG=$(cat "broadcast/01_Deploy.s.sol/$chainId/run-latest.json")
FORK_ENV_DUMP=$(
    cat <<EOF
$(cat .env.fork)
UNIVERSAL_ROUTER_ADDRESS=$(echo "$DEPLOYMENT_LOG" | jq '.returns.UniversalRouter_.value' | xargs printf "%s\n")
EOF
)

echo "$FORK_ENV_DUMP" > .env.fork

