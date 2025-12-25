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

An optional companion contract for public minting with economic controls.

**Features:**
| Feature | Description |
|---------|-------------|
| **Mint Price** | Configurable ETH price per mint (0 = free) |
| **Max Supply** | Optional cap on total agents (0 = unlimited) |
| **Open/Close** | Owner can open/close public minting (starts **closed** by default) |
| **Lock Bits** | Permanently lock specific settings |
| **Metadata Minting** | Set agent metadata during mint |
| **Batch Minting** | Mint multiple agents in one transaction |
| **Revenue Collection** | Owner can withdraw collected ETH |
| **Overpayment Refunds** | Automatically refunds excess ETH |

**Lock Bits (Irreversible):**
| Lock | Effect |
|------|--------|
| `LOCK_OPEN_CLOSE` | Permanently freezes open/close state |
| `LOCK_MINT_PRICE` | Permanently freezes mint price |
| `LOCK_MAX_SUPPLY` | Permanently freezes max supply |

### 3. AgentRegistryFactory

A gas-efficient factory for deploying registries and registrars using EIP-1167 minimal clones.

**Key Features:**
- Deploy registry + registrar together or separately
- Deterministic deployment with predictable addresses
- Automatic role setup when deploying pairs
- Tracks all deployed contracts with enumeration functions

See [`deployments/Sepolia_factory_deployment_2025-12-19-10.md`](deployments/Sepolia_factory_deployment_2025-12-19-10.md) for full API documentation.

## Deployed Contracts (Sepolia)

| Contract | Address |
|----------|---------|
| **Factory** | [`0x97B5679fA5B7fB4B38525359791BB94Eac0a3723`](https://sepolia.etherscan.io/address/0x97B5679fA5B7fB4B38525359791BB94Eac0a3723) |
| **Registry Implementation** | [`0xE625179F5CD970fD3FB00Df72398815106DB5F31`](https://sepolia.etherscan.io/address/0xE625179F5CD970fD3FB00Df72398815106DB5F31) |
| **Registrar Implementation** | [`0x6aB5c9e29C261c8c9019CF85B5D8057b9f0A9cEd`](https://sepolia.etherscan.io/address/0x6aB5c9e29C261c8c9019CF85B5D8057b9f0A9cEd) |

📄 **Full deployment details and code examples:** [`deployments/Sepolia_factory_deployment_2025-12-19-10.md`](deployments/Sepolia_factory_deployment_2025-12-19-10.md)

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
FACTORY_ADDRESS=0x97B5679fA5B7fB4B38525359791BB94Eac0a3723 \
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
- **Role Management**: Be careful when granting `DEFAULT_ADMIN_ROLE`
- **Registrar Ownership**: The registrar owner controls minting and withdrawals
- **Factory is Permissionless**: Anyone can deploy registries from the factory

## License

MIT
