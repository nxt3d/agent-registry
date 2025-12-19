// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AgentRegistry} from "./AgentRegistry.sol";

/// @title AgentRegistryFactory
/// @notice Factory contract for deploying minimal clone (EIP-1167) instances of AgentRegistry
/// @dev Uses OpenZeppelin's Clones library for gas-efficient proxy deployment
contract AgentRegistryFactory {
    using Clones for address;

    /* --- Events --- */

    /// @notice Emitted when a new AgentRegistry clone is deployed
    /// @param registry The address of the newly deployed registry clone
    /// @param admin The admin address for the new registry
    /// @param salt The salt used for deterministic deployment (0 if not deterministic)
    event RegistryDeployed(address indexed registry, address indexed admin, bytes32 salt);

    /* --- State Variables --- */

    /// @notice The implementation contract address used for cloning
    address public immutable implementation;

    /// @notice Array of all deployed registry clones
    address[] public deployedRegistries;

    /// @notice Mapping to check if an address is a deployed clone from this factory
    mapping(address => bool) public isDeployedRegistry;

    /* --- Constructor --- */

    /// @notice Deploy the factory with a new implementation contract
    /// @dev Creates a new AgentRegistry implementation that will be used for all clones
    constructor() {
        implementation = address(new AgentRegistry());
    }

    /* --- External Functions --- */

    /// @notice Deploy a new AgentRegistry clone
    /// @param admin The address to receive all admin roles in the new registry
    /// @return registry The address of the newly deployed registry
    function deploy(address admin) external returns (address registry) {
        registry = implementation.clone();
        AgentRegistry(registry).initialize(admin);
        
        deployedRegistries.push(registry);
        isDeployedRegistry[registry] = true;
        
        emit RegistryDeployed(registry, admin, bytes32(0));
    }

    /// @notice Deploy a new AgentRegistry clone with a deterministic address
    /// @param admin The address to receive all admin roles in the new registry
    /// @param salt The salt for deterministic address generation
    /// @return registry The address of the newly deployed registry
    function deployDeterministic(address admin, bytes32 salt) external returns (address registry) {
        registry = implementation.cloneDeterministic(salt);
        AgentRegistry(registry).initialize(admin);
        
        deployedRegistries.push(registry);
        isDeployedRegistry[registry] = true;
        
        emit RegistryDeployed(registry, admin, salt);
    }

    /// @notice Predict the address of a deterministic clone before deployment
    /// @param salt The salt that will be used for deployment
    /// @return predicted The predicted address of the clone
    function predictDeterministicAddress(bytes32 salt) external view returns (address predicted) {
        return implementation.predictDeterministicAddress(salt, address(this));
    }

    /// @notice Get the total number of deployed registries
    /// @return count The number of deployed registries
    function getDeployedRegistriesCount() external view returns (uint256 count) {
        return deployedRegistries.length;
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
}

