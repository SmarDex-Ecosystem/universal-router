#!/usr/bin/env bash
red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'


rpcUrl=http://localhost:8545
deployerPrivateKey=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
chainId=$(cast chain-id -r "$rpcUrl")
export DEPLOYER_ADDRESS=$(cast wallet address "$deployerPrivateKey")

printf "$green USDN protocol has been deployed !\n"
sleep 1s

# # Add USDN protocol address to .env.fork of universal-router
# cat ".env.fork" >"../../.env.fork"

# # Enter universal-router folder
# popd >/dev/null || exit

# Deploy Router
forge script --non-interactive --private-key "$deployerPrivateKey" -f "$rpcUrl" script/01_Deploy.s.sol:Deploy \
    --broadcast --sig "run(address,address)" 0x0000000000000000000000000000000000000000 "$USDN_PROTOCOL_SHORTDN_ADDRESS"

# Check logs
DEPLOYMENT_LOG=$(cat "broadcast/01_Deploy.s.sol/$chainId/run-latest.json")
FORK_ENV_DUMP=$(
    cat <<EOF
$(cat .env.fork)
UNIVERSAL_ROUTER_SHORTDN_ADDRESS=$(echo "$DEPLOYMENT_LOG" | jq '.returns.universalRouter_.value' | xargs printf "%s\n")
EOF
)

echo "$FORK_ENV_DUMP" >.env.fork
