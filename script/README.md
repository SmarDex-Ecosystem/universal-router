# Scripts

## Deploy the router

To deploy the router, run the command:

```sh
forge script script/01_Deploy.s.sol -i 1 -f RPC_URL --broadcast --sig "run(address,address)" WUSDN_ADDRESS USDN_PROTOCOL_ADDRESS
```

## Verify contracts

The verifying script will work with a broadcast file, the compiled contracts and an etherscan API key.
You don't need to be the deployer to verify the contracts.
Before verifying, you need to compile the contracts:

```forge compile```

Be sure to be in the same version as the deployment to avoid bytecode difference.
You can then verify by using this cli:

```sh
npm run verify -- PATH_TO_BROADCAST_FILE -e ETHERSCAN_API_KEY
```

To show some extra debug you can add `-d` flag.
If you are verifying contracts in another platform than Etherscan, you can specify the url with `--verifier-url`
