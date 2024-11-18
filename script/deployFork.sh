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

script/deployFork.sh

rpcUrl=http://localhost:8545
deployerPrivateKey=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
chainId=$(cast chain-id -r "$rpcUrl")
broadcastUsdn="./broadcast/01_DeployProtocol.s.sol/$chainId/run-latest.json"
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

echo "DEPLOYER_ADDRESS"
echo $DEPLOYER_ADDRESS
echo "________________"

echo "USDN_PROTOCOL_ADDRESS"
echo $USDN_PROTOCOL_ADDRESS
echo "_____________________"

# Add USDN protocol address to .env.fork of universal-router
cat ".env.fork" > "../../.env.fork"

# Enter universal-router folder
popd  > /dev/null

# Deploy Router
forge script --via-ir --non-interactive --private-key "$deployerPrivateKey" -f "$rpcUrl" script/01_Deploy.s.sol:Deploy --broadcast

# Check logs
DEPLOYMENT_LOG=$(cat "broadcast/01_Deploy.s.sol/$chainId/run-latest.json")
FORK_ENV_DUMP=$(
    cat <<EOF
$(cat .env.fork)
UNIVERSAL_ROUTER=$(echo "$DEPLOYMENT_LOG" | jq '.returns.UniversalRouter_.value' | xargs printf "%s\n")
EOF
)

echo "$FORK_ENV_DUMP" > .env.fork

popd  > /dev/null

# Impersonating
cast rpc anvil_impersonateAccount $DEPLOYER_ADDRESS

#####
# Admin set roles
#####

# ADMIN_SET_EXTERNAL_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0xe066b764dbc472e706cbc2f8733ab0fcee541dd01136dc6512dca8f6dc61b692" $DEPLOYER_ADDRESS

# ADMIN_SET_OPTIONS_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x98de2855152060acaf991c6c67bcd523513322d493b38e46544cf92e3fee8334" $DEPLOYER_ADDRESS

# ADMIN_SET_PROTOCOL_PARAMS_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x668144e07fd661d09cc13a56f823a5cecc9ddd81fac15e0f66a794e2048f7eeb" $DEPLOYER_ADDRESS

# ADMIN_SET_USDN_PARAMS_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x750ec48621e602bf6e87efd3f05aacefc0afaaf02ef76bf2316cd7d61322e136" $DEPLOYER_ADDRESS

#####
# Normal set roles
#####

# SET_EXTERNAL_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x112a81abbbc0a642a71c01ee707237745fdf9150a36cd6c341a77a82b042fcfe" $DEPLOYER_ADDRESS

# SET_USDN_PARAMS_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x2332b7708e4d211430c3d07e50a5483bc31f86f1a3c7c79e159a5bab63060e82" $DEPLOYER_ADDRESS

# SET_OPTIONS_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x5fdbe07c81484705bc90cbf005feb2ecc66822288a5ac5d3cf89e384fa6fdd47" $DEPLOYER_ADDRESS

# SET_PROTOCOL_PARAMS_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0xa33d215b27d5ec861579769ea5343a0a14da1a34a49b09fa343facf13bf852ba" $DEPLOYER_ADDRESS

#####
# Set admin roles
#####

# ADMIN_CRITICAL_FUNCTIONS_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0xe7b4cf829186f8c4eae56184e8b39efd89f053da9890202c466f766239b5c06d" $DEPLOYER_ADDRESS

# ADMIN_PROXY_UPGRADE_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x5afc0553d94a015add162f99e64d9f1e7954cb5168d8eb6c93ee26a783968d8a" $DEPLOYER_ADDRESS

# ADMIN_PAUSER_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x365fccb66c62533ad1447fec73f7b764cf03ac69d512070f7c0aa889025cec19" $DEPLOYER_ADDRESS

# ADMIN_UNPAUSER_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0xe7747964bba14b1d51bb4f84f826a6ba3ef37d424902280c5a01c99b837c970d" $DEPLOYER_ADDRESS

#####
# Set normal roles
#####

# CRITICAL_FUNCTIONS_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x02f5b57e73f7374270c293a6c0f8f21b963fcb794517ca371178f1ebf3e0ea7d" $DEPLOYER_ADDRESS

# PROXY_UPGRADE_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x233d5d22cfc2df30a1764cac21e2207537a3711647f2c29fe3702201f65c1444" $DEPLOYER_ADDRESS

# PAUSER_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a" $DEPLOYER_ADDRESS

# UNPAUSER_ROLE
cast call $USDN_PROTOCOL_ADDRESS --from $DEPLOYER_ADDRESS "grantRole(bytes32 role, address account)" "0x427da25fe773164f88948d3e215c94b6554e2ed5e5f203a821c9f2f6131cf75a" $DEPLOYER_ADDRESS

# Stop impersonating
cast rpc anvil_stopImpersonatingAccount $DEPLOYER_ADDRESS
