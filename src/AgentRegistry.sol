// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IAgentRegistry} from "./interfaces/IAgentRegistry.sol";
import {ERC8048} from "./extensions/ERC8048.sol";
import {ERC8049} from "./extensions/ERC8049.sol";
import {IERC8048} from "./interfaces/IERC8048.sol";
import {IERC8049} from "./interfaces/IERC8049.sol";

/// @title AgentRegistry
/// @notice A minimal onchain registry for discovering AI agents
/// @dev Implements ERC-6909 with single ownership, ERC-8048 metadata, ERC-8049 contract metadata,
///      and uses AccessControl for contract-level permissions with ERC-6909-style token authorization.
///      Supports both standalone deployment and minimal clone (EIP-1167) deployment.
contract AgentRegistry is IAgentRegistry, AccessControl, Initializable, ERC8048, ERC8049 {
    /* --- Constants --- */

    /// @notice Role for registering new agents
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    /// @notice Role for setting contract metadata
    bytes32 public constant METADATA_ADMIN_ROLE = keccak256("METADATA_ADMIN_ROLE");

    /* --- State Variables --- */

    /// @notice ERC-6909 approvals: owner => spender => id => approved
    mapping(address owner => mapping(address spender => mapping(uint256 id => bool))) private _approvals;

    /// @notice ERC-6909 operator approvals: owner => operator => approved
    mapping(address owner => mapping(address spender => bool)) public isOperator;

    /// @notice Single ownership mapping: agentId => owner
    mapping(uint256 agentId => address) private _owners;

    /// @notice Counter for agent IDs (next ID to be assigned)
    uint256 public agentIndex;

    /* --- Errors --- */

    /// @notice Thrown when the sender has insufficient balance
    error InsufficientBalance(address owner, uint256 id);

    /// @notice Thrown when the sender lacks permission
    error InsufficientPermission(address spender, uint256 id);

    /// @notice Thrown when an invalid amount is provided (must be 1 for transfers)
    error InvalidAmount();

    /// @notice Thrown when querying a non-existent agent
    error AgentNotFound();

    /// @notice Thrown when array lengths don't match in batch operations
    error ArrayLengthMismatch();

    /* --- Constructor --- */

    /// @notice Initialize the registry with the deployer as admin (standalone deployment)
    /// @dev Disables initializers to prevent re-initialization when used as implementation
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRAR_ROLE, msg.sender);
        _grantRole(METADATA_ADMIN_ROLE, msg.sender);
        _disableInitializers();
    }

    /// @notice Initialize the registry (for clone deployment)
    /// @param admin The address to receive all admin roles
    function initialize(address admin) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(REGISTRAR_ROLE, admin);
        _grantRole(METADATA_ADMIN_ROLE, admin);
    }

    /* --- ERC-165 --- */

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return
            interfaceId == 0x0f632fb3 || // ERC-6909 interface ID
            interfaceId == type(IERC8048).interfaceId ||
            interfaceId == type(IERC8049).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /* --- ERC-6909 View Functions --- */

    /// @inheritdoc IAgentRegistry
    function balanceOf(address owner, uint256 id) public view returns (uint256) {
        return _owners[id] == owner ? 1 : 0;
    }

    /// @inheritdoc IAgentRegistry
    function allowance(address owner, address spender, uint256 id) public view returns (uint256) {
        return _approvals[owner][spender][id] ? 1 : 0;
    }

    /// @inheritdoc IAgentRegistry
    function ownerOf(uint256 agentId) external view returns (address) {
        address owner = _owners[agentId];
        if (owner == address(0)) revert AgentNotFound();
        return owner;
    }

    /* --- ERC-6909 Transfer Functions --- */

    /// @inheritdoc IAgentRegistry
    function transfer(address receiver, uint256 id, uint256 amount) public returns (bool) {
        if (amount != 1) revert InvalidAmount();
        if (_owners[id] != msg.sender) revert InsufficientBalance(msg.sender, id);

        _owners[id] = receiver;

        emit Transfer(msg.sender, msg.sender, receiver, id, 1);
        return true;
    }

    /// @inheritdoc IAgentRegistry
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public returns (bool) {
        if (amount != 1) revert InvalidAmount();

        _checkApprovedOwnerOrOperator(sender, id);
        if (_owners[id] != sender) revert InsufficientBalance(sender, id);

        _owners[id] = receiver;

        emit Transfer(msg.sender, sender, receiver, id, 1);
        return true;
    }

    /* --- ERC-6909 Approval Functions --- */

    /// @inheritdoc IAgentRegistry
    /// @dev Any non-zero amount grants approval (stored as true), zero revokes it (stored as false)
    function approve(address spender, uint256 id, uint256 amount) public returns (bool) {
        bool approved = amount > 0;
        _approvals[msg.sender][spender][id] = approved;
        emit Approval(msg.sender, spender, id, approved ? 1 : 0);
        return true;
    }

    /// @inheritdoc IAgentRegistry
    function setOperator(address spender, bool approved) public returns (bool) {
        isOperator[msg.sender][spender] = approved;
        emit OperatorSet(msg.sender, spender, approved);
        return true;
    }

    /* --- Registration Functions --- */

    /// @inheritdoc IAgentRegistry
    function register(
        address owner,
        string calldata endpointType,
        string calldata endpoint,
        address agentAccount
    ) external onlyRole(REGISTRAR_ROLE) returns (uint256 agentId) {
        agentId = agentIndex++;

        // Set owner and mint token
        _owners[agentId] = owner;

        // Set endpoint_type metadata
        if (bytes(endpointType).length > 0) {
            _setMetadataUnchecked(agentId, "endpoint_type", bytes(endpointType));
        }

        // Set endpoint metadata
        if (bytes(endpoint).length > 0) {
            _setMetadataUnchecked(agentId, "endpoint", bytes(endpoint));
        }

        // Set agent_account metadata
        if (agentAccount != address(0)) {
            _setMetadataUnchecked(agentId, "agent_account", abi.encode(agentAccount));
        }

        emit Transfer(msg.sender, address(0), owner, agentId, 1);
        emit Registered(agentId, owner, endpointType, endpoint, agentAccount);
    }

    /// @inheritdoc IAgentRegistry
    function register(
        address owner,
        MetadataEntry[] calldata metadata
    ) external onlyRole(REGISTRAR_ROLE) returns (uint256 agentId) {
        agentId = _register(owner, metadata);
    }

    /// @inheritdoc IAgentRegistry
    function registerBatch(
        address[] calldata owners,
        MetadataEntry[][] calldata metadata
    ) external onlyRole(REGISTRAR_ROLE) returns (uint256[] memory agentIds) {
        if (owners.length != metadata.length) revert ArrayLengthMismatch();

        agentIds = new uint256[](owners.length);

        for (uint256 i = 0; i < owners.length; i++) {
            agentIds[i] = _register(owners[i], metadata[i]);
        }
    }

    /* --- ERC-8048 Metadata Functions --- */

    /// @inheritdoc IAgentRegistry
    /// @dev Only the owner or an approved operator can set metadata for an agent
    function setMetadata(uint256 agentId, string calldata key, bytes calldata value) external {
        _checkAgentAuthorization(agentId);
        _setMetadata(agentId, key, value);
    }

    /* --- ERC-8049 Contract Metadata Functions --- */

    /// @inheritdoc IAgentRegistry
    function setContractMetadata(string calldata key, bytes calldata value) external onlyRole(METADATA_ADMIN_ROLE) {
        _setContractMetadata(key, value);
    }

    /* --- Internal Functions --- */

    /// @dev Register a new agent with metadata entries
    function _register(address owner, MetadataEntry[] calldata metadata) internal returns (uint256 agentId) {
        agentId = agentIndex++;

        // Set owner and mint token
        _owners[agentId] = owner;

        // Set metadata (ERC-8048) and extract common fields
        string memory endpointType = "";
        string memory endpoint = "";
        address agentAccount = address(0);

        for (uint256 i = 0; i < metadata.length; i++) {
            _setMetadata(agentId, metadata[i].key, metadata[i].value);

            // Extract common fields for event
            if (keccak256(bytes(metadata[i].key)) == keccak256(bytes("endpoint_type"))) {
                endpointType = string(metadata[i].value);
            } else if (keccak256(bytes(metadata[i].key)) == keccak256(bytes("endpoint"))) {
                endpoint = string(metadata[i].value);
            } else if (keccak256(bytes(metadata[i].key)) == keccak256(bytes("agent_account"))) {
                agentAccount = abi.decode(metadata[i].value, (address));
            }
        }

        emit Transfer(msg.sender, address(0), owner, agentId, 1);
        emit Registered(agentId, owner, endpointType, endpoint, agentAccount);
    }

    /// @dev Check if msg.sender is owner, operator, or has approval for the token
    ///      Consumes the approval if used (ERC-6909 compliant)
    function _checkApprovedOwnerOrOperator(address sender, uint256 id) internal {
        if (sender == msg.sender) return;
        if (isOperator[sender][msg.sender]) return;
        if (_approvals[sender][msg.sender][id]) {
            // Consume the approval (one-time use per ERC-6909)
            _approvals[sender][msg.sender][id] = false;
            return;
        }
        revert InsufficientPermission(msg.sender, id);
    }

    /// @dev Check if msg.sender is authorized to modify an agent's metadata
    ///      Uses ERC-6909-style authorization: owner or operator
    function _checkAgentAuthorization(uint256 agentId) internal view {
        address owner = _owners[agentId];
        if (owner == address(0)) revert AgentNotFound();
        if (msg.sender == owner) return;
        if (isOperator[owner][msg.sender]) return;
        revert InsufficientPermission(msg.sender, agentId);
    }
}
