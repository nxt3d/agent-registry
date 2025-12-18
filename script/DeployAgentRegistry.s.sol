// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/AgentRegistry.sol";

/**
 * @title DeployAgentRegistry
 * @dev Deployment script for AgentRegistry contract
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

        console.log("Deploying AgentRegistry...");
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

        console.log("Deploying AgentRegistry...");
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

