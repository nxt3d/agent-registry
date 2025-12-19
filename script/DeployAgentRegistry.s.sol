// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/AgentRegistry.sol";
import "../src/AgentRegistryFactory.sol";

/**
 * @title DeployAgentRegistry
 * @dev Deployment script for standalone AgentRegistry contract
 * 
 * Usage:
 *   forge script script/DeployAgentRegistry.s.sol:DeployAgentRegistry --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 * 
 * Environment variables required:
 *   - DEPLOYER_PRIVATE_KEY: Private key of the deployer
 *   - ETHERSCAN_API_KEY: API key for contract verification (optional)
 */
contract DeployAgentRegistry is Script {
    function run() external returns (AgentRegistry registry) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying AgentRegistry (standalone)...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        registry = new AgentRegistry();

        // Set initial contract metadata
        registry.setContractMetadata("name", bytes("Agent Registry"));
        registry.setContractMetadata("description", bytes("A minimal onchain registry for discovering AI agents"));

        vm.stopBroadcast();

        console.log("AgentRegistry deployed at:", address(registry));
        console.log("Deployer has DEFAULT_ADMIN_ROLE, REGISTRAR_ROLE, and METADATA_ADMIN_ROLE");

        return registry;
    }
}

/**
 * @title DeployAgentRegistryWithRoles
 * @dev Deployment script that sets up additional roles
 * 
 * Usage:
 *   REGISTRAR_ADDRESS=0x... METADATA_ADMIN_ADDRESS=0x... forge script script/DeployAgentRegistry.s.sol:DeployAgentRegistryWithRoles --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 */
contract DeployAgentRegistryWithRoles is Script {
    function run() external returns (AgentRegistry registry) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Optional additional role addresses
        address registrar = vm.envOr("REGISTRAR_ADDRESS", deployer);
        address metadataAdmin = vm.envOr("METADATA_ADMIN_ADDRESS", deployer);

        console.log("Deploying AgentRegistry (standalone)...");
        console.log("Deployer address:", deployer);
        console.log("Registrar address:", registrar);
        console.log("Metadata Admin address:", metadataAdmin);

        vm.startBroadcast(deployerPrivateKey);

        registry = new AgentRegistry();

        // Grant additional roles if different from deployer
        if (registrar != deployer) {
            registry.grantRole(registry.REGISTRAR_ROLE(), registrar);
        }
        if (metadataAdmin != deployer) {
            registry.grantRole(registry.METADATA_ADMIN_ROLE(), metadataAdmin);
        }

        // Set initial contract metadata
        registry.setContractMetadata("name", bytes("Agent Registry"));
        registry.setContractMetadata("description", bytes("A minimal onchain registry for discovering AI agents"));

        vm.stopBroadcast();

        console.log("AgentRegistry deployed at:", address(registry));

        return registry;
    }
}

/**
 * @title DeployAgentRegistryFactory
 * @dev Deployment script for AgentRegistryFactory contract (EIP-1167 minimal clones)
 * 
 * Usage:
 *   forge script script/DeployAgentRegistry.s.sol:DeployAgentRegistryFactory --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 * 
 * Environment variables required:
 *   - DEPLOYER_PRIVATE_KEY: Private key of the deployer
 *   - ETHERSCAN_API_KEY: API key for contract verification (optional)
 */
contract DeployAgentRegistryFactory is Script {
    function run() external returns (AgentRegistryFactory factory) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying AgentRegistryFactory...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        factory = new AgentRegistryFactory();

        vm.stopBroadcast();

        console.log("AgentRegistryFactory deployed at:", address(factory));
        console.log("Implementation contract at:", factory.implementation());
        console.log("");
        console.log("To deploy a new registry clone, call:");
        console.log("  factory.deploy(adminAddress)");
        console.log("Or for deterministic address:");
        console.log("  factory.deployDeterministic(adminAddress, salt)");

        return factory;
    }
}

/**
 * @title DeployFactoryAndClone
 * @dev Deployment script that deploys the factory and creates an initial clone
 * 
 * Usage:
 *   forge script script/DeployAgentRegistry.s.sol:DeployFactoryAndClone --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 * 
 * Environment variables:
 *   - DEPLOYER_PRIVATE_KEY: Private key of the deployer
 *   - REGISTRY_ADMIN: (Optional) Admin for the first registry clone (defaults to deployer)
 *   - ETHERSCAN_API_KEY: API key for contract verification (optional)
 */
contract DeployFactoryAndClone is Script {
    function run() external returns (AgentRegistryFactory factory, address registry) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address registryAdmin = vm.envOr("REGISTRY_ADMIN", deployer);

        console.log("Deploying AgentRegistryFactory and initial clone...");
        console.log("Deployer address:", deployer);
        console.log("Registry admin:", registryAdmin);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy factory
        factory = new AgentRegistryFactory();

        // Deploy first registry clone
        registry = factory.deploy(registryAdmin);

        // Set initial contract metadata on the clone
        AgentRegistry(registry).setContractMetadata("name", bytes("Agent Registry"));
        AgentRegistry(registry).setContractMetadata("description", bytes("A minimal onchain registry for discovering AI agents"));

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("AgentRegistryFactory:", address(factory));
        console.log("Implementation:", factory.implementation());
        console.log("First Registry Clone:", registry);
        console.log("");
        console.log("Registry admin has DEFAULT_ADMIN_ROLE, REGISTRAR_ROLE, and METADATA_ADMIN_ROLE");

        return (factory, registry);
    }
}

/**
 * @title DeployCloneFromFactory
 * @dev Deployment script to create a new clone from an existing factory
 * 
 * Usage:
 *   FACTORY_ADDRESS=0x... forge script script/DeployAgentRegistry.s.sol:DeployCloneFromFactory --rpc-url $SEPOLIA_RPC_URL --broadcast
 * 
 * Environment variables:
 *   - DEPLOYER_PRIVATE_KEY: Private key of the deployer
 *   - FACTORY_ADDRESS: Address of the existing factory
 *   - REGISTRY_ADMIN: (Optional) Admin for the new registry (defaults to deployer)
 *   - DETERMINISTIC_SALT: (Optional) Salt for deterministic address deployment
 */
contract DeployCloneFromFactory is Script {
    function run() external returns (address registry) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        address registryAdmin = vm.envOr("REGISTRY_ADMIN", deployer);
        bytes32 salt = vm.envOr("DETERMINISTIC_SALT", bytes32(0));

        AgentRegistryFactory factory = AgentRegistryFactory(factoryAddress);

        console.log("Deploying new registry clone...");
        console.log("Factory address:", factoryAddress);
        console.log("Registry admin:", registryAdmin);

        vm.startBroadcast(deployerPrivateKey);

        if (salt != bytes32(0)) {
            console.log("Using deterministic deployment with salt:", vm.toString(salt));
            address predicted = factory.predictDeterministicAddress(salt);
            console.log("Predicted address:", predicted);
            registry = factory.deployDeterministic(registryAdmin, salt);
        } else {
            registry = factory.deploy(registryAdmin);
        }

        // Set initial contract metadata
        AgentRegistry(registry).setContractMetadata("name", bytes("Agent Registry"));
        AgentRegistry(registry).setContractMetadata("description", bytes("A minimal onchain registry for discovering AI agents"));

        vm.stopBroadcast();

        console.log("New Registry Clone deployed at:", registry);
        console.log("Total registries from factory:", factory.getDeployedRegistriesCount());

        return registry;
    }
}

