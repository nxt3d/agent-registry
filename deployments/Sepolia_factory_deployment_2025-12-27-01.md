# Sepolia Factory Deployment - 2025-12-27

**Date:** December 27, 2025  
**Network:** Sepolia Testnet  
**Chain ID:** 11155111

## Contract Details

- **Contract Name:** AgentRegistryFactory
- **Contract Address:** [`0x86a5139cBA9AB0f588aeFA3A7Ea3351E62C18563`](https://sepolia.etherscan.io/address/0x86a5139cBA9AB0f588aeFA3A7Ea3351E62C18563)
- **Compiler Version:** Solidity 0.8.30
- **EVM Version:** Prague
- **Status:** ✅ Verified on Etherscan

## Implementation Contracts

### AgentRegistry Implementation
- **Implementation Address:** [`0xa8cb0672E978Ff311412477c4D6732d80e074b20`](https://sepolia.etherscan.io/address/0xa8cb0672E978Ff311412477c4D6732d80e074b20)
- **Status:** ✅ Verified on Etherscan
- **Transaction Hash:** [`0xd5fb903e4f2b59129a004717513d052720c47e952d2a4f3efb519b42f8e0e805`](https://sepolia.etherscan.io/tx/0xd5fb903e4f2b59129a004717513d052720c47e952d2a4f3efb519b42f8e0e805)
- **Deployment Block:** `9926798` (important for indexers)

### AgentRegistrar Implementation
- **Implementation Address:** [`0xb5E3Dcc8cc881c95Cd66D03fd0A4B3C07eA2fDCc`](https://sepolia.etherscan.io/address/0xb5E3Dcc8cc881c95Cd66D03fd0A4B3C07eA2fDCc)
- **Status:** ✅ Verified on Etherscan
- **Transaction Hash:** [`0x87dc5ef02fdcb8d092dcbcb2902da178fef6ea0b4545b1a75c0e454271e6bab3`](https://sepolia.etherscan.io/tx/0x87dc5ef02fdcb8d092dcbcb2902da178fef6ea0b4545b1a75c0e454271e6bab3)
- **Deployment Block:** `9926798` (important for indexers)

## Deployment Transaction

- **Transaction Hash:** [`0x2196ecfb5dda8a9c8c20bcc62882cea48070b905bacc32cc1b9d4f5d8c689620`](https://sepolia.etherscan.io/tx/0x2196ecfb5dda8a9c8c20bcc62882cea48070b905bacc32cc1b9d4f5d8c689620)
- **Deployment Block:** `9926798` (important for indexers)
- **Deployer Address:** `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`

## Deployment Method

This deployment uses a **two-step approach** to avoid "max initcode size exceeded" errors:

1. **Step 1:** Deploy implementation contracts separately
   - AgentRegistry implementation deployed first
   - AgentRegistrar implementation deployed second (with dummy constructor params)

2. **Step 2:** Deploy factory with pre-deployed implementation addresses
   - Factory constructor accepts implementation addresses as parameters
   - This avoids deploying implementations inline, which would exceed initcode size limits

## Factory Features

The factory contract enables gas-efficient deployment of AgentRegistry and AgentRegistrar instances using EIP-1167 minimal proxy pattern:

### Registry Deployment
- ✅ **Standard Clone Deployment** - `deployRegistry(admin)` creates a new registry clone
- ✅ **Registry with Name** - `deployRegistry(admin, name)` creates a registry with ERC-8049 metadata name
- ✅ **Deterministic Deployment** - `deployRegistryDeterministic(admin, salt)` for predictable addresses
- ✅ **Deterministic with Name** - `deployRegistryDeterministic(admin, salt, name)` for named deterministic deployments
- ✅ **Address Prediction** - `predictRegistryAddress(salt)` to predict addresses before deployment

### Registrar Deployment
- ✅ **Standalone Registrar** - `deployRegistrar(registry, mintPrice, maxSupply, admin)` creates a registrar for an existing registry
- ✅ **Deterministic Registrar** - `deployRegistrarDeterministic(registry, mintPrice, maxSupply, admin, salt)` for predictable addresses

### Combined Deployment
- ✅ **Registry + Registrar Pair** - `deploy(admin, mintPrice, maxSupply)` deploys both contracts together
- ✅ **Registry + Registrar with Name** - `deploy(admin, mintPrice, maxSupply, name)` deploys with registry name
- ✅ **Deterministic Pair** - `deployDeterministic(admin, mintPrice, maxSupply, registrySalt, registrarSalt)` for predictable addresses
- ✅ **Deterministic Pair with Name** - `deployDeterministic(admin, mintPrice, maxSupply, registrySalt, registrarSalt, name)` for named deterministic deployments
- ✅ **Automatic Role Granting** - Registrar automatically receives `REGISTRAR_ROLE` on the registry

### Tracking & Enumeration
- ✅ **Registry Tracking** - Tracks all deployed registry clones with enumeration functions
- ✅ **Registrar Tracking** - Tracks all deployed registrar clones
- ✅ **Registry-to-Registrar Mapping** - Maps registries to their associated registrars (when deployed together)

## Usage

### Deploy Registry + Registrar Together

```solidity
// Connect to the factory
AgentRegistryFactory factory = AgentRegistryFactory(0x86a5139cBA9AB0f588aeFA3A7Ea3351E62C18563);

// Deploy both registry and registrar
uint256 mintPrice = 0.01 ether;
uint256 maxSupply = 1000; // 0 = unlimited
(address registry, address registrar) = factory.deploy(adminAddress, mintPrice, maxSupply);

// Or with a name for the registry
(address registry, address registrar) = factory.deploy(
    adminAddress, 
    mintPrice, 
    maxSupply, 
    "My Agent Registry"
);

// Registrar is automatically granted REGISTRAR_ROLE on the registry
// IMPORTANT: Minting starts CLOSED by default - you must open it
AgentRegistrar(registrar).openMinting(true); // true = public minting, false = private minting
```

### Deploy Registry Only

```solidity
// Standard deployment
address registry = factory.deployRegistry(adminAddress);

// With name
address registry = factory.deployRegistry(adminAddress, "My Registry Name");
```

### Deploy Registrar for Existing Registry

```solidity
address registrar = factory.deployRegistrar(
    AgentRegistry(existingRegistry),
    mintPrice,
    maxSupply,
    adminAddress
);

// Manually grant REGISTRAR_ROLE to the registrar
AgentRegistry(existingRegistry).grantRole(
    AgentRegistry(existingRegistry).REGISTRAR_ROLE(),
    registrar
);
```

### Deterministic Deployment

```solidity
bytes32 registrySalt = keccak256("my-registry-salt");
bytes32 registrarSalt = keccak256("my-registrar-salt");

// Predict addresses
address predictedRegistry = factory.predictRegistryAddress(registrySalt);
address predictedRegistrar = factory.predictRegistrarAddress(registrarSalt);

// Deploy to predicted addresses
(address registry, address registrar) = factory.deployDeterministic(
    adminAddress,
    mintPrice,
    maxSupply,
    registrySalt,
    registrarSalt
);

// Or with a name
(address registry, address registrar) = factory.deployDeterministic(
    adminAddress,
    mintPrice,
    maxSupply,
    registrySalt,
    registrarSalt,
    "My Registry Name"
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
- **Factory:** https://sepolia.etherscan.io/address/0x86a5139cBA9AB0f588aeFA3A7Ea3351E62C18563#code
- **Registry Implementation:** https://sepolia.etherscan.io/address/0xa8cb0672E978Ff311412477c4D6732d80e074b20#code
- **Registrar Implementation:** https://sepolia.etherscan.io/address/0xb5E3Dcc8cc881c95Cd66D03fd0A4B3C07eA2fDCc#code

## Gas Savings

Using minimal clones (EIP-1167) provides significant gas savings:
- **Full registry deployment:** ~4,463,047 gas (standalone AgentRegistry)
- **Full registrar deployment:** ~1,500,000+ gas (standalone AgentRegistrar)
- **Clone registry deployment:** ~219,172 gas (via factory)
- **Clone registrar deployment:** ~180,000+ gas (via factory)
- **Combined clone deployment:** ~400,000 gas (registry + registrar via factory)
- **Savings:** ~95% reduction in deployment costs

## Recent Updates

This deployment includes the following updates from the previous version:

### Factory Constructor Changes
- ✅ **Separate Implementation Deployment** - Factory now accepts pre-deployed implementation addresses
- ✅ **Initcode Size Fix** - Resolves "max initcode size exceeded" errors by deploying implementations separately
- ✅ **Backward Compatible API** - All factory methods remain unchanged

### Registry Features
- ✅ **Name Parameter Support** - All deployment functions now support optional `name` parameter
- ✅ **ERC-8049 Metadata** - Registry names are stored as ERC-8049 contract metadata
- ✅ **IERC6909 Interface** - Properly extends IERC6909 interface

### Registrar Features
- ✅ **Public/Private Minting** - `openMinting(bool isPublic)` supports both public and private minting modes
- ✅ **MINTER_ROLE** - Private minting requires MINTER_ROLE
- ✅ **AccessControl Integration** - Uses OpenZeppelin AccessControl for role management
- ✅ **Withdrawal Updates** - Withdrawals go to the caller (msg.sender) instead of owner

## AgentRegistrar Features

The registrar contract includes:
- ✅ **Mint Price Control** - Configurable price per mint (0 = free)
- ✅ **Max Supply Cap** - Optional maximum supply limit (0 = unlimited)
- ✅ **Open/Close Minting** - Admin can open/close public or private minting
- ✅ **Public/Private Modes** - Control who can mint (public = anyone, private = MINTER_ROLE only)
- ✅ **Lock Bits** - Permanent locks for open/close, price, and max supply
- ✅ **Metadata Support** - Mint with basic or flexible key-value metadata
- ✅ **Batch Minting** - Mint multiple agents in a single transaction
- ✅ **ETH Withdrawal** - Admin can withdraw collected ETH

## Repository

- **GitHub:** https://github.com/nxt3d/agent-registry
- **Commit:** `1a225e6` - fix: deploy factory with separate implementations to avoid initcode size limit

## Notes

- The factory uses pre-deployed implementation contracts to avoid initcode size limits
- Each clone is a minimal proxy that delegates to the implementation
- Clones have independent storage and state
- All clones share the same implementation code
- When deploying registry + registrar together, the registrar automatically receives `REGISTRAR_ROLE` on the registry
- **Registrars start with minting CLOSED by default** - call `openMinting(true)` for public or `openMinting(false)` for private minting
- Registry names are stored as ERC-8049 contract metadata and can be set during deployment
- The registrar uses AccessControl with ADMIN_ROLE, MINTER_ROLE, and DEFAULT_ADMIN_ROLE
- Private minting mode requires callers to have MINTER_ROLE
