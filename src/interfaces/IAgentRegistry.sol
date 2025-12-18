// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC8048} from "./IERC8048.sol";
import {IERC8049} from "./IERC8049.sol";

/// @title IAgentRegistry
/// @notice Interface for the Minimal Agent Registry
/// @dev Extends ERC-6909 with ERC-8048 onchain metadata and ERC-8049 contract metadata
interface IAgentRegistry is IERC8048, IERC8049 {
    /* --- Events --- */

    /// @notice ERC-6909 Transfer event
    event Transfer(address caller, address indexed sender, address indexed receiver, uint256 indexed id, uint256 amount);

    /// @notice ERC-6909 OperatorSet event
    event OperatorSet(address indexed owner, address indexed spender, bool approved);

    /// @notice ERC-6909 Approval event
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);

    /// @notice Emitted when an agent is registered
    /// @param agentId The ID of the registered agent
    /// @param owner The owner of the agent
    /// @param endpointType The type of endpoint protocol (e.g., "mcp", "a2a")
    /// @param endpoint The offchain endpoint URL
    /// @param agentAccount The agent's account address
    event Registered(uint256 indexed agentId, address indexed owner, string endpointType, string endpoint, address agentAccount);

    /* --- Structs --- */

    /// @notice Metadata entry for batch operations
    struct MetadataEntry {
        string key;
        bytes value;
    }

    /* --- ERC-6909 Functions --- */

    /// @notice Get the balance of a token for an owner
    function balanceOf(address owner, uint256 id) external view returns (uint256);

    /// @notice Get the allowance of a spender for a specific token
    function allowance(address owner, address spender, uint256 id) external view returns (uint256);

    /// @notice Check if an address is an operator for an owner
    function isOperator(address owner, address spender) external view returns (bool);

    /// @notice Transfer a token
    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool);

    /// @notice Transfer a token from one address to another
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool);

    /// @notice Approve a spender for a specific token
    function approve(address spender, uint256 id, uint256 amount) external returns (bool);

    /// @notice Set operator approval for all tokens
    function setOperator(address spender, bool approved) external returns (bool);

    /* --- Agent Registry Functions --- */

    /// @notice Register a new agent with basic parameters
    /// @param owner The owner of the agent
    /// @param endpointType The type of endpoint protocol
    /// @param endpoint The offchain endpoint URL
    /// @param agentAccount The agent's account address
    /// @return agentId The ID of the registered agent
    function register(address owner, string calldata endpointType, string calldata endpoint, address agentAccount) external returns (uint256 agentId);

    /// @notice Register a new agent with metadata entries
    /// @param owner The owner of the agent
    /// @param metadata Array of metadata entries
    /// @return agentId The ID of the registered agent
    function register(address owner, MetadataEntry[] calldata metadata) external returns (uint256 agentId);

    /// @notice Register multiple agents in a batch
    /// @param owners Array of owners
    /// @param metadata Array of metadata entry arrays
    /// @return agentIds Array of registered agent IDs
    function registerBatch(address[] calldata owners, MetadataEntry[][] calldata metadata) external returns (uint256[] memory agentIds);

    /// @notice Get the owner of an agent
    /// @param agentId The agent ID
    /// @return owner The owner address
    function ownerOf(uint256 agentId) external view returns (address owner);

    /// @notice Set metadata for an agent (owner/operator only)
    /// @param agentId The agent ID
    /// @param key The metadata key
    /// @param value The metadata value
    function setMetadata(uint256 agentId, string calldata key, bytes calldata value) external;

    /// @notice Set contract-level metadata (admin only)
    /// @param key The metadata key
    /// @param value The metadata value
    function setContractMetadata(string calldata key, bytes calldata value) external;

    /// @notice Get the current agent index (next ID to be assigned)
    /// @return The current agent index
    function agentIndex() external view returns (uint256);
}
