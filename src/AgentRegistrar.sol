// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AgentRegistry} from "./AgentRegistry.sol";
import {IAgentRegistry} from "./interfaces/IAgentRegistry.sol";

/// @title AgentRegistrar
/// @notice A registrar contract that allows public or private minting of agents for a fee
/// @dev Supports both standalone deployment and minimal clone (EIP-1167) deployment.
///      Features: mint price, max supply cap, open/close minting, public/private minting, permanent lock bits.
contract AgentRegistrar is Initializable, AccessControl, ReentrancyGuard {
    /* --- Constants --- */
    
    /// @notice Role for administrative functions (open/close minting, set prices, etc.)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    /// @notice Role for minting agents when minting is in private mode
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /* --- Lock Bits --- */
    
    /// @notice Bit flags for locking specific admin functions
    /// Bit 0: LOCK_OPEN_CLOSE - Prevents opening/closing minting
    /// Bit 1: LOCK_MINT_PRICE - Prevents changing mint price
    /// Bit 2: LOCK_MAX_SUPPLY - Prevents changing max supply
    uint256 public lockBits;
    
    /// @notice Lock bit constants
    uint256 public constant LOCK_OPEN_CLOSE = 1 << 0;    // 1
    uint256 public constant LOCK_MINT_PRICE = 1 << 1;    // 2
    uint256 public constant LOCK_MAX_SUPPLY = 1 << 2;    // 4

    /* --- State Variables --- */

    /// @notice The AgentRegistry this registrar mints to
    AgentRegistry public registry;

    /// @notice Price per mint in wei (0 = free mint)
    uint256 public mintPrice;

    /// @notice Maximum number of agents that can be minted (0 = unlimited)
    uint256 public maxSupply;

    /// @notice Current number of agents minted through this registrar
    uint256 public totalMinted;

    /// @notice Whether minting is currently open
    bool public open;
    
    /// @notice Whether minting is public (true) or private (false)
    /// @dev When false, only addresses with MINTER_ROLE can mint
    bool public publicMinting;

    /* --- Events --- */

    /// @notice Emitted when minting is opened
    /// @param isPublic Whether minting is public (true) or private (false)
    event MintingOpened(bool isPublic);

    /// @notice Emitted when minting is closed
    event MintingClosed();

    /// @notice Emitted when mint price is updated
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);

    /// @notice Emitted when max supply is updated
    event MaxSupplyUpdated(uint256 oldSupply, uint256 newSupply);

    /// @notice Emitted when a lock bit is set
    event LockBitSet(uint256 lockBit);

    /// @notice Emitted when an agent is minted through this registrar
    event AgentMinted(uint256 indexed agentId, address indexed owner, uint256 mintNumber);

    /// @notice Emitted when ETH is withdrawn
    event Withdrawn(address indexed to, uint256 amount);

    /* --- Errors --- */

    /// @notice Thrown when minting is not open
    error MintingNotOpen();
    
    /// @notice Thrown when caller lacks minter role in private minting mode
    error NotMinter();

    /// @notice Thrown when max supply would be exceeded
    error MaxSupplyExceeded(uint256 requested, uint256 available);

    /// @notice Thrown when insufficient payment is sent
    error InsufficientPayment(uint256 sent, uint256 required);

    /// @notice Thrown when a locked function is called
    error FunctionLocked();

    /// @notice Thrown when an invalid lock bit is provided
    error InvalidLockBit();

    /// @notice Thrown when new max supply is below total minted
    error MaxSupplyTooLow(uint256 newMaxSupply, uint256 totalMinted);

    /// @notice Thrown when ETH transfer fails
    error TransferFailed();

    /* --- Constructor --- */

    /// @notice Deploy as standalone registrar
    /// @param _registry The AgentRegistry to mint to
    /// @param _mintPrice Price per mint in wei
    /// @param _maxSupply Maximum supply (0 = unlimited)
    /// @param _admin Admin of the registrar (receives ADMIN_ROLE and DEFAULT_ADMIN_ROLE)
    constructor(
        AgentRegistry _registry,
        uint256 _mintPrice,
        uint256 _maxSupply,
        address _admin
    ) {
        registry = _registry;
        mintPrice = _mintPrice;
        maxSupply = _maxSupply;
        open = false;
        publicMinting = false; // Default to private minting
        
        // Grant roles to admin - DEFAULT_ADMIN_ROLE for role management, ADMIN_ROLE for admin functions, MINTER_ROLE for private minting
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
        _disableInitializers();
    }

    /// @notice Initialize the registrar (for clone deployment)
    /// @param _registry The AgentRegistry to mint to
    /// @param _mintPrice Price per mint in wei
    /// @param _maxSupply Maximum supply (0 = unlimited)
    /// @param _admin Admin of the registrar (receives ADMIN_ROLE and DEFAULT_ADMIN_ROLE)
    function initialize(
        AgentRegistry _registry,
        uint256 _mintPrice,
        uint256 _maxSupply,
        address _admin
    ) external initializer {
        registry = _registry;
        mintPrice = _mintPrice;
        maxSupply = _maxSupply;
        open = false;
        publicMinting = false; // Default to private minting
        
        // Grant roles to admin - DEFAULT_ADMIN_ROLE for role management, ADMIN_ROLE for admin functions, MINTER_ROLE for private minting
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
    }

    /* --- Minting Functions --- */

    /// @notice Mint an agent to the caller
    /// @return agentId The ID of the minted agent
    function mint() external payable returns (uint256 agentId) {
        return _mintSimple(msg.sender);
    }

    /// @notice Mint an agent to a specific address
    /// @param to The address to receive the agent
    /// @return agentId The ID of the minted agent
    function mint(address to) external payable returns (uint256 agentId) {
        return _mintSimple(to);
    }

    /// @notice Mint an agent with basic metadata
    /// @param to The address to receive the agent
    /// @param endpointType The type of endpoint (e.g., "mcp", "a2a")
    /// @param endpoint The agent's endpoint URL
    /// @param agentAccount The agent's wallet address
    /// @return agentId The ID of the minted agent
    function mint(
        address to,
        string calldata endpointType,
        string calldata endpoint,
        address agentAccount
    ) external payable returns (uint256 agentId) {
        return _mintWithBasicMetadata(to, endpointType, endpoint, agentAccount);
    }

    /// @notice Mint an agent with flexible metadata
    /// @param to The address to receive the agent
    /// @param metadata Array of key-value metadata entries
    /// @return agentId The ID of the minted agent
    function mint(
        address to,
        IAgentRegistry.MetadataEntry[] calldata metadata
    ) external payable returns (uint256 agentId) {
        return _mintWithMetadata(to, metadata);
    }

    /// @notice Mint multiple agents to the caller
    /// @param count Number of agents to mint
    /// @return agentIds Array of minted agent IDs
    function mintBatch(uint256 count) external payable returns (uint256[] memory agentIds) {
        return _mintBatch(msg.sender, count);
    }

    /// @notice Mint multiple agents to a specific address
    /// @param to The address to receive the agents
    /// @param count Number of agents to mint
    /// @return agentIds Array of minted agent IDs
    function mintBatch(address to, uint256 count) external payable returns (uint256[] memory agentIds) {
        return _mintBatch(to, count);
    }

    /// @notice Mint multiple agents with metadata to a specific address
    /// @param to The address to receive the agents
    /// @param metadata Array of metadata arrays (one per agent)
    /// @return agentIds Array of minted agent IDs
    function mintBatch(
        address to,
        IAgentRegistry.MetadataEntry[][] calldata metadata
    ) external payable returns (uint256[] memory agentIds) {
        return _mintBatchWithMetadata(to, metadata);
    }

    /* --- Admin Functions --- */

    /// @notice Open minting
    /// @param _publicMinting True for public minting, false for private (MINTER_ROLE only)
    function openMinting(bool _publicMinting) external onlyRole(ADMIN_ROLE) {
        if (lockBits & LOCK_OPEN_CLOSE != 0) revert FunctionLocked();
        open = true;
        publicMinting = _publicMinting;
        emit MintingOpened(_publicMinting);
    }

    /// @notice Close minting
    function closeMinting() external onlyRole(ADMIN_ROLE) {
        if (lockBits & LOCK_OPEN_CLOSE != 0) revert FunctionLocked();
        open = false;
        emit MintingClosed();
    }

    /// @notice Set the mint price
    /// @param newPrice New price in wei
    function setMintPrice(uint256 newPrice) external onlyRole(ADMIN_ROLE) {
        if (lockBits & LOCK_MINT_PRICE != 0) revert FunctionLocked();
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit MintPriceUpdated(oldPrice, newPrice);
    }

    /// @notice Set the max supply
    /// @param newMaxSupply New maximum supply (0 = unlimited)
    function setMaxSupply(uint256 newMaxSupply) external onlyRole(ADMIN_ROLE) {
        if (lockBits & LOCK_MAX_SUPPLY != 0) revert FunctionLocked();
        if (newMaxSupply != 0 && newMaxSupply < totalMinted) {
            revert MaxSupplyTooLow(newMaxSupply, totalMinted);
        }
        uint256 oldSupply = maxSupply;
        maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(oldSupply, newMaxSupply);
    }

    /// @notice Permanently lock a function
    /// @param lockBit The lock bit to set (LOCK_OPEN_CLOSE, LOCK_MINT_PRICE, or LOCK_MAX_SUPPLY)
    function setLockBit(uint256 lockBit) external onlyRole(ADMIN_ROLE) {
        if (lockBit != LOCK_OPEN_CLOSE && lockBit != LOCK_MINT_PRICE && lockBit != LOCK_MAX_SUPPLY) {
            revert InvalidLockBit();
        }
        lockBits |= lockBit;
        emit LockBitSet(lockBit);
    }

    /// @notice Withdraw all ETH to the caller (must have ADMIN_ROLE)
    function withdraw() external onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) revert TransferFailed();
        emit Withdrawn(msg.sender, balance);
    }

    /// @notice Withdraw a specific amount of ETH to the caller (must have ADMIN_ROLE)
    /// @param amount Amount to withdraw
    function withdraw(uint256 amount) external onlyRole(ADMIN_ROLE) nonReentrant {
        if (amount > address(this).balance) revert TransferFailed();
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    /* --- View Functions --- */

    /// @notice Get the remaining supply available for minting
    /// @return remaining Number of agents that can still be minted (type(uint256).max if unlimited)
    function remainingSupply() external view returns (uint256 remaining) {
        if (maxSupply == 0) return type(uint256).max;
        return maxSupply - totalMinted;
    }

    /// @notice Check if a specific lock bit is set
    /// @param lockBit The lock bit to check
    /// @return locked Whether the lock bit is set
    function isLocked(uint256 lockBit) external view returns (bool locked) {
        return lockBits & lockBit != 0;
    }

    /* --- Internal Functions --- */

    /// @dev Check mint prerequisites and handle payment
    function _checkMintAndPay(uint256 count) internal {
        if (!open) revert MintingNotOpen();
        
        // Check if minting is private and caller doesn't have MINTER_ROLE
        if (!publicMinting && !hasRole(MINTER_ROLE, msg.sender)) {
            revert NotMinter();
        }
        
        if (maxSupply != 0 && totalMinted + count > maxSupply) {
            revert MaxSupplyExceeded(count, maxSupply == 0 ? 0 : maxSupply - totalMinted);
        }
        
        uint256 totalCost = mintPrice * count;
        if (msg.value < totalCost) {
            revert InsufficientPayment(msg.value, totalCost);
        }

        // Refund overpayment
        uint256 overpayment = msg.value - totalCost;
        if (overpayment > 0) {
            (bool success, ) = payable(msg.sender).call{value: overpayment}("");
            if (!success) revert TransferFailed();
        }
    }

    /// @dev Internal simple mint function (no metadata)
    function _mintSimple(address to) internal returns (uint256 agentId) {
        _checkMintAndPay(1);

        // Mint the agent without metadata
        agentId = registry.register(to, "", "", address(0));
        totalMinted++;

        emit AgentMinted(agentId, to, totalMinted);
    }

    /// @dev Internal mint function with basic metadata
    function _mintWithBasicMetadata(
        address to,
        string calldata endpointType,
        string calldata endpoint,
        address agentAccount
    ) internal returns (uint256 agentId) {
        _checkMintAndPay(1);

        // Mint the agent with metadata
        agentId = registry.register(to, endpointType, endpoint, agentAccount);
        totalMinted++;

        emit AgentMinted(agentId, to, totalMinted);
    }

    /// @dev Internal mint function with flexible metadata
    function _mintWithMetadata(
        address to,
        IAgentRegistry.MetadataEntry[] calldata metadata
    ) internal returns (uint256 agentId) {
        _checkMintAndPay(1);

        // Mint the agent with metadata
        agentId = registry.register(to, metadata);
        totalMinted++;

        emit AgentMinted(agentId, to, totalMinted);
    }

    /// @dev Internal batch mint function (no metadata)
    function _mintBatch(address to, uint256 count) internal returns (uint256[] memory agentIds) {
        _checkMintAndPay(count);

        agentIds = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            agentIds[i] = registry.register(to, "", "", address(0));
            totalMinted++;
            emit AgentMinted(agentIds[i], to, totalMinted);
        }
    }

    /// @dev Internal batch mint function with metadata
    function _mintBatchWithMetadata(
        address to,
        IAgentRegistry.MetadataEntry[][] calldata metadata
    ) internal returns (uint256[] memory agentIds) {
        uint256 count = metadata.length;
        _checkMintAndPay(count);

        agentIds = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            agentIds[i] = registry.register(to, metadata[i]);
            totalMinted++;
            emit AgentMinted(agentIds[i], to, totalMinted);
        }
    }

    /// @notice Receive ETH
    receive() external payable {}
}
