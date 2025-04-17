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

- [AcurastHyperdriveIbc#Ibc](https://sepolia.etherscan.io/address/0xeb5fd20887C2367FDF48D171F07028914E2a46e8#code)

- [AcurastToken#AcurastToken](https://sepolia.etherscan.io/address/0x6D314E433bf446C833f11D4D07Ed38720d6069D0#code)
