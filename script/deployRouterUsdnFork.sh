#!/usr/bin/env bash
red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'

# Check if both arguments are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    printf "${red}Error: Both WUSDN_TOKEN_ADDRESS and USDN_PROTOCOL_USDN_ADDRESS arguments are required${nc}\n"
    printf "Usage: $0 <WUSDN_TOKEN_ADDRESS> <USDN_PROTOCOL_USDN_ADDRESS>\n"
    exit 1
fi

WUSDN_TOKEN_ADDRESS=$1
USDN_PROTOCOL_USDN_ADDRESS=$2

rpcUrl=http://localhost:8545
deployerPrivateKey=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
chainId=$(cast chain-id -r "$rpcUrl")

# Deploy Router
forge script --non-interactive --private-key "$deployerPrivateKey" -f "$rpcUrl" script/01_Deploy.s.sol:Deploy \
    --broadcast --sig "run(address,address)" "$WUSDN_TOKEN_ADDRESS" "$USDN_PROTOCOL_USDN_ADDRESS"

printf "$green USDN Router has been deployed !\n"

# Check logs
DEPLOYMENT_LOG=$(cat "broadcast/01_Deploy.s.sol/$chainId/run-latest.json")
FORK_ENV_DUMP=$(
    cat <<EOF
$(cat .env.fork)
UNIVERSAL_ROUTER_USDN_ADDRESS=$(echo "$DEPLOYMENT_LOG" | jq '.returns.universalRouter_.value' | xargs printf "%s\n")
EOF
)

echo "$FORK_ENV_DUMP" >.env.fork
