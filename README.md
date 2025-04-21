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

- [AcurastHyperdriveIbc#Ibc](https://sepolia.etherscan.io/address/0x5bCFA0622e07A74ce3e5bE94fE285830198accEa#code)

- [AcurastToken#AcurastToken](https://sepolia.etherscan.io/address/0x791495b5c932D20705f48680f56bD41D0708981a#code)
