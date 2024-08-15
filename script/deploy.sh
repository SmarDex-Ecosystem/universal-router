#!/usr/bin/env bash
# Path of the script folder (so that the script can be invoked from somewhere else than the project's root)
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

pushd $SCRIPT_DIR/.. > /dev/null

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
nc='\033[0m'

read -p $'\n'"Enter rpc url : " userRpcUrl
rpcUrl=$userRpcUrl

while true; do
    read -p $'\n'"Do you wish to use a ledger? (Yy/Nn) : " yn
    case $yn in
    [Yy]*)
        read -p $'\n'"Enter address : " userAddress
        address=$userAddress

        printf "\n\n$green Running script in Ledger mode\n"
        ledger=true
        break
        ;;
    [Nn]*)
        read -s -p $'\n'"Enter private key : " privateKey
        deployerPrivateKey=$privateKey

        address=$(cast wallet address $deployerPrivateKey)
        if [[ -z $address ]]; then
            printf "\n$red The private key is invalid$nc\n\n"
            exit 1
        fi

        printf "\n\n$green Running script in Non-Ledger mode\n"
        ledger=false
        break
        ;;
    *) printf "\nPlease answer yes (Y/y) or no (N/n).\n" ;;
    esac
done

printf "\n$blue Address :$nc $address"
printf "\n$blue RPC URL :$nc "$rpcUrl"\n"
export DEPLOYER_ADDRESS=$address

while true; do
    read -p $'\n'"Do you wish to continue? (Yy/Nn) : " yn
    case $yn in
    [Yy]*)
        break
        ;;
    [Nn]*)
        exit 1
        ;;
    *) printf "\nPlease answer yes (Y/y) or no (N/n).\n" ;;
    esac
done

if [ $ledger = true ]; then
    forge script --via-ir -l -f "$rpcUrl" script/01_Deploy.s.sol:Deploy --broadcast
else
    forge script --via-ir --private-key "$deployerPrivateKey" -f "$rpcUrl" script/01_Deploy.s.sol:Deploy --broadcast
fi

popd  > /dev/null
