#!/usr/bin/env bash
red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'
sourcifyVerifierUrl=http://localhost:5555

# Declare args
VERIFY_FLAG=""
WUSDN_TOKEN_ADDRESS=""
USDN_PROTOCOL_USDN_ADDRESS=""

# Parse arguments, --verify is optional and can be in any position
# the other two args are required in correct order (WUSDN_TOKEN_ADDRESS
# then USDN_PROTOCOL_USDN_ADDRESS).
for arg in "$@"; do
    if [ "$arg" == "--verify" ]; then
        VERIFY_FLAG="--verify --verifier sourcify --verifier-url $sourcifyVerifierUrl"
    elif [ -z "$WUSDN_TOKEN_ADDRESS" ]; then
        WUSDN_TOKEN_ADDRESS="$arg"
    elif [ -z "$USDN_PROTOCOL_USDN_ADDRESS" ]; then
        USDN_PROTOCOL_USDN_ADDRESS="$arg"
    fi
done

# Check if both arguments are provided
if [ -z "$WUSDN_TOKEN_ADDRESS" ] || [ -z "$USDN_PROTOCOL_USDN_ADDRESS" ]; then
    printf "${red}Error: Both WUSDN_TOKEN_ADDRESS and USDN_PROTOCOL_USDN_ADDRESS arguments are required${nc}\n"
    printf "Usage: $0 <WUSDN_TOKEN_ADDRESS> <USDN_PROTOCOL_USDN_ADDRESS> [--verify]\n"
    exit 1
fi

rpcUrl=http://localhost:8545
deployerPrivateKey=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
chainId=$(cast chain-id -r "$rpcUrl")

# Deploy Router
forge script --non-interactive --private-key "$deployerPrivateKey" -f "$rpcUrl" script/01_Deploy.s.sol:Deploy \
    --broadcast $VERIFY_FLAG --sig "run(address,address)" "$WUSDN_TOKEN_ADDRESS" "$USDN_PROTOCOL_USDN_ADDRESS"

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
