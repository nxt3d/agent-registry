# Sepolia Factory Deployment - 2025-12-19-10

**Date:** December 19, 2025  
**Network:** Sepolia Testnet  
**Chain ID:** 11155111

## Contract Details

- **Contract Name:** AgentRegistryFactory
- **Contract Address:** [`0x97B5679fA5B7fB4B38525359791BB94Eac0a3723`](https://sepolia.etherscan.io/address/0x97B5679fA5B7fB4B38525359791BB94Eac0a3723)
- **Compiler Version:** Solidity 0.8.30
- **EVM Version:** Prague
- **Status:** ✅ Verified on Etherscan

## Implementation Contracts

### AgentRegistry Implementation
- **Implementation Address:** [`0xE625179F5CD970fD3FB00Df72398815106DB5F31`](https://sepolia.etherscan.io/address/0xE625179F5CD970fD3FB00Df72398815106DB5F31)
- **Status:** ✅ Verified on Etherscan

### AgentRegistrar Implementation
- **Implementation Address:** [`0x6aB5c9e29C261c8c9019CF85B5D8057b9f0A9cEd`](https://sepolia.etherscan.io/address/0x6aB5c9e29C261c8c9019CF85B5D8057b9f0A9cEd)
- **Status:** ✅ Verified on Etherscan

## Deployment Transaction

- **Transaction Hash:** [`0x364beb290dbec7cc6e3ba9e71cf776a0783ae445816a9654e9bd9b3755af99fe`](https://sepolia.etherscan.io/tx/0x364beb290dbec7cc6e3ba9e71cf776a0783ae445816a9654e9bd9b3755af99fe)
- **Deployment Block:** `9878571` (important for indexers)
- **Deployer Address:** `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- **Gas Used:** ~11,062,853 gas
- **Total Cost:** ~0.0000115 ETH

## Factory Features

The factory contract enables gas-efficient deployment of AgentRegistry and AgentRegistrar instances using EIP-1167 minimal proxy pattern:

### Registry Deployment
- ✅ **Standard Clone Deployment** - `deployRegistry(admin)` creates a new registry clone
- ✅ **Deterministic Deployment** - `deployRegistryDeterministic(admin, salt)` for predictable addresses
- ✅ **Address Prediction** - `predictDeterministicAddress(salt)` to predict addresses before deployment

### Registrar Deployment
- ✅ **Standalone Registrar** - `deployRegistrar(registry, mintPrice, maxSupply, owner)` creates a registrar for an existing registry
- ✅ **Deterministic Registrar** - `deployRegistrarDeterministic(registry, mintPrice, maxSupply, owner, salt)` for predictable addresses

### Combined Deployment
- ✅ **Registry + Registrar Pair** - `deploy(admin, mintPrice, maxSupply)` deploys both contracts together
- ✅ **Deterministic Pair** - `deployDeterministic(admin, mintPrice, maxSupply, salt)` for predictable addresses
- ✅ **Automatic Role Granting** - Registrar automatically receives `REGISTRAR_ROLE` on the registry

### Tracking & Enumeration
- ✅ **Registry Tracking** - Tracks all deployed registry clones with enumeration functions
- ✅ **Registrar Tracking** - Tracks all deployed registrar clones
- ✅ **Registry-to-Registrar Mapping** - Maps registries to their associated registrars (when deployed together)

## Usage

### Deploy Registry + Registrar Together

```solidity
// Connect to the factory
AgentRegistryFactory factory = AgentRegistryFactory(0x97B5679fA5B7fB4B38525359791BB94Eac0a3723);

// Deploy both registry and registrar
uint256 mintPrice = 0.01 ether;
uint256 maxSupply = 1000; // 0 = unlimited
(address registry, address registrar) = factory.deploy(adminAddress, mintPrice, maxSupply);

// Registrar is automatically granted REGISTRAR_ROLE on the registry
// IMPORTANT: Minting starts CLOSED by default - you must open it
AgentRegistrar(registrar).openMinting();
```

### Deploy Registry Only

```solidity
address registry = factory.deployRegistry(adminAddress);
```

### Deploy Registrar for Existing Registry

```solidity
address registrar = factory.deployRegistrar(
    AgentRegistry(existingRegistry),
    mintPrice,
    maxSupply,
    ownerAddress
);

// Manually grant REGISTRAR_ROLE to the registrar
AgentRegistry(existingRegistry).grantRole(
    AgentRegistry(existingRegistry).REGISTRAR_ROLE(),
    registrar
);
```

### Deterministic Deployment

```solidity
bytes32 salt = keccak256("my-unique-salt");

// Predict addresses
address predictedRegistry = factory.predictDeterministicRegistryAddress(salt);
address predictedRegistrar = factory.predictDeterministicRegistrarAddress(salt);

// Deploy to predicted addresses
(address registry, address registrar) = factory.deployDeterministic(
    adminAddress,
    mintPrice,
    maxSupply,
    salt
);
```

### Enumerate Deployed Contracts

```solidity
// Get counts
uint256 registryCount = factory.getDeployedRegistriesCount();
uint256 registrarCount = factory.getDeployedRegistrarsCount();

// Get ranges
address[] memory registries = factory.getDeployedRegistries(0, 10);
address[] memory registrars = factory.getDeployedRegistrars(0, 10);

// Check if address is deployed
bool isRegistry = factory.isDeployedRegistry(someAddress);
bool isRegistrar = factory.isDeployedRegistrar(someAddress);

// Get registrar for a registry (if deployed together)
address registrar = factory.registryToRegistrar(registryAddress);
```

## Verification

All contracts have been verified on Etherscan:
- **Factory:** https://sepolia.etherscan.io/address/0x97B5679fA5B7fB4B38525359791BB94Eac0a3723#code
- **Registry Implementation:** https://sepolia.etherscan.io/address/0xE625179F5CD970fD3FB00Df72398815106DB5F31#code
- **Registrar Implementation:** https://sepolia.etherscan.io/address/0x6aB5c9e29C261c8c9019CF85B5D8057b9f0A9cEd#code

## Gas Savings

Using minimal clones (EIP-1167) provides significant gas savings:
- **Full registry deployment:** ~4,463,047 gas (standalone AgentRegistry)
- **Full registrar deployment:** ~1,500,000+ gas (standalone AgentRegistrar)
- **Clone registry deployment:** ~219,172 gas (via factory)
- **Clone registrar deployment:** ~180,000+ gas (via factory)
- **Combined clone deployment:** ~400,000 gas (registry + registrar via factory)
- **Savings:** ~95% reduction in deployment costs

## AgentRegistrar Features

The registrar contract includes:
- ✅ **Mint Price Control** - Configurable price per mint (0 = free)
- ✅ **Max Supply Cap** - Optional maximum supply limit (0 = unlimited)
- ✅ **Open/Close Minting** - Owner can open/close public minting
- ✅ **Lock Bits** - Permanent locks for open/close, price, and max supply
- ✅ **Metadata Support** - Mint with basic or flexible key-value metadata
- ✅ **Batch Minting** - Mint multiple agents in a single transaction
- ✅ **ETH Withdrawal** - Owner can withdraw collected ETH

## Repository

- **GitHub:** https://github.com/nxt3d/agent-registry
- **Commit:** `81314bc` - Add AgentRegistrar with metadata support

## Notes

- The factory creates AgentRegistry and AgentRegistrar implementation contracts during construction
- Each clone is a minimal proxy that delegates to the implementation
- Clones have independent storage and state
- All clones share the same implementation code
- When deploying registry + registrar together, the registrar automatically receives `REGISTRAR_ROLE` on the registry
- **Registrars start with minting CLOSED by default** - call `openMinting()` to enable public minting
- The registrar trusts the registry (no reentrancy guards on mint functions)
- Metadata can be set during minting using either basic parameters or flexible key-value arrays

