// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AgentRegistry} from "./AgentRegistry.sol";
import {AgentRegistrar} from "./AgentRegistrar.sol";

/// @title AgentRegistryFactory
/// @notice Factory contract for deploying minimal clone (EIP-1167) instances of AgentRegistry and AgentRegistrar
/// @dev Uses OpenZeppelin's Clones library for gas-efficient proxy deployment
contract AgentRegistryFactory {
    using Clones for address;

    /* --- Events --- */

    /// @notice Emitted when a new AgentRegistry clone is deployed
    /// @param registry The address of the newly deployed registry clone
    /// @param admin The admin address for the new registry
    /// @param salt The salt used for deterministic deployment (0 if not deterministic)
    event RegistryDeployed(address indexed registry, address indexed admin, bytes32 salt);

    /// @notice Emitted when a new AgentRegistrar clone is deployed
    /// @param registrar The address of the newly deployed registrar clone
    /// @param registry The registry the registrar mints to
    /// @param owner The owner of the registrar
    event RegistrarDeployed(address indexed registrar, address indexed registry, address indexed owner);

    /// @notice Emitted when both registry and registrar are deployed together
    /// @param registry The address of the registry
    /// @param registrar The address of the registrar
    /// @param admin The admin/owner address
    event RegistryAndRegistrarDeployed(address indexed registry, address indexed registrar, address indexed admin);

    /* --- State Variables --- */

    /// @notice The AgentRegistry implementation contract address
    address public immutable registryImplementation;

    /// @notice The AgentRegistrar implementation contract address
    address public immutable registrarImplementation;

    /// @notice Array of all deployed registry clones
    address[] public deployedRegistries;

    /// @notice Array of all deployed registrar clones
    address[] public deployedRegistrars;

    /// @notice Mapping to check if an address is a deployed registry from this factory
    mapping(address => bool) public isDeployedRegistry;

    /// @notice Mapping to check if an address is a deployed registrar from this factory
    mapping(address => bool) public isDeployedRegistrar;

    /// @notice Mapping from registry to its associated registrar (if deployed together)
    mapping(address registry => address registrar) public registryToRegistrar;

    /* --- Constructor --- */

    /// @notice Deploy the factory with new implementation contracts
    /// @dev Creates AgentRegistry and AgentRegistrar implementations for cloning
    constructor() {
        registryImplementation = address(new AgentRegistry());
        // Deploy registrar implementation with dummy values (will be overwritten on clone init)
        registrarImplementation = address(new AgentRegistrar(
            AgentRegistry(registryImplementation),
            0,
            0,
            address(this)
        ));
    }

    /* --- Registry Deployment --- */

    /// @notice Deploy a new AgentRegistry clone
    /// @param admin The address to receive all admin roles in the new registry
    /// @return registry The address of the newly deployed registry
    function deployRegistry(address admin) external returns (address registry) {
        registry = registryImplementation.clone();
        AgentRegistry(registry).initialize(admin);
        
        deployedRegistries.push(registry);
        isDeployedRegistry[registry] = true;
        
        emit RegistryDeployed(registry, admin, bytes32(0));
    }

    /// @notice Deploy a new AgentRegistry clone with a name
    /// @param admin The address to receive all admin roles in the new registry
    /// @param name The name for the registry (stored as ERC-8049 contract metadata)
    /// @return registry The address of the newly deployed registry
    function deployRegistry(address admin, string calldata name) external returns (address registry) {
        registry = registryImplementation.clone();
        AgentRegistry reg = AgentRegistry(registry);
        
        // Initialize with factory as admin so we can set metadata
        reg.initialize(address(this));
        
        // Set the name metadata
        reg.setContractMetadata("name", bytes(name));
        
        // Grant all roles to admin
        reg.grantRole(reg.DEFAULT_ADMIN_ROLE(), admin);
        reg.grantRole(reg.REGISTRAR_ROLE(), admin);
        reg.grantRole(reg.METADATA_ADMIN_ROLE(), admin);
        
        // Renounce factory's roles
        reg.renounceRole(reg.DEFAULT_ADMIN_ROLE(), address(this));
        reg.renounceRole(reg.REGISTRAR_ROLE(), address(this));
        reg.renounceRole(reg.METADATA_ADMIN_ROLE(), address(this));
        
        deployedRegistries.push(registry);
        isDeployedRegistry[registry] = true;
        
        emit RegistryDeployed(registry, admin, bytes32(0));
    }

    /// @notice Deploy a new AgentRegistry clone with a deterministic address
    /// @param admin The address to receive all admin roles in the new registry
    /// @param salt The salt for deterministic address generation
    /// @return registry The address of the newly deployed registry
    function deployRegistryDeterministic(address admin, bytes32 salt) external returns (address registry) {
        registry = registryImplementation.cloneDeterministic(salt);
        AgentRegistry(registry).initialize(admin);
        
        deployedRegistries.push(registry);
        isDeployedRegistry[registry] = true;
        
        emit RegistryDeployed(registry, admin, salt);
    }

    /// @notice Deploy a new AgentRegistry clone with a deterministic address and a name
    /// @param admin The address to receive all admin roles in the new registry
    /// @param salt The salt for deterministic address generation
    /// @param name The name for the registry (stored as ERC-8049 contract metadata)
    /// @return registry The address of the newly deployed registry
    function deployRegistryDeterministic(address admin, bytes32 salt, string calldata name) external returns (address registry) {
        registry = registryImplementation.cloneDeterministic(salt);
        AgentRegistry reg = AgentRegistry(registry);
        
        // Initialize with factory as admin so we can set metadata
        reg.initialize(address(this));
        
        // Set the name metadata
        reg.setContractMetadata("name", bytes(name));
        
        // Grant all roles to admin
        reg.grantRole(reg.DEFAULT_ADMIN_ROLE(), admin);
        reg.grantRole(reg.REGISTRAR_ROLE(), admin);
        reg.grantRole(reg.METADATA_ADMIN_ROLE(), admin);
        
        // Renounce factory's roles
        reg.renounceRole(reg.DEFAULT_ADMIN_ROLE(), address(this));
        reg.renounceRole(reg.REGISTRAR_ROLE(), address(this));
        reg.renounceRole(reg.METADATA_ADMIN_ROLE(), address(this));
        
        deployedRegistries.push(registry);
        isDeployedRegistry[registry] = true;
        
        emit RegistryDeployed(registry, admin, salt);
    }

    /* --- Registrar Deployment --- */

    /// @notice Deploy a new AgentRegistrar clone for an existing registry
    /// @param registry The AgentRegistry to mint to
    /// @param mintPrice Price per mint in wei (0 = free)
    /// @param maxSupply Maximum supply (0 = unlimited)
    /// @param owner Owner of the registrar
    /// @return registrar The address of the newly deployed registrar
    function deployRegistrar(
        AgentRegistry registry,
        uint256 mintPrice,
        uint256 maxSupply,
        address owner
    ) external returns (address registrar) {
        registrar = registrarImplementation.clone();
        AgentRegistrar(payable(registrar)).initialize(registry, mintPrice, maxSupply, owner);
        
        deployedRegistrars.push(registrar);
        isDeployedRegistrar[registrar] = true;
        
        emit RegistrarDeployed(registrar, address(registry), owner);
    }

    /* --- Combined Deployment --- */

    /// @notice Deploy both a registry and registrar together
    /// @param admin The admin for the registry and owner of the registrar
    /// @param mintPrice Price per mint in wei (0 = free)
    /// @param maxSupply Maximum supply (0 = unlimited)
    /// @return registry The address of the deployed registry
    /// @return registrar The address of the deployed registrar
    function deploy(
        address admin,
        uint256 mintPrice,
        uint256 maxSupply
    ) external returns (address registry, address registrar) {
        // Deploy registry with factory as initial admin
        registry = registryImplementation.clone();
        AgentRegistry(registry).initialize(address(this));
        
        deployedRegistries.push(registry);
        isDeployedRegistry[registry] = true;
        
        // Deploy registrar
        registrar = registrarImplementation.clone();
        AgentRegistrar(payable(registrar)).initialize(
            AgentRegistry(registry),
            mintPrice,
            maxSupply,
            admin
        );
        
        deployedRegistrars.push(registrar);
        isDeployedRegistrar[registrar] = true;
        registryToRegistrar[registry] = registrar;
        
        // Grant roles: REGISTRAR_ROLE to registrar, all roles to admin
        AgentRegistry reg = AgentRegistry(registry);
        reg.grantRole(reg.REGISTRAR_ROLE(), registrar);
        reg.grantRole(reg.DEFAULT_ADMIN_ROLE(), admin);
        reg.grantRole(reg.REGISTRAR_ROLE(), admin);
        reg.grantRole(reg.METADATA_ADMIN_ROLE(), admin);
        
        // Renounce factory's admin role
        reg.renounceRole(reg.DEFAULT_ADMIN_ROLE(), address(this));
        reg.renounceRole(reg.REGISTRAR_ROLE(), address(this));
        reg.renounceRole(reg.METADATA_ADMIN_ROLE(), address(this));
        
        emit RegistryDeployed(registry, admin, bytes32(0));
        emit RegistrarDeployed(registrar, registry, admin);
        emit RegistryAndRegistrarDeployed(registry, registrar, admin);
    }

    /// @notice Deploy both a registry and registrar together with a name
    /// @param admin The admin for the registry and owner of the registrar
    /// @param mintPrice Price per mint in wei (0 = free)
    /// @param maxSupply Maximum supply (0 = unlimited)
    /// @param name The name for the registry (stored as ERC-8049 contract metadata)
    /// @return registry The address of the deployed registry
    /// @return registrar The address of the deployed registrar
    function deploy(
        address admin,
        uint256 mintPrice,
        uint256 maxSupply,
        string calldata name
    ) external returns (address registry, address registrar) {
        // Deploy registry with factory as initial admin
        registry = registryImplementation.clone();
        AgentRegistry reg = AgentRegistry(registry);
        reg.initialize(address(this));
        
        deployedRegistries.push(registry);
        isDeployedRegistry[registry] = true;
        
        // Set the name metadata
        reg.setContractMetadata("name", bytes(name));
        
        // Deploy registrar
        registrar = registrarImplementation.clone();
        AgentRegistrar(payable(registrar)).initialize(
            reg,
            mintPrice,
            maxSupply,
            admin
        );
        
        deployedRegistrars.push(registrar);
        isDeployedRegistrar[registrar] = true;
        registryToRegistrar[registry] = registrar;
        
        // Grant roles: REGISTRAR_ROLE to registrar, all roles to admin
        reg.grantRole(reg.REGISTRAR_ROLE(), registrar);
        reg.grantRole(reg.DEFAULT_ADMIN_ROLE(), admin);
        reg.grantRole(reg.REGISTRAR_ROLE(), admin);
        reg.grantRole(reg.METADATA_ADMIN_ROLE(), admin);
        
        // Renounce factory's admin role
        reg.renounceRole(reg.DEFAULT_ADMIN_ROLE(), address(this));
        reg.renounceRole(reg.REGISTRAR_ROLE(), address(this));
        reg.renounceRole(reg.METADATA_ADMIN_ROLE(), address(this));
        
        emit RegistryDeployed(registry, admin, bytes32(0));
        emit RegistrarDeployed(registrar, registry, admin);
        emit RegistryAndRegistrarDeployed(registry, registrar, admin);
    }

    /// @notice Deploy both a registry and registrar with deterministic addresses
    /// @param admin The admin for the registry and owner of the registrar
    /// @param mintPrice Price per mint in wei (0 = free)
    /// @param maxSupply Maximum supply (0 = unlimited)
    /// @param registrySalt Salt for registry address
    /// @param registrarSalt Salt for registrar address
    /// @return registry The address of the deployed registry
    /// @return registrar The address of the deployed registrar
    function deployDeterministic(
        address admin,
        uint256 mintPrice,
        uint256 maxSupply,
        bytes32 registrySalt,
        bytes32 registrarSalt
    ) external returns (address registry, address registrar) {
        // Deploy registry with factory as initial admin
        registry = registryImplementation.cloneDeterministic(registrySalt);
        AgentRegistry(registry).initialize(address(this));
        
        deployedRegistries.push(registry);
        isDeployedRegistry[registry] = true;
        
        // Deploy registrar
        registrar = registrarImplementation.cloneDeterministic(registrarSalt);
        AgentRegistrar(payable(registrar)).initialize(
            AgentRegistry(registry),
            mintPrice,
            maxSupply,
            admin
        );
        
        deployedRegistrars.push(registrar);
        isDeployedRegistrar[registrar] = true;
        registryToRegistrar[registry] = registrar;
        
        // Grant roles: REGISTRAR_ROLE to registrar, all roles to admin
        AgentRegistry reg = AgentRegistry(registry);
        reg.grantRole(reg.REGISTRAR_ROLE(), registrar);
        reg.grantRole(reg.DEFAULT_ADMIN_ROLE(), admin);
        reg.grantRole(reg.REGISTRAR_ROLE(), admin);
        reg.grantRole(reg.METADATA_ADMIN_ROLE(), admin);
        
        // Renounce factory's admin role
        reg.renounceRole(reg.DEFAULT_ADMIN_ROLE(), address(this));
        reg.renounceRole(reg.REGISTRAR_ROLE(), address(this));
        reg.renounceRole(reg.METADATA_ADMIN_ROLE(), address(this));
        
        emit RegistryDeployed(registry, admin, registrySalt);
        emit RegistrarDeployed(registrar, registry, admin);
        emit RegistryAndRegistrarDeployed(registry, registrar, admin);
    }

    /// @notice Deploy both a registry and registrar with deterministic addresses and a name
    /// @param admin The admin for the registry and owner of the registrar
    /// @param mintPrice Price per mint in wei (0 = free)
    /// @param maxSupply Maximum supply (0 = unlimited)
    /// @param registrySalt Salt for registry address
    /// @param registrarSalt Salt for registrar address
    /// @param name The name for the registry (stored as ERC-8049 contract metadata)
    /// @return registry The address of the deployed registry
    /// @return registrar The address of the deployed registrar
    function deployDeterministic(
        address admin,
        uint256 mintPrice,
        uint256 maxSupply,
        bytes32 registrySalt,
        bytes32 registrarSalt,
        string calldata name
    ) external returns (address registry, address registrar) {
        // Deploy registry with factory as initial admin
        registry = registryImplementation.cloneDeterministic(registrySalt);
        AgentRegistry reg = AgentRegistry(registry);
        reg.initialize(address(this));
        
        deployedRegistries.push(registry);
        isDeployedRegistry[registry] = true;
        
        // Set the name metadata
        reg.setContractMetadata("name", bytes(name));
        
        // Deploy registrar
        registrar = registrarImplementation.cloneDeterministic(registrarSalt);
        AgentRegistrar(payable(registrar)).initialize(
            reg,
            mintPrice,
            maxSupply,
            admin
        );
        
        deployedRegistrars.push(registrar);
        isDeployedRegistrar[registrar] = true;
        registryToRegistrar[registry] = registrar;
        
        // Grant roles: REGISTRAR_ROLE to registrar, all roles to admin
        reg.grantRole(reg.REGISTRAR_ROLE(), registrar);
        reg.grantRole(reg.DEFAULT_ADMIN_ROLE(), admin);
        reg.grantRole(reg.REGISTRAR_ROLE(), admin);
        reg.grantRole(reg.METADATA_ADMIN_ROLE(), admin);
        
        // Renounce factory's admin role
        reg.renounceRole(reg.DEFAULT_ADMIN_ROLE(), address(this));
        reg.renounceRole(reg.REGISTRAR_ROLE(), address(this));
        reg.renounceRole(reg.METADATA_ADMIN_ROLE(), address(this));
        
        emit RegistryDeployed(registry, admin, registrySalt);
        emit RegistrarDeployed(registrar, registry, admin);
        emit RegistryAndRegistrarDeployed(registry, registrar, admin);
    }

    /* --- Address Prediction --- */

    /// @notice Predict the address of a deterministic registry clone
    /// @param salt The salt that will be used for deployment
    /// @return predicted The predicted address of the registry
    function predictRegistryAddress(bytes32 salt) external view returns (address predicted) {
        return registryImplementation.predictDeterministicAddress(salt, address(this));
    }

    /// @notice Predict the address of a deterministic registrar clone
    /// @param salt The salt that will be used for deployment
    /// @return predicted The predicted address of the registrar
    function predictRegistrarAddress(bytes32 salt) external view returns (address predicted) {
        return registrarImplementation.predictDeterministicAddress(salt, address(this));
    }

    /* --- View Functions --- */

    /// @notice Get the total number of deployed registries
    /// @return count The number of deployed registries
    function getDeployedRegistriesCount() external view returns (uint256 count) {
        return deployedRegistries.length;
    }

    /// @notice Get the total number of deployed registrars
    /// @return count The number of deployed registrars
    function getDeployedRegistrarsCount() external view returns (uint256 count) {
        return deployedRegistrars.length;
    }

    /// @notice Get a range of deployed registries
    /// @param start The starting index (inclusive)
    /// @param end The ending index (exclusive)
    /// @return registries Array of registry addresses in the specified range
    function getDeployedRegistries(uint256 start, uint256 end) external view returns (address[] memory registries) {
        require(start < end, "Invalid range");
        require(end <= deployedRegistries.length, "End out of bounds");
        
        registries = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            registries[i - start] = deployedRegistries[i];
        }
    }

    /// @notice Get a range of deployed registrars
    /// @param start The starting index (inclusive)
    /// @param end The ending index (exclusive)
    /// @return registrars Array of registrar addresses in the specified range
    function getDeployedRegistrars(uint256 start, uint256 end) external view returns (address[] memory registrars) {
        require(start < end, "Invalid range");
        require(end <= deployedRegistrars.length, "End out of bounds");
        
        registrars = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            registrars[i - start] = deployedRegistrars[i];
        }
    }

    /* --- Legacy Support --- */

    /// @notice Deploy a new AgentRegistry clone (legacy function name)
    /// @param admin The address to receive all admin roles in the new registry
    /// @return registry The address of the newly deployed registry
    /// @dev This function is kept for backward compatibility. Use deployRegistry() for new integrations.
    function deploy(address admin) external returns (address registry) {
        registry = registryImplementation.clone();
        AgentRegistry(registry).initialize(admin);
        
        deployedRegistries.push(registry);
        isDeployedRegistry[registry] = true;
        
        emit RegistryDeployed(registry, admin, bytes32(0));
    }

    /// @notice Get the implementation address (legacy, returns registry implementation)
    /// @return The registry implementation address
    /// @dev Kept for backward compatibility
    function implementation() external view returns (address) {
        return registryImplementation;
    }
}
