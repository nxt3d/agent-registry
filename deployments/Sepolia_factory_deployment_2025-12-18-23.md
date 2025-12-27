# Sepolia Factory Deployment - 2025-12-18-23

**Date:** December 18, 2025  
**Network:** Sepolia Testnet  
**Chain ID:** 11155111

## Contract Details

- **Contract Name:** AgentRegistryFactory
- **Contract Address:** [`0xB32027222F7eACb9D7aE3423110B77ad86A1300F`](https://sepolia.etherscan.io/address/0xB32027222F7eACb9D7aE3423110B77ad86A1300F)
- **Compiler Version:** Solidity 0.8.30
- **EVM Version:** Prague
- **Status:** ✅ Verified on Etherscan

## Implementation Contract

- **Implementation Address:** [`0xb39d901F1474FE4A4C5463d600c226c3215C9dC6`](https://sepolia.etherscan.io/address/0xb39d901F1474FE4A4C5463d600c226c3215C9dC6)
- **Status:** ⚠️ Not verified (deployed as part of factory constructor)

## Deployment Transaction

- **Transaction Hash:** [`0x6b2b7af3da7ccb25603a869db7422d37ad46febc13d47d0c9836cd082488d937`](https://sepolia.etherscan.io/tx/0x6b2b7af3da7ccb25603a869db7422d37ad46febc13d47d0c9836cd082488d937)
- **Deployer Address:** `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- **Gas Used:** ~5,657,821 gas
- **Total Cost:** ~0.00000689 ETH

## Factory Features

The factory contract enables gas-efficient deployment of AgentRegistry instances using EIP-1167 minimal proxy pattern:

- ✅ **Standard Clone Deployment** - `deploy(admin)` creates a new registry clone
- ✅ **Deterministic Deployment** - `deployDeterministic(admin, salt)` for predictable addresses
- ✅ **Address Prediction** - `predictDeterministicAddress(salt)` to predict addresses before deployment
- ✅ **Registry Tracking** - Tracks all deployed clones with enumeration functions

## Usage

### Deploy a New Registry Clone

```solidity
// Connect to the factory
AgentRegistryFactory factory = AgentRegistryFactory(0xB32027222F7eACb9D7aE3423110B77ad86A1300F);

// Deploy a new registry with an admin
address registry = factory.deploy(adminAddress);

// Or deploy with a deterministic address
bytes32 salt = keccak256("my-unique-salt");
address registry = factory.deployDeterministic(adminAddress, salt);
```

### Predict Deterministic Address

```solidity
bytes32 salt = keccak256("my-unique-salt");
address predicted = factory.predictDeterministicAddress(salt);
// Later deploy to this address
address registry = factory.deployDeterministic(adminAddress, salt);
assert(registry == predicted);
```

### Enumerate Deployed Registries

```solidity
// Get total count
uint256 count = factory.getDeployedRegistriesCount();

// Get a range of registries
address[] memory registries = factory.getDeployedRegistries(0, 10);

// Check if an address is a deployed registry
bool isRegistry = factory.isDeployedRegistry(someAddress);
```

## Verification

Factory contract source code has been verified on Etherscan:
- **Etherscan URL:** https://sepolia.etherscan.io/address/0xB32027222F7eACb9D7aE3423110B77ad86A1300F#code

## Gas Savings

Using minimal clones (EIP-1167) provides significant gas savings:
- **Full deployment:** ~4,463,047 gas (standalone AgentRegistry)
- **Clone deployment:** ~219,172 gas (via factory)
- **Savings:** ~95% reduction in deployment costs

## Repository

- **GitHub:** https://github.com/nxt3d/agent-registry
- **Commit:** Factory deployment

## Notes

- The factory creates an AgentRegistry implementation contract during construction
- Each clone is a minimal proxy that delegates to the implementation
- Clones have independent storage and state
- All clones share the same implementation code
- The implementation contract is initialized during factory construction (roles granted to factory address)




