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

## Current deployments

### Sepolia

- [AcurastHyperdriveIbc#Ibc](https://sepolia.etherscan.io/address/0x3b6622E395886D84372D6a096e1d9B5536f7B1BF#code)

- [AcurastToken#AcurastToken](https://sepolia.etherscan.io/address/0x2a7f61aeEFee7B946173fD525B22d331E0E1aE68#code)
