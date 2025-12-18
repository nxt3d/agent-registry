# Minimal Agent Registry

A lightweight onchain registry for **discovering AI agents across organizational boundaries** using [ERC-6909](https://eips.ethereum.org/EIPS/eip-6909) as the underlying token standard and [ERC-8048](https://eips.ethereum.org/EIPS/eip-8048) for onchain metadata.

Each agent is represented as a token ID with a single owner and fully onchain metadata, enabling agent discovery and ownership transfer without reliance on external storage.

## Motivation

While various offchain agent communication protocols handle capabilities advertisement and task orchestration, they don't inherently cover agent discovery. To foster an open, cross-organizational agent economy, we need a mechanism for discovering agents in a decentralized manner.

This registry enables:
- **Decentralized Discovery**: Anyone can deploy their own registry on any L2 or Mainnet Ethereum
- **Specialized Collections**: Create registries for specific agent categories (e.g., Whitehat Hacking Agents, DeFi Stablecoin Strategy Agents)
- **Censorship Resistance**: All metadata stored fully onchain using ERC-8048
- **Single Ownership**: Each agent has exactly one owner with clear transfer semantics

## Features

- **ERC-6909 Multi-Token**: Efficient token standard with single ownership model
- **ERC-8048 Onchain Metadata**: Key-value metadata stored entirely onchain
- **ERC-8049 Contract Metadata**: Registry-level metadata for collection info
- **Access Control**: OpenZeppelin AccessControl for contract-level permissions
- **Token Authorization**: ERC-6909-style approvals for agent-level permissions

## Agent ID Format

Each agent is uniquely identified by:
- **Registry Address**: The contract address of the registry
- **agentId**: The token ID (`uint256`) assigned incrementally by the registry

Example: Registry `0xd8da6bf26964af9d7eed9e03e53415d37aa96045`, Agent ID `12345`

## Standard Metadata Keys

### Agent Metadata (ERC-8048)

| Key | Type | Description |
|-----|------|-------------|
| `name` | string | Human-readable name of the agent |
| `ens_name` | string | ENS name associated with the agent |
| `image` | string | URI pointing to an image (may be data URL) |
| `description` | string | Natural language description of capabilities |
| `endpoint_type` | string | Protocol type (e.g., "mcp", "a2a") |
| `endpoint` | string | Primary offchain endpoint URL |
| `agent_account` | address | Agent's account address for transactions |

### Contract Metadata (ERC-8049)

| Key | Type | Description |
|-----|------|-------------|
| `name` | string | Human-readable name of the registry |
| `description` | string | Description of the registry's purpose |
| `image` | string | URI for registry image |
| `symbol` | string | Short symbol for the registry |

## Installation

```bash
forge install
```

## Build

```bash
forge build
```

## Test

```bash
forge test
```

## Deployment

### Basic Deployment

```bash
forge script script/DeployAgentRegistry.s.sol:DeployAgentRegistry \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

### With Additional Roles

```bash
REGISTRAR_ADDRESS=0x... METADATA_ADMIN_ADDRESS=0x... \
forge script script/DeployAgentRegistry.s.sol:DeployAgentRegistryWithRoles \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

## Roles

| Role | Description |
|------|-------------|
| `DEFAULT_ADMIN_ROLE` | Can grant/revoke all roles |
| `REGISTRAR_ROLE` | Can register new agents |
| `METADATA_ADMIN_ROLE` | Can set contract-level metadata |

## Usage

### Register an Agent

```solidity
// Basic registration
uint256 agentId = registry.register(
    ownerAddress,
    "mcp",                          // endpoint type
    "https://agent.example.com",    // endpoint URL
    agentAccountAddress             // agent's wallet
);

// With custom metadata
IAgentRegistry.MetadataEntry[] memory metadata = new IAgentRegistry.MetadataEntry[](2);
metadata[0] = IAgentRegistry.MetadataEntry("name", bytes("My Agent"));
metadata[1] = IAgentRegistry.MetadataEntry("description", bytes("A helpful assistant"));
uint256 agentId = registry.register(ownerAddress, metadata);
```

### Query Agent Metadata

```solidity
bytes memory name = registry.getMetadata(agentId, "name");
bytes memory endpoint = registry.getMetadata(agentId, "endpoint");
address owner = registry.ownerOf(agentId);
```

### Update Agent Metadata (Owner/Operator Only)

```solidity
registry.setMetadata(agentId, "endpoint", bytes("https://new-endpoint.com"));
```

### Transfer Ownership

```solidity
registry.transfer(newOwner, agentId, 1);
```

## Environment Variables

Create a `.env` file:

```bash
DEPLOYER_PRIVATE_KEY=0x...
SEPOLIA_RPC_URL=https://...
ETHERSCAN_API_KEY=...
```

## License

MIT
