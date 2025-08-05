# Hyperdrive Token Bridge Architecture

## Overview

The Hyperdrive Token Bridge system has been refactored to separate concerns between the token contract and the bridge functionality. This provides better modularity, security, and flexibility.

## Architecture Components

### 1. AcuERC20 (`contracts/token/acu.sol`)
- Abstract base contract for the Acurast token
- Implements ERC20 with additional features:
  - ERC20Permit for gasless approvals
  - ERC20Bridgeable (draft) for cross-chain functionality
  - Access control with role-based permissions
  - Transfer restrictions through configurable restrictor
- Key roles:
  - `TOKEN_BRIDGE`: Can mint and burn tokens for cross-chain transfers
  - `RESTRICTOR_UPDATER`: Can update the transfer restrictor contract

### 2. AcurastToken (`contracts/token/AcurastToken.sol`)
- Concrete implementation of AcuERC20
- Simple ERC20 token with 12 decimals
- Deployed with initial balances for specified addresses

### 3. HyperdriveTokenBridge (`contracts/bridge/HyperdriveTokenBridge.sol`)
- Handles cross-chain transfer logic
- Processes incoming messages from the IBC protocol
- Manages outgoing transfers to other chains
- Must have `TOKEN_BRIDGE` role on the token contract

### 4. Ibc (`contracts/bridge/Ibc.sol`)
- Core IBC protocol implementation
- Handles cross-chain messaging infrastructure
- Manages oracle signatures and message delivery

## Key Benefits of Separation

1. **Modularity**: Token and bridge concerns are separated
2. **Security**: Token contract is simpler and has fewer attack vectors
3. **Upgradability**: Bridge logic can be upgraded independently
4. **Flexibility**: Multiple bridges could theoretically be connected to the same token
5. **Standards Compliance**: Token follows ERC20Bridgeable draft standard

## Deployment Process

The deployment is handled through Hardhat Ignition modules:

1. Deploy IBC contract
2. Deploy AcurastToken with initial balances
3. Deploy HyperdriveTokenBridge with references to token and IBC contracts
4. Grant `TOKEN_BRIDGE` role to the bridge contract

## Cross-Chain Transfer Flow

### Outgoing Transfers (Ethereum → Other Chain)

1. User calls `transferNative(amount, dest)` on the bridge
2. Bridge burns tokens from user's account using `crosschainBurn()`
3. Bridge encodes transfer message and sends via IBC
4. Transfer details stored for potential retry

### Incoming Transfers (Other Chain → Ethereum)

1. IBC contract receives cross-chain message
2. IBC calls `processMessage(sender, payload)` on the bridge
3. Bridge validates message and extracts transfer details
4. Bridge mints tokens to destination address using `crosschainMint()`
5. Transfer nonce recorded to prevent duplicate processing

## Security Considerations

1. **Role-Based Access**: Only bridge contract can mint/burn tokens
2. **Transfer Restrictions**: Configurable restrictor can control token transfers
3. **Nonce Protection**: Prevents replay attacks on cross-chain transfers
4. **Oracle Validation**: IBC requires multiple oracle signatures
5. **TTL Protection**: Messages have time-to-live limits

## Configuration

### Token Configuration
- Transfer restrictor can be updated by `RESTRICTOR_UPDATER` role
- Initial restrictor is set to dead address (transfers disabled by default)

### Bridge Configuration
- IBC contract address (updateable by owner)
- Token pallet account on target chain (updateable by owner)
- Outgoing TTL within IBC-defined bounds (updateable by owner)

## Usage Examples

### Deploy and Setup
```typescript
// Deploy contracts (handled by Ignition)
const { acurastToken, bridge } = await deployments.AcurastToken();

// Grant additional roles if needed
await acurastToken.grantRole(await acurastToken.RESTRICTOR_UPDATER(), restrictorManager);
```

### Cross-Chain Transfer
```solidity
// Transfer 1000 tokens to Acurast chain
bridge.transferNative{value: fee}(1000 * 10**12, destinationAccount);
```

### Update Configuration
```solidity
// Update outgoing TTL
bridge.setOutgoingTTL(100);

// Update transfer restrictor
token.updateErc20TransferRestrictor(newRestrictorAddress);
```

## Migration from Old Architecture

The old architecture combined token and bridge functionality in a single contract. The new architecture:

1. Moves token logic to dedicated contracts following standards
2. Separates bridge logic for better modularity
3. Uses role-based access control for security
4. Maintains backward compatibility for cross-chain functionality

## Future Enhancements

1. **Multiple Bridges**: Support for multiple bridge contracts
2. **Advanced Restrictions**: More sophisticated transfer restriction logic
3. **Fee Management**: More flexible fee structures for cross-chain transfers
4. **Emergency Controls**: Pause mechanisms for security incidents