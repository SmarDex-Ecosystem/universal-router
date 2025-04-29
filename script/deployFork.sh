#!/usr/bin/env bash
red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'

# Deploy USDN contracts
pushd dependencies/@smardex-usdn-contracts-* >/dev/null || exit

script/fork/deployFork.sh

rpcUrl=http://localhost:8545
deployerPrivateKey=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
chainId=$(cast chain-id -r "$rpcUrl")
usdnProtocolBroadcast="./broadcast/DeployUsdnWstethFork.s.sol/$chainId/run-latest.json"
export DEPLOYER_ADDRESS=$(cast wallet address "$deployerPrivateKey")

printf "$green USDN protocol has been deployed !\n"
sleep 1s

for i in {1..15}; do
    printf "$green Trying to fetch WUSDN address... (attempt $i/15)$nc\n"
    WUSDN_ADDRESS=$(cat "$usdnProtocolBroadcast" | jq -r '.returns.wusdn_.value')
    wusdnCode=$(cast code -r "$rpcUrl" "$WUSDN_ADDRESS")

    if [[ ! -z $wusdnCode ]]; then
        printf "\n$green WUSDN contract found on blockchain$nc\n\n"
        USDN_PROTOCOL_ADDRESS=$(cat "$usdnProtocolBroadcast" | jq -r '.returns.usdnProtocol_.value')
        break
    fi

    if [ $i -eq 15 ]; then
        printf "\n$red Failed to fetch WUSDN address$nc\n\n"
        exit 1
    fi

    sleep 2s
done

# Add USDN protocol address to .env.fork of universal-router
cat ".env.fork" >"../../.env.fork"

# Enter universal-router folder
popd >/dev/null || exit

# Deploy Router
forge script --non-interactive --private-key "$deployerPrivateKey" -f "$rpcUrl" script/01_Deploy.s.sol:Deploy \
    --broadcast --sig "run(address,address)" "$WUSDN_ADDRESS" "$USDN_PROTOCOL_ADDRESS"

# Check logs
DEPLOYMENT_LOG=$(cat "broadcast/01_Deploy.s.sol/$chainId/run-latest.json")
FORK_ENV_DUMP=$(
    cat <<EOF
$(cat .env.fork)
UNIVERSAL_ROUTER_ADDRESS=$(echo "$DEPLOYMENT_LOG" | jq '.returns.universalRouter_.value' | xargs printf "%s\n")
EOF
)

echo "$FORK_ENV_DUMP" >.env.fork
