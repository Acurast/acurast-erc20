# hyperdrive-ethereum

## Build

```sh
yarn run hardhat compile
```

## Test deploy to local hardhat network

```ssh
yarn run hardhat node
```

```sh
yarn run hardhat ignition deploy ignition/modules/AcurastToken.ts --verbose --network localhost
```

## Deploy on sepolia testnet
```sh
yarn run hardhat ignition deploy ignition/modules/AcurastToken.ts --network sepolia --verify
```

**Partially wipe futures of deployment to redeploy changes**:

Only works if no dependent futures in deployment.

```sh
yarn run hardhat ignition wipe chain-11155111 AcurastToken#AcurastToken
```

## Current deployments

### Sepolia

- [AcurastHyperdriveIbc#Ibc](https://sepolia.etherscan.io/address/0xcdE845a0c34ec329CFB3a9052Ce99F0EC92d0943#code)

- [AcurastToken#AcurastToken](https://sepolia.etherscan.io/address/0x7F44aD0fD6c15CfBA6f417C33924c8cF0C751d23#code)
