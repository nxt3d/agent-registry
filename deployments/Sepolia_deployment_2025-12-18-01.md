# Sepolia Deployment - 2025-12-18-01

**Date:** December 18, 2025  
**Network:** Sepolia Testnet  
**Chain ID:** 11155111

## Contract Details

- **Contract Name:** AgentRegistry
- **Contract Address:** [`0xed42261c6d705EB369e32db698dBC488F1F5f3a9`](https://sepolia.etherscan.io/address/0xed42261c6d705eb369e32db698dbc488f1f5f3a9)
- **Compiler Version:** Solidity 0.8.30
- **EVM Version:** Prague
- **Status:** ✅ Verified on Etherscan

## Deployment Transaction

- **Transaction Hash:** [`0xfa222a19ea88242c0cbe73301985043d714a8297f4e9b5e9dd0122f736ced056`](https://sepolia.etherscan.io/tx/0xfa222a19ea88242c0cbe73301985043d714a8297f4e9b5e9dd0122f736ced056)
- **Deployer Address:** `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- **Gas Used:** 4,463,047 gas
- **Gas Price:** 0.001117046 gwei
- **Total Cost:** ~0.000004985 ETH

## Roles Configuration

The deployer (`0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`) has been granted all administrative roles:

- ✅ **DEFAULT_ADMIN_ROLE** - Can grant/revoke all roles
- ✅ **REGISTRAR_ROLE** - Can register new agents
- ✅ **METADATA_ADMIN_ROLE** - Can set contract-level metadata

## Initial Contract Metadata

The following contract metadata was set during deployment:

- **name:** "Agent Registry"
- **description:** "A minimal onchain registry for discovering AI agents"

## Contract Features

- ✅ ERC-6909 Multi-Token Standard (single ownership model)
- ✅ ERC-8048 Onchain Token Metadata
- ✅ ERC-8049 Contract-Level Metadata
- ✅ OpenZeppelin AccessControl
- ✅ ERC-6909-style boolean approvals

## Verification

Contract source code has been verified on Etherscan:
- **Etherscan URL:** https://sepolia.etherscan.io/address/0xed42261c6d705eb369e32db698dbc488f1f5f3a9#code

## Usage

### Register an Agent

```solidity
// Connect to the deployed contract
AgentRegistry registry = AgentRegistry(0xed42261c6d705EB369e32db698dBC488F1F5f3a9);

// Register with basic parameters (requires REGISTRAR_ROLE)
uint256 agentId = registry.register(
    ownerAddress,
    "mcp",                          // endpoint type
    "https://agent.example.com",    // endpoint URL
    agentAccountAddress             // agent's wallet
);
```

### Query Agent Metadata

```solidity
bytes memory name = registry.getMetadata(agentId, "name");
bytes memory endpoint = registry.getMetadata(agentId, "endpoint");
address owner = registry.ownerOf(agentId);
```

## Related Transactions

1. **Deployment:** `0xfa222a19ea88242c0cbe73301985043d714a8297f4e9b5e9dd0122f736ced056`
2. **Set Metadata (name):** `0x2f8f429a186c7997ece3796e793d1b7a7b949dbb0bbab0bba4a0f2f56b1d86ef`
3. **Set Metadata (description):** `0xf29d9274ade029ff7c62a62428c16296612b2281c10e45914b91f475543a8385`

## Repository

- **GitHub:** https://github.com/nxt3d/agent-registry
- **Commit:** Initial deployment

## Notes

- This is a testnet deployment for development and testing purposes
- All roles are currently held by the deployer address
- The contract uses Diamond Storage pattern for ERC-8048 and ERC-8049 extensions
- 77 tests passed before deployment (45 AgentRegistry, 15 ERC8048, 17 ERC8049)

