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

### Ethereum

- [AcurastHyperdriveIbc#Ibc](https://etherscan.io/address/0x3de12e9622542e0e32079c2146cacaf40f7e093f)
- [AcurastToken#AcurastToken](https://etherscan.io/address/0x53b6cE1f64f78FF8037f01706FC47f3D53ef1B7C)
  
**Fee estimation**

See [deployment address history](https://sepolia.etherscan.io/txs?a=0x147b33c5b12767b3abee547212af27b1398ce517).
```
Deployment: 0.00440755 ETH +0.00353001 ETH
Deployment: 0.00278188 ETH + 0.00255661 ETH
0.00429623 (per transfer native test) + 0.0015861 (receive native test)
TOTAL: 0.01915838 ETH
```