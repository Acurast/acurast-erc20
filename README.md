# Acurast ERC20 and Hyperdrive contracts

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

- [AcurastHyperdriveIbc#Ibc](https://sepolia.etherscan.io/address/0x9B3b3275A4f49FEC03dE488a245162A30F300E86#code)

- [AcurastToken#AcurastTokenBridge](https://sepolia.etherscan.io/address/0xf27de96535A489CC39259BC2Fa0EF967778BFEfF#code)

- [AcurastToken#AcurastToken](https://sepolia.etherscan.io/address/0x705A18eB47702064e0F4c6EB4Ae6059429Eb3a1A#code)

### Ethereum

- [AcurastToken#AcurastToken](https://etherscan.io/address/0x216b3643ff8b7BB30d8A48E9F1BD550126202AdD)
  
**Fee estimation**

See [deployment address history](https://sepolia.etherscan.io/txs?a=0x147b33c5b12767b3abee547212af27b1398ce517).
```
Deployment: 0.00440755 ETH +0.00353001 ETH
Deployment: 0.00278188 ETH + 0.00255661 ETH
0.00429623 (per transfer native test) + 0.0015861 (receive native test)
TOTAL: 0.01915838 ETH
```