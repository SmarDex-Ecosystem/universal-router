#!/usr/bin/env bash
red='\033[0;31m'
green='\033[0m'
nc='\033[0m'

# Check if USDN_PROTOCOL_SHORTDN_ADDRESS argument is provided
if [ -z "$1" ]; then
    printf "${red}Error: USDN_PROTOCOL_SHORTDN_ADDRESS argument is required${nc}\n"
    printf "Usage: $0 <USDN_PROTOCOL_SHORTDN_ADDRESS>\n"
    exit 1
fi

USDN_PROTOCOL_SHORTDN_ADDRESS=$1

rpcUrl=http://localhost:8545
deployerPrivateKey=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
ADDRESS_ZERO=0x0000000000000000000000000000000000000000
chainId=$(cast chain-id -r "$rpcUrl")
export DEPLOYER_ADDRESS=$(cast wallet address "$deployerPrivateKey")
echo $USDN_PROTOCOL_SHORTDN_ADDRESS

printf "$green USDN protocol has been deployed !\n"
sleep 1s

# Deploy Router
forge script --non-interactive --private-key "$deployerPrivateKey" -f "$rpcUrl" script/01_Deploy.s.sol:Deploy \
    --broadcast --sig "run(address,address)" "$ADDRESS_ZERO" "$USDN_PROTOCOL_SHORTDN_ADDRESS"

# Check logs
DEPLOYMENT_LOG=$(cat "broadcast/01_Deploy.s.sol/$chainId/run-latest.json")
FORK_ENV_DUMP=$(
    cat <<EOF
$(cat .env.fork)
UNIVERSAL_ROUTER_SHORTDN_ADDRESS=$(echo "$DEPLOYMENT_LOG" | jq '.returns.universalRouter_.value' | xargs printf "%s\n")
EOF
)

echo "$FORK_ENV_DUMP" >.env.fork
