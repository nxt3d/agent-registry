// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/AgentRegistry.sol";
import "../src/AgentRegistryFactory.sol";
import "../src/AgentRegistrar.sol";

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
        console.log("Registry Implementation:", factory.registryImplementation());
        console.log("Registrar Implementation:", factory.registrarImplementation());
        console.log("");
        console.log("To deploy registry + registrar:");
        console.log("  factory.deploy(admin, mintPrice, maxSupply)");
        console.log("To deploy registry only:");
        console.log("  factory.deployRegistry(admin)");

        return factory;
    }
}

/**
 * @title DeployRegistryAndRegistrar
 * @dev Deployment script that deploys factory and creates a registry + registrar pair
 * 
 * Usage:
 *   MINT_PRICE=10000000000000000 MAX_SUPPLY=1000 forge script script/DeployAgentRegistry.s.sol:DeployRegistryAndRegistrar --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 * 
 * Environment variables:
 *   - DEPLOYER_PRIVATE_KEY: Private key of the deployer
 *   - MINT_PRICE: Price per mint in wei (default: 0.01 ether)
 *   - MAX_SUPPLY: Maximum supply (default: 0 = unlimited)
 *   - ETHERSCAN_API_KEY: API key for contract verification (optional)
 */
contract DeployRegistryAndRegistrar is Script {
    function run() external returns (AgentRegistryFactory factory, address registry, address registrar) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        uint256 mintPrice = vm.envOr("MINT_PRICE", uint256(0.01 ether));
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", uint256(0));

        console.log("Deploying AgentRegistryFactory with Registry and Registrar...");
        console.log("Deployer address:", deployer);
        console.log("Mint price:", mintPrice);
        console.log("Max supply:", maxSupply == 0 ? "Unlimited" : vm.toString(maxSupply));

        vm.startBroadcast(deployerPrivateKey);

        // Deploy factory
        factory = new AgentRegistryFactory();

        // Deploy registry + registrar pair
        (registry, registrar) = factory.deploy(deployer, mintPrice, maxSupply);

        // Set initial contract metadata on the registry
        AgentRegistry(registry).setContractMetadata("name", bytes("Agent Registry"));
        AgentRegistry(registry).setContractMetadata("description", bytes("A minimal onchain registry for discovering AI agents"));

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("AgentRegistryFactory:", address(factory));
        console.log("Registry Implementation:", factory.registryImplementation());
        console.log("Registrar Implementation:", factory.registrarImplementation());
        console.log("");
        console.log("Registry:", registry);
        console.log("Registrar:", registrar);
        console.log("");
        console.log("Admin has all registry roles and registrar ownership");
        console.log("Registrar has REGISTRAR_ROLE on registry");
        console.log("");
        console.log("To open minting, call registrar.openMinting()");

        return (factory, registry, registrar);
    }
}

/**
 * @title DeployRegistryOnly
 * @dev Deployment script that deploys factory and creates a registry only (no registrar)
 * 
 * Usage:
 *   forge script script/DeployAgentRegistry.s.sol:DeployRegistryOnly --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 */
contract DeployRegistryOnly is Script {
    function run() external returns (AgentRegistryFactory factory, address registry) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying AgentRegistryFactory with Registry...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy factory
        factory = new AgentRegistryFactory();

        // Deploy registry only
        registry = factory.deploy(deployer);

        // Set initial contract metadata
        AgentRegistry(registry).setContractMetadata("name", bytes("Agent Registry"));
        AgentRegistry(registry).setContractMetadata("description", bytes("A minimal onchain registry for discovering AI agents"));

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("AgentRegistryFactory:", address(factory));
        console.log("Registry:", registry);
        console.log("");
        console.log("Admin has DEFAULT_ADMIN_ROLE, REGISTRAR_ROLE, and METADATA_ADMIN_ROLE");

        return (factory, registry);
    }
}

/**
 * @title DeployFromExistingFactory
 * @dev Deploy a new registry + registrar from an existing factory
 * 
 * Usage:
 *   FACTORY_ADDRESS=0x... MINT_PRICE=10000000000000000 MAX_SUPPLY=1000 forge script script/DeployAgentRegistry.s.sol:DeployFromExistingFactory --rpc-url $SEPOLIA_RPC_URL --broadcast
 */
contract DeployFromExistingFactory is Script {
    function run() external returns (address registry, address registrar) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        uint256 mintPrice = vm.envOr("MINT_PRICE", uint256(0.01 ether));
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", uint256(0));

        AgentRegistryFactory factory = AgentRegistryFactory(factoryAddress);

        console.log("Deploying from existing factory...");
        console.log("Factory address:", factoryAddress);
        console.log("Deployer address:", deployer);
        console.log("Mint price:", mintPrice);
        console.log("Max supply:", maxSupply == 0 ? "Unlimited" : vm.toString(maxSupply));

        vm.startBroadcast(deployerPrivateKey);

        // Deploy registry + registrar
        (registry, registrar) = factory.deploy(deployer, mintPrice, maxSupply);

        // Set initial contract metadata
        AgentRegistry(registry).setContractMetadata("name", bytes("Agent Registry"));
        AgentRegistry(registry).setContractMetadata("description", bytes("A minimal onchain registry for discovering AI agents"));

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("Registry:", registry);
        console.log("Registrar:", registrar);
        console.log("Total registries from factory:", factory.getDeployedRegistriesCount());
        console.log("Total registrars from factory:", factory.getDeployedRegistrarsCount());

        return (registry, registrar);
    }
}

/**
 * @title DeployRegistrarOnly
 * @dev Deploy a registrar for an existing registry
 * 
 * Usage:
 *   FACTORY_ADDRESS=0x... REGISTRY_ADDRESS=0x... MINT_PRICE=10000000000000000 MAX_SUPPLY=1000 forge script script/DeployAgentRegistry.s.sol:DeployRegistrarOnly --rpc-url $SEPOLIA_RPC_URL --broadcast
 */
contract DeployRegistrarOnly is Script {
    function run() external returns (address registrar) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        address registryAddress = vm.envAddress("REGISTRY_ADDRESS");
        uint256 mintPrice = vm.envOr("MINT_PRICE", uint256(0.01 ether));
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", uint256(0));

        AgentRegistryFactory factory = AgentRegistryFactory(factoryAddress);

        console.log("Deploying registrar for existing registry...");
        console.log("Factory address:", factoryAddress);
        console.log("Registry address:", registryAddress);
        console.log("Deployer address:", deployer);
        console.log("Mint price:", mintPrice);
        console.log("Max supply:", maxSupply == 0 ? "Unlimited" : vm.toString(maxSupply));

        vm.startBroadcast(deployerPrivateKey);

        // Deploy registrar
        registrar = factory.deployRegistrar(
            AgentRegistry(registryAddress),
            mintPrice,
            maxSupply,
            deployer
        );

        // Note: Admin must manually grant REGISTRAR_ROLE to the registrar
        console.log("");
        console.log("IMPORTANT: Grant REGISTRAR_ROLE to registrar:");
        console.log("  registry.grantRole(registry.REGISTRAR_ROLE(), registrar)");

        vm.stopBroadcast();

        console.log("");
        console.log("Registrar deployed at:", registrar);

        return registrar;
    }
}