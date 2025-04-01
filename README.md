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

- [contracts/ibc.sol:Ibc](https://sepolia.etherscan.io/address/0xb1bEA47a3510Bf55fd444C5C11AEf04C7488152B#code)

- [@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy](https://sepolia.etherscan.io/address/0x61363cb390eb1a1F2AdBF45b2e55f19C6FEd4Dab#code)

- [contracts/acu.sol:AcurastToken](https://sepolia.etherscan.io/address/0xD4E015140B9c6aF811835f83Ef86aBb518cCE470#code)
