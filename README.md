# Minimal Agent Registry

A complete, production-ready system for building **decentralized AI agent networks** on Ethereum. Deploy your own agent registry with customizable minting, fees, supply limits, and onchain metadata—all with 95% gas savings through EIP-1167 minimal clones.

## Overview

The Agent Registry system enables organizations, DAOs, and individuals to create and manage collections of AI agents onchain. Each agent is represented as a token with:

- **Single ownership** via [ERC-6909](https://eips.ethereum.org/EIPS/eip-6909)
- **Fully onchain metadata** via [ERC-8048](https://eips.ethereum.org/EIPS/eip-8048)
- **Transferable ownership** with standard token semantics
- **Discoverable endpoints** for agent communication protocols (MCP, A2A, etc.)

## Why Use This?

While offchain agent protocols handle capabilities advertisement and task orchestration, they don't inherently cover **agent discovery**. This registry provides:

| Feature | Description |
|---------|-------------|
| **Decentralized Discovery** | Deploy registries on any EVM chain |
| **Specialized Collections** | Create themed registries (e.g., "DeFi Strategy Agents", "Security Auditing Agents") |
| **Censorship Resistance** | All metadata stored fully onchain |
| **Economic Models** | Configurable mint fees, supply caps, and revenue collection |
| **Gas Efficiency** | 95% cheaper deployments via minimal clones |

## Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                     AgentRegistryFactory                           │
│  ┌─────────────────────────┐    ┌─────────────────────────┐        │ 
│  │  Registry Imp.          │    │ Registrar Imp.          │        │ 
│  │      (ERC-6909 +        │    │   (Minting + Fees +     │        │
│  │   ERC-8048 + Roles)     │    │   Supply Control)       │        │
│  └─────────────────────────┘    └─────────────────────────┘        │
└────────────────────────────────────────────────────────────────────┘
                    │                           │
                    │ clone()                   │ clone()
                    ▼                           ▼
        ┌───────────────────┐       ┌───────────────────┐
        │  Your Registry    │◄──────│  Your Registrar   │
        │   (Minimal Clone) │       │   (Minimal Clone) │
        │                   │       │                   │
        │  • Agent tokens   │       │  • Public minting │
        │  • Metadata       │       │  • Fee collection │
        │  • Access control │       │  • Supply limits  │
        └───────────────────┘       └───────────────────┘
```

## System Components

### 1. AgentRegistry

The core contract that stores agents and their metadata.

**Features:**
- ERC-6909 token standard with single ownership (balance is always 0 or 1)
- ERC-8048 onchain key-value metadata per agent
- ERC-8049 contract-level metadata for the registry itself
- OpenZeppelin AccessControl for role-based permissions
- ERC-6909 approvals and operators for token-level permissions

**Roles:**
| Role | Description |
|------|-------------|
| `DEFAULT_ADMIN_ROLE` | Can grant/revoke all roles |
| `REGISTRAR_ROLE` | Can register (mint) new agents |
| `METADATA_ADMIN_ROLE` | Can set contract-level metadata |

### 2. AgentRegistrar

An optional companion contract for public or private minting with economic controls.

**Features:**
| Feature | Description |
|---------|-------------|
| **Mint Price** | Configurable ETH price per mint (0 = free) |
| **Max Supply** | Optional cap on total agents (0 = unlimited) |
| **Open/Close** | Admin can open/close minting (starts **closed** by default) |
| **Public/Private Minting** | When open, can be public (anyone) or private (MINTER_ROLE only) |
| **Access Control** | Role-based permissions (ADMIN_ROLE, MINTER_ROLE) |
| **Lock Bits** | Permanently lock specific settings |
| **Metadata Minting** | Set agent metadata during mint |
| **Batch Minting** | Mint multiple agents in one transaction |
| **Revenue Collection** | Admin can withdraw collected ETH |
| **Overpayment Refunds** | Automatically refunds excess ETH |

**Roles:**
| Role | Description |
|------|-------------|
| `DEFAULT_ADMIN_ROLE` | Can grant/revoke all roles (role management) |
| `ADMIN_ROLE` | Can open/close minting, set prices, withdraw funds, set lock bits |
| `MINTER_ROLE` | Can mint agents when minting is open in private mode |

**Minting Modes:**
- **Public Minting**: When `openMinting(true)` is called, anyone can mint (subject to payment and supply limits)
- **Private Minting**: When `openMinting(false)` is called, only addresses with `MINTER_ROLE` can mint
- **Default**: Minting starts closed and defaults to private mode
- **Deployer**: Automatically receives all roles (`DEFAULT_ADMIN_ROLE`, `ADMIN_ROLE`, `MINTER_ROLE`)

**Lock Bits (Irreversible):**
| Lock | Effect |
|------|--------|
| `LOCK_OPEN_CLOSE` | Permanently freezes open/close state **and** public/private mode (locks current state) |
| `LOCK_MINT_PRICE` | Permanently freezes mint price |
| `LOCK_MAX_SUPPLY` | Permanently freezes max supply |

**Note:** When `LOCK_OPEN_CLOSE` is set, it freezes both the open/close state AND the public/private mode. If locked while public, it stays public forever. If locked while private, it stays private forever.

### 3. AgentRegistryFactory

A gas-efficient factory for deploying registries and registrars using EIP-1167 minimal clones.

**Key Features:**
- Deploy registry + registrar together or separately
- Set registry name via ERC-8049 contract metadata during deployment
- Deterministic deployment with predictable addresses
- Automatic role setup when deploying pairs
- Tracks all deployed contracts with enumeration functions

**Deployment Functions:**
- `deployRegistry(admin)` / `deployRegistry(admin, name)` - Deploy registry only
- `deploy(admin, mintPrice, maxSupply)` / `deploy(admin, mintPrice, maxSupply, name)` - Deploy registry + registrar together
- `deployRegistryDeterministic(admin, salt)` / `deployRegistryDeterministic(admin, salt, name)` - Deterministic registry deployment
- `deployDeterministic(admin, mintPrice, maxSupply, registrySalt, registrarSalt, name)` - Deterministic combined deployment

See [`deployments/Sepolia_factory_deployment_2025-12-27-01.md`](deployments/Sepolia_factory_deployment_2025-12-27-01.md) for full API documentation.

## Deployed Contracts (Sepolia)

**Deployment Date:** December 27, 2025  
**Deployment Block:** `9926798` (important for indexers)  
**Transaction Hash:** [`0x2196ecfb5dda8a9c8c20bcc62882cea48070b905bacc32cc1b9d4f5d8c689620`](https://sepolia.etherscan.io/tx/0x2196ecfb5dda8a9c8c20bcc62882cea48070b905bacc32cc1b9d4f5d8c689620)

| Contract | Address | Status |
|----------|---------|--------|
| **Factory** | [`0x86a5139cBA9AB0f588aeFA3A7Ea3351E62C18563`](https://sepolia.etherscan.io/address/0x86a5139cBA9AB0f588aeFA3A7Ea3351E62C18563) | ✅ Verified |
| **Registry Implementation** | [`0xa8cb0672E978Ff311412477c4D6732d80e074b20`](https://sepolia.etherscan.io/address/0xa8cb0672E978Ff311412477c4D6732d80e074b20) | ✅ Verified |
| **Registrar Implementation** | [`0xb5E3Dcc8cc881c95Cd66D03fd0A4B3C07eA2fDCc`](https://sepolia.etherscan.io/address/0xb5E3Dcc8cc881c95Cd66D03fd0A4B3C07eA2fDCc) | ✅ Verified |

📄 **Full deployment details and code examples:** [`deployments/Sepolia_factory_deployment_2025-12-27-01.md`](deployments/Sepolia_factory_deployment_2025-12-27-01.md)

## Gas Savings

Using EIP-1167 minimal clones provides massive gas savings:

| Deployment Type | Gas Cost | Savings |
|-----------------|----------|---------|
| Standalone Registry | ~4,463,047 | - |
| Clone Registry | ~219,172 | **95%** |
| Clone Registry + Registrar | ~400,000 | **91%** |

## Standard Metadata Keys

### Agent Metadata (ERC-8048)

| Key | Type | Description |
|-----|------|-------------|
| `name` | string | Human-readable name |
| `ens_name` | string | ENS name for the agent |
| `image` | string | Image URI (may be data URL) |
| `description` | string | Capabilities description |
| `endpoint_type` | string | Protocol type ("mcp", "a2a", etc.) |
| `endpoint` | string | Primary endpoint URL |
| `agent_account` | address | Agent's wallet address |

### Contract Metadata (ERC-8049)

| Key | Type | Description |
|-----|------|-------------|
| `name` | string | Registry name |
| `description` | string | Registry purpose |
| `image` | string | Registry image URI |
| `symbol` | string | Short symbol |

## Use Cases

| Use Case | Configuration |
|----------|---------------|
| **Free Community Registry** | `mintPrice: 0, maxSupply: 0` |
| **Premium Agent Collection** | `mintPrice: 0.1 ETH, maxSupply: 100` + lock max supply |
| **DAO-Controlled Registry** | Deploy with DAO multisig as admin |
| **Permissioned Enterprise** | Deploy registry only, grant `REGISTRAR_ROLE` to approved addresses |
| **Multiple Registrars** | Deploy registry, then multiple registrars with different economics |

## Installation

```bash
git clone https://github.com/nxt3d/agent-registry
cd agent-registry
forge install
```

## Build & Test

```bash
forge build
forge test
```

## Deployment

### Using Existing Factory (Recommended)

```bash
FACTORY_ADDRESS=0x86a5139cBA9AB0f588aeFA3A7Ea3351E62C18563 \
MINT_PRICE=10000000000000000 \
MAX_SUPPLY=1000 \
source .env && forge script script/DeployAgentRegistry.s.sol:DeployFromExistingFactory \
  --rpc-url $SEPOLIA_RPC_URL --broadcast
```

### Deploy New Factory + Registry

```bash
MINT_PRICE=10000000000000000 MAX_SUPPLY=1000 \
source .env && forge script script/DeployAgentRegistry.s.sol:DeployRegistryAndRegistrar \
  --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

See [`script/DeployAgentRegistry.s.sol`](script/DeployAgentRegistry.s.sol) for all deployment options.

### Public vs Private Minting

**Public Minting (Anyone can mint):**
```solidity
// Open minting in public mode
registrar.openMinting(true);

// Now anyone can mint
registrar.mint{value: mintPrice}();
```

**Private Minting (MINTER_ROLE only):**
```solidity
// Open minting in private mode
registrar.openMinting(false);

// Grant MINTER_ROLE to approved addresses
registrar.grantRole(registrar.MINTER_ROLE(), approvedAddress1);
registrar.grantRole(registrar.MINTER_ROLE(), approvedAddress2);

// Only addresses with MINTER_ROLE can mint
registrar.mint{value: mintPrice}(); // ✅ Works if caller has MINTER_ROLE
```

**Switching Between Modes:**
```solidity
// Start private, grant roles to whitelist
registrar.openMinting(false);
registrar.grantRole(registrar.MINTER_ROLE(), whitelistedAddress);

// Later, switch to public
registrar.closeMinting();
registrar.openMinting(true); // Now anyone can mint

// Lock to prevent future changes
registrar.setLockBit(registrar.LOCK_OPEN_CLOSE()); // Freezes as public forever
```

## Environment Variables

Create a `.env` file:

```bash
DEPLOYER_PRIVATE_KEY=0x...
SEPOLIA_RPC_URL=https://...
MAINNET_RPC_URL=https://...
ETHERSCAN_API_KEY=...
```

## Security Considerations

- **Lock Bits are Irreversible**: Once set, lock bits cannot be unset
  - `LOCK_OPEN_CLOSE` freezes both the open/close state AND public/private mode
  - If locked while public, it remains public forever
  - If locked while private, it remains private forever
- **Role Management**: Be careful when granting `DEFAULT_ADMIN_ROLE` (can grant/revoke all roles)
- **Admin vs Default Admin**: `ADMIN_ROLE` handles day-to-day operations, `DEFAULT_ADMIN_ROLE` manages roles
- **Private Minting**: Only addresses with `MINTER_ROLE` can mint when in private mode
- **Public Minting**: Anyone can mint when in public mode (subject to payment and supply limits)
- **Factory is Permissionless**: Anyone can deploy registries from the factory

## License

MIT
