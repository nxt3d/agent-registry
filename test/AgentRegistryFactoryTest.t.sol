// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/AgentRegistry.sol";
import "../src/AgentRegistryFactory.sol";
import "../src/AgentRegistrar.sol";
import "../src/interfaces/IAgentRegistry.sol";
import {IERC8048} from "../src/interfaces/IERC8048.sol";
import {IERC8049} from "../src/interfaces/IERC8049.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title AgentRegistryFactoryTest
 * @dev Comprehensive tests for the AgentRegistryFactory contract
 * 
 * This test verifies:
 * - Factory deployment and implementation creation
 * - Clone deployment (standard and deterministic)
 * - Address prediction for deterministic clones
 * - Clone initialization and functionality
 * - Multiple registry deployment tracking
 * - Full registry functionality through clones
 * - Combined registry + registrar deployment
 */
contract AgentRegistryFactoryTest is Test {
    
    /* --- State Variables --- */
    
    AgentRegistryFactory public factory;
    
    /* --- Test Addresses --- */
    
    address constant ADMIN1 = address(0x1111111111111111111111111111111111111111);
    address constant ADMIN2 = address(0x2222222222222222222222222222222222222222);
    address constant OWNER1 = address(0x3333333333333333333333333333333333333333);
    address constant OWNER2 = address(0x4444444444444444444444444444444444444444);
    address constant AGENT_ACCOUNT1 = address(0x5555555555555555555555555555555555555555);
    address constant RANDOM_USER = address(0x6666666666666666666666666666666666666666);
    
    /* --- Events --- */
    
    event RegistryDeployed(address indexed registry, address indexed admin, bytes32 salt);
    event RegistrarDeployed(address indexed registrar, address indexed registry, address indexed owner);
    event RegistryAndRegistrarDeployed(address indexed registry, address indexed registrar, address indexed admin);
    
    /* --- Setup --- */
    
    function setUp() public {
        factory = new AgentRegistryFactory();
    }
    
    /* ============================================================== */
    /*                      FACTORY DEPLOYMENT                        */
    /* ============================================================== */
    
    function test_001____factoryDeployment____ImplementationIsDeployed() public view {
        address impl = factory.registryImplementation();
        assertNotEq(impl, address(0), "Registry implementation should be deployed");
        assertTrue(impl.code.length > 0, "Registry implementation should have code");
        
        address registrarImpl = factory.registrarImplementation();
        assertNotEq(registrarImpl, address(0), "Registrar implementation should be deployed");
        assertTrue(registrarImpl.code.length > 0, "Registrar implementation should have code");
    }
    
    function test_002____factoryDeployment____ImplementationIsAgentRegistry() public view {
        address impl = factory.registryImplementation();
        
        // Verify it supports the expected interfaces
        assertTrue(
            AgentRegistry(impl).supportsInterface(0x0f632fb3), // ERC-6909
            "Implementation should support ERC-6909"
        );
        assertTrue(
            AgentRegistry(impl).supportsInterface(type(IERC8048).interfaceId),
            "Implementation should support IERC8048"
        );
        assertTrue(
            AgentRegistry(impl).supportsInterface(type(IERC8049).interfaceId),
            "Implementation should support IERC8049"
        );
    }
    
    function test_003____factoryDeployment____InitialDeployedCountIsZero() public view {
        assertEq(factory.getDeployedRegistriesCount(), 0, "Should have no deployed registries initially");
        assertEq(factory.getDeployedRegistrarsCount(), 0, "Should have no deployed registrars initially");
    }
    
    /* ============================================================== */
    /*                      STANDARD CLONE DEPLOYMENT                 */
    /* ============================================================== */
    
    function test_010____deploy____DeploysNewClone() public {
        address registry = factory.deploy(ADMIN1);
        
        assertNotEq(registry, address(0), "Registry should be deployed");
        assertTrue(registry.code.length > 0, "Registry should have code");
    }
    
    function test_011____deploy____InitializesWithAdmin() public {
        address registry = factory.deploy(ADMIN1);
        AgentRegistry reg = AgentRegistry(registry);
        
        assertTrue(
            reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), ADMIN1),
            "Admin should have DEFAULT_ADMIN_ROLE"
        );
        assertTrue(
            reg.hasRole(reg.REGISTRAR_ROLE(), ADMIN1),
            "Admin should have REGISTRAR_ROLE"
        );
        assertTrue(
            reg.hasRole(reg.METADATA_ADMIN_ROLE(), ADMIN1),
            "Admin should have METADATA_ADMIN_ROLE"
        );
    }
    
    function test_012____deploy____TracksDeployedRegistry() public {
        address registry = factory.deploy(ADMIN1);
        
        assertEq(factory.getDeployedRegistriesCount(), 1, "Should have 1 deployed registry");
        assertEq(factory.deployedRegistries(0), registry, "Registry should be tracked");
        assertTrue(factory.isDeployedRegistry(registry), "Should be marked as deployed");
    }
    
    function test_013____deploy____EmitsRegistryDeployedEvent() public {
        // Record logs to verify the event
        vm.recordLogs();
        
        address registry = factory.deploy(ADMIN1);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        
        // Find the RegistryDeployed event
        bool eventFound = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("RegistryDeployed(address,address,bytes32)")) {
                assertEq(address(uint160(uint256(entries[i].topics[1]))), registry, "Registry address mismatch");
                assertEq(address(uint160(uint256(entries[i].topics[2]))), ADMIN1, "Admin address mismatch");
                eventFound = true;
                break;
            }
        }
        assertTrue(eventFound, "RegistryDeployed event should be emitted");
    }
    
    function test_014____deploy____MultipleDeploymentsTracked() public {
        address registry1 = factory.deploy(ADMIN1);
        address registry2 = factory.deploy(ADMIN2);
        address registry3 = factory.deploy(ADMIN1);
        
        assertEq(factory.getDeployedRegistriesCount(), 3, "Should have 3 deployed registries");
        assertEq(factory.deployedRegistries(0), registry1, "First registry tracked");
        assertEq(factory.deployedRegistries(1), registry2, "Second registry tracked");
        assertEq(factory.deployedRegistries(2), registry3, "Third registry tracked");
        
        assertNotEq(registry1, registry2, "Registries should have different addresses");
        assertNotEq(registry2, registry3, "Registries should have different addresses");
    }
    
    /* ============================================================== */
    /*                  DETERMINISTIC CLONE DEPLOYMENT                */
    /* ============================================================== */
    
    function test_020____deployDeterministic____DeploysWithSalt() public {
        bytes32 salt = keccak256("test-salt");
        address registry = factory.deployRegistryDeterministic(ADMIN1, salt);
        
        assertNotEq(registry, address(0), "Registry should be deployed");
        assertTrue(registry.code.length > 0, "Registry should have code");
    }
    
    function test_021____deployDeterministic____AddressMatchesPrediction() public {
        bytes32 salt = keccak256("deterministic-test");
        
        address predicted = factory.predictRegistryAddress(salt);
        address deployed = factory.deployRegistryDeterministic(ADMIN1, salt);
        
        assertEq(deployed, predicted, "Deployed address should match prediction");
    }
    
    function test_022____deployDeterministic____SameSaltSameAddress() public {
        bytes32 salt = keccak256("same-salt");
        
        // Predict address before deployment
        address predicted = factory.predictRegistryAddress(salt);
        
        // Deploy with the salt
        address deployed = factory.deployRegistryDeterministic(ADMIN1, salt);
        
        assertEq(deployed, predicted, "Address should be deterministic");
    }
    
    function test_023____deployDeterministic____DifferentSaltsDifferentAddresses() public view {
        bytes32 salt1 = keccak256("salt-one");
        bytes32 salt2 = keccak256("salt-two");
        
        address predicted1 = factory.predictRegistryAddress(salt1);
        address predicted2 = factory.predictRegistryAddress(salt2);
        
        assertNotEq(predicted1, predicted2, "Different salts should predict different addresses");
    }
    
    function test_024____deployDeterministic____RevertsOnDuplicateSalt() public {
        bytes32 salt = keccak256("duplicate-salt");
        
        factory.deployRegistryDeterministic(ADMIN1, salt);
        
        vm.expectRevert(); // Should revert when deploying with same salt
        factory.deployRegistryDeterministic(ADMIN2, salt);
    }
    
    function test_025____deployDeterministic____TracksRegistry() public {
        bytes32 salt = keccak256("tracked-salt");
        address registry = factory.deployRegistryDeterministic(ADMIN1, salt);
        
        assertEq(factory.getDeployedRegistriesCount(), 1, "Should have 1 deployed registry");
        assertTrue(factory.isDeployedRegistry(registry), "Should be marked as deployed");
    }
    
    /* ============================================================== */
    /*                      ADDRESS PREDICTION                        */
    /* ============================================================== */
    
    function test_030____predictAddress____ReturnsValidAddress() public view {
        bytes32 salt = keccak256("prediction-test");
        address predicted = factory.predictRegistryAddress(salt);
        
        assertNotEq(predicted, address(0), "Predicted address should not be zero");
    }
    
    function test_031____predictAddress____ConsistentPredictions() public view {
        bytes32 salt = keccak256("consistent-salt");
        
        address predicted1 = factory.predictRegistryAddress(salt);
        address predicted2 = factory.predictRegistryAddress(salt);
        
        assertEq(predicted1, predicted2, "Same salt should give same prediction");
    }
    
    /* ============================================================== */
    /*                    REGISTRY ENUMERATION                        */
    /* ============================================================== */
    
    function test_040____getDeployedRegistries____ReturnsCorrectRange() public {
        factory.deploy(ADMIN1);
        address registry2 = factory.deploy(ADMIN2);
        address registry3 = factory.deploy(ADMIN1);
        factory.deploy(ADMIN2);
        
        address[] memory range = factory.getDeployedRegistries(1, 3);
        
        assertEq(range.length, 2, "Should return 2 registries");
        assertEq(range[0], registry2, "First in range should be registry2");
        assertEq(range[1], registry3, "Second in range should be registry3");
    }
    
    function test_041____getDeployedRegistries____RevertsOnInvalidRange() public {
        factory.deploy(ADMIN1);
        factory.deploy(ADMIN2);
        
        vm.expectRevert("Invalid range");
        factory.getDeployedRegistries(2, 1);
    }
    
    function test_042____getDeployedRegistries____RevertsOnOutOfBounds() public {
        factory.deploy(ADMIN1);
        
        vm.expectRevert("End out of bounds");
        factory.getDeployedRegistries(0, 5);
    }
    
    /* ============================================================== */
    /*                CLONE FUNCTIONALITY VERIFICATION                */
    /* ============================================================== */
    
    function test_050____cloneFunctionality____SupportsAllInterfaces() public {
        address registry = factory.deploy(ADMIN1);
        AgentRegistry reg = AgentRegistry(registry);
        
        assertTrue(reg.supportsInterface(0x0f632fb3), "Should support ERC-6909");
        assertTrue(reg.supportsInterface(type(IERC8048).interfaceId), "Should support IERC8048");
        assertTrue(reg.supportsInterface(type(IERC8049).interfaceId), "Should support IERC8049");
        assertTrue(reg.supportsInterface(type(IAccessControl).interfaceId), "Should support IAccessControl");
    }
    
    function test_051____cloneFunctionality____CanRegisterAgents() public {
        address registry = factory.deploy(ADMIN1);
        AgentRegistry reg = AgentRegistry(registry);
        
        vm.prank(ADMIN1);
        uint256 agentId = reg.register(OWNER1, "mcp", "https://example.com/agent", AGENT_ACCOUNT1);
        
        assertEq(agentId, 0, "First agent ID should be 0");
        assertEq(reg.ownerOf(0), OWNER1, "Owner should be set");
        assertEq(reg.balanceOf(OWNER1, 0), 1, "Balance should be 1");
    }
    
    function test_052____cloneFunctionality____CanSetMetadata() public {
        address registry = factory.deploy(ADMIN1);
        AgentRegistry reg = AgentRegistry(registry);
        
        // Register an agent
        vm.prank(ADMIN1);
        reg.register(OWNER1, "mcp", "https://example.com", AGENT_ACCOUNT1);
        
        // Set metadata as owner
        vm.prank(OWNER1);
        reg.setMetadata(0, "custom_key", bytes("custom_value"));
        
        bytes memory value = reg.getMetadata(0, "custom_key");
        assertEq(string(value), "custom_value", "Metadata should be set");
    }
    
    function test_053____cloneFunctionality____CanSetContractMetadata() public {
        address registry = factory.deploy(ADMIN1);
        AgentRegistry reg = AgentRegistry(registry);
        
        vm.prank(ADMIN1);
        reg.setContractMetadata("registry_name", bytes("Test Registry"));
        
        bytes memory value = reg.getContractMetadata("registry_name");
        assertEq(string(value), "Test Registry", "Contract metadata should be set");
    }
    
    function test_054____cloneFunctionality____CanTransferAgents() public {
        address registry = factory.deploy(ADMIN1);
        AgentRegistry reg = AgentRegistry(registry);
        
        // Register an agent
        vm.prank(ADMIN1);
        reg.register(OWNER1, "mcp", "https://example.com", AGENT_ACCOUNT1);
        
        // Transfer the agent
        vm.prank(OWNER1);
        reg.transfer(OWNER2, 0, 1);
        
        assertEq(reg.ownerOf(0), OWNER2, "Owner should be transferred");
        assertEq(reg.balanceOf(OWNER1, 0), 0, "Original owner balance should be 0");
        assertEq(reg.balanceOf(OWNER2, 0), 1, "New owner balance should be 1");
    }
    
    function test_055____cloneFunctionality____AccessControlWorks() public {
        address registry = factory.deploy(ADMIN1);
        AgentRegistry reg = AgentRegistry(registry);
        
        // Non-registrar cannot register
        vm.startPrank(RANDOM_USER);
        vm.expectRevert();
        reg.register(OWNER1, "mcp", "https://example.com", AGENT_ACCOUNT1);
        vm.stopPrank();
        
        // Admin can grant role
        vm.startPrank(ADMIN1);
        reg.grantRole(reg.REGISTRAR_ROLE(), RANDOM_USER);
        vm.stopPrank();
        
        // Now they can register
        vm.startPrank(RANDOM_USER);
        uint256 agentId = reg.register(OWNER1, "mcp", "https://example.com", AGENT_ACCOUNT1);
        vm.stopPrank();
        
        assertEq(agentId, 0, "Should be able to register after role grant");
    }
    
    /* ============================================================== */
    /*                    CLONE ISOLATION                             */
    /* ============================================================== */
    
    function test_060____cloneIsolation____SeparateAgentIndexes() public {
        address registry1 = factory.deploy(ADMIN1);
        address registry2 = factory.deploy(ADMIN2);
        
        AgentRegistry reg1 = AgentRegistry(registry1);
        AgentRegistry reg2 = AgentRegistry(registry2);
        
        // Register agents in both registries
        vm.prank(ADMIN1);
        uint256 id1 = reg1.register(OWNER1, "mcp", "https://example1.com", AGENT_ACCOUNT1);
        
        vm.prank(ADMIN2);
        uint256 id2 = reg2.register(OWNER2, "mcp", "https://example2.com", address(0));
        
        // Both should start from 0
        assertEq(id1, 0, "Registry 1 first ID should be 0");
        assertEq(id2, 0, "Registry 2 first ID should be 0");
        
        // And increment independently
        assertEq(reg1.agentIndex(), 1, "Registry 1 index should be 1");
        assertEq(reg2.agentIndex(), 1, "Registry 2 index should be 1");
    }
    
    function test_061____cloneIsolation____SeparateRoles() public {
        address registry1 = factory.deploy(ADMIN1);
        address registry2 = factory.deploy(ADMIN2);
        
        AgentRegistry reg1 = AgentRegistry(registry1);
        AgentRegistry reg2 = AgentRegistry(registry2);
        
        // ADMIN1 should not have roles in registry2
        assertFalse(
            reg2.hasRole(reg2.DEFAULT_ADMIN_ROLE(), ADMIN1),
            "ADMIN1 should not be admin in registry2"
        );
        
        // ADMIN2 should not have roles in registry1
        assertFalse(
            reg1.hasRole(reg1.DEFAULT_ADMIN_ROLE(), ADMIN2),
            "ADMIN2 should not be admin in registry1"
        );
    }
    
    function test_062____cloneIsolation____SeparateMetadata() public {
        address registry1 = factory.deploy(ADMIN1);
        address registry2 = factory.deploy(ADMIN2);
        
        AgentRegistry reg1 = AgentRegistry(registry1);
        AgentRegistry reg2 = AgentRegistry(registry2);
        
        // Set contract metadata in registry1
        vm.prank(ADMIN1);
        reg1.setContractMetadata("name", bytes("Registry One"));
        
        // Set different metadata in registry2
        vm.prank(ADMIN2);
        reg2.setContractMetadata("name", bytes("Registry Two"));
        
        // Verify isolation
        assertEq(string(reg1.getContractMetadata("name")), "Registry One", "Registry 1 metadata");
        assertEq(string(reg2.getContractMetadata("name")), "Registry Two", "Registry 2 metadata");
    }
    
    /* ============================================================== */
    /*                    INITIALIZATION SECURITY                     */
    /* ============================================================== */
    
    function test_070____initSecurity____CannotReinitializeClone() public {
        address registry = factory.deploy(ADMIN1);
        AgentRegistry reg = AgentRegistry(registry);
        
        vm.expectRevert();
        reg.initialize(ADMIN2);
    }
    
    function test_071____initSecurity____CannotInitializeImplementation() public {
        address impl = factory.registryImplementation();
        AgentRegistry implContract = AgentRegistry(impl);
        
        vm.expectRevert();
        implContract.initialize(ADMIN1);
    }
    
    /* ============================================================== */
    /*                  COMBINED DEPLOYMENT (REGISTRY + REGISTRAR)    */
    /* ============================================================== */
    
    function test_080____combinedDeploy____DeploysBothContracts() public {
        (address registry, address registrar) = factory.deploy(ADMIN1, 0.01 ether, 1000);
        
        assertNotEq(registry, address(0), "Registry should be deployed");
        assertNotEq(registrar, address(0), "Registrar should be deployed");
        assertTrue(registry.code.length > 0, "Registry should have code");
        assertTrue(registrar.code.length > 0, "Registrar should have code");
    }
    
    function test_081____combinedDeploy____RegistrarLinkedToRegistry() public {
        (address registry, address registrar) = factory.deploy(ADMIN1, 0.01 ether, 1000);
        
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        assertEq(address(reg.registry()), registry, "Registrar should point to registry");
    }
    
    function test_082____combinedDeploy____RegistrarHasCorrectConfig() public {
        uint256 mintPrice = 0.05 ether;
        uint256 maxSupply = 500;
        
        (, address registrar) = factory.deploy(ADMIN1, mintPrice, maxSupply);
        
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        assertEq(reg.mintPrice(), mintPrice, "Mint price should be set");
        assertEq(reg.maxSupply(), maxSupply, "Max supply should be set");
        assertEq(reg.owner(), ADMIN1, "Owner should be admin");
        assertFalse(reg.open(), "Minting should be closed initially");
    }
    
    function test_083____combinedDeploy____RegistrarHasRegistrarRole() public {
        (address registry, address registrar) = factory.deploy(ADMIN1, 0.01 ether, 1000);
        
        AgentRegistry reg = AgentRegistry(registry);
        assertTrue(
            reg.hasRole(reg.REGISTRAR_ROLE(), registrar),
            "Registrar should have REGISTRAR_ROLE"
        );
    }
    
    function test_084____combinedDeploy____TracksBothContracts() public {
        (address registry, address registrar) = factory.deploy(ADMIN1, 0.01 ether, 1000);
        
        assertEq(factory.getDeployedRegistriesCount(), 1, "Should have 1 registry");
        assertEq(factory.getDeployedRegistrarsCount(), 1, "Should have 1 registrar");
        assertTrue(factory.isDeployedRegistry(registry), "Registry should be tracked");
        assertTrue(factory.isDeployedRegistrar(registrar), "Registrar should be tracked");
        assertEq(factory.registryToRegistrar(registry), registrar, "Mapping should be set");
    }
    
    function test_085____combinedDeploy____CanMintThroughRegistrar() public {
        (address registry, address registrar) = factory.deploy(ADMIN1, 0.01 ether, 1000);
        
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        AgentRegistry agentReg = AgentRegistry(registry);
        
        // Open minting
        vm.prank(ADMIN1);
        reg.openMinting();
        
        // Mint an agent
        vm.deal(OWNER1, 1 ether);
        vm.prank(OWNER1);
        uint256 agentId = reg.mint{value: 0.01 ether}();
        
        assertEq(agentId, 0, "First agent ID should be 0");
        assertEq(agentReg.ownerOf(0), OWNER1, "Owner should be OWNER1");
        assertEq(reg.totalMinted(), 1, "Total minted should be 1");
    }
    
    function test_086____combinedDeploy____EmitsAllEvents() public {
        vm.recordLogs();
        
        (address registry, address registrar) = factory.deploy(ADMIN1, 0.01 ether, 1000);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        
        bool registryEventFound = false;
        bool registrarEventFound = false;
        bool combinedEventFound = false;
        
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("RegistryDeployed(address,address,bytes32)")) {
                registryEventFound = true;
            }
            if (entries[i].topics[0] == keccak256("RegistrarDeployed(address,address,address)")) {
                registrarEventFound = true;
            }
            if (entries[i].topics[0] == keccak256("RegistryAndRegistrarDeployed(address,address,address)")) {
                combinedEventFound = true;
            }
        }
        
        assertTrue(registryEventFound, "RegistryDeployed should be emitted");
        assertTrue(registrarEventFound, "RegistrarDeployed should be emitted");
        assertTrue(combinedEventFound, "RegistryAndRegistrarDeployed should be emitted");
        
        // Suppress unused variable warnings
        registry;
        registrar;
    }
    
    /* ============================================================== */
    /*                  REGISTRAR-ONLY DEPLOYMENT                     */
    /* ============================================================== */
    
    function test_090____deployRegistrar____DeploysForExistingRegistry() public {
        address registry = factory.deploy(ADMIN1);
        
        address registrar = factory.deployRegistrar(
            AgentRegistry(registry),
            0.01 ether,
            1000,
            ADMIN2
        );
        
        assertNotEq(registrar, address(0), "Registrar should be deployed");
        
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        assertEq(address(reg.registry()), registry, "Should point to registry");
        assertEq(reg.owner(), ADMIN2, "Owner should be ADMIN2");
    }
    
    function test_091____deployRegistrar____TracksRegistrar() public {
        address registry = factory.deploy(ADMIN1);
        
        address registrar = factory.deployRegistrar(
            AgentRegistry(registry),
            0.01 ether,
            1000,
            ADMIN1
        );
        
        assertEq(factory.getDeployedRegistrarsCount(), 1, "Should have 1 registrar");
        assertTrue(factory.isDeployedRegistrar(registrar), "Should be tracked");
    }
    
    /* ============================================================== */
    /*              REGISTRY DEPLOYMENT WITH NAME                     */
    /* ============================================================== */
    
    function test_100____deployRegistryWithName____SetsNameMetadata() public {
        string memory name = "My Test Registry";
        address registry = factory.deployRegistry(ADMIN1, name);
        
        AgentRegistry reg = AgentRegistry(registry);
        bytes memory nameBytes = reg.getContractMetadata("name");
        assertEq(string(nameBytes), name, "Name should be set correctly");
    }
    
    function test_101____deployRegistryWithName____InitializesWithAdmin() public {
        address registry = factory.deployRegistry(ADMIN1, "Test Registry");
        AgentRegistry reg = AgentRegistry(registry);
        
        assertTrue(
            reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), ADMIN1),
            "Admin should have DEFAULT_ADMIN_ROLE"
        );
        assertTrue(
            reg.hasRole(reg.REGISTRAR_ROLE(), ADMIN1),
            "Admin should have REGISTRAR_ROLE"
        );
        assertTrue(
            reg.hasRole(reg.METADATA_ADMIN_ROLE(), ADMIN1),
            "Admin should have METADATA_ADMIN_ROLE"
        );
    }
    
    function test_102____deployRegistryWithName____FactoryRolesRenounced() public {
        address registry = factory.deployRegistry(ADMIN1, "Test Registry");
        AgentRegistry reg = AgentRegistry(registry);
        
        assertFalse(
            reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), address(factory)),
            "Factory should not have DEFAULT_ADMIN_ROLE"
        );
        assertFalse(
            reg.hasRole(reg.REGISTRAR_ROLE(), address(factory)),
            "Factory should not have REGISTRAR_ROLE"
        );
        assertFalse(
            reg.hasRole(reg.METADATA_ADMIN_ROLE(), address(factory)),
            "Factory should not have METADATA_ADMIN_ROLE"
        );
    }
    
    function test_103____deployRegistryWithName____TracksDeployedRegistry() public {
        address registry = factory.deployRegistry(ADMIN1, "Test Registry");
        
        assertEq(factory.getDeployedRegistriesCount(), 1, "Should have 1 deployed registry");
        assertEq(factory.deployedRegistries(0), registry, "Registry should be tracked");
        assertTrue(factory.isDeployedRegistry(registry), "Should be marked as deployed");
    }
    
    function test_104____deployRegistryWithName____CanSetOtherMetadata() public {
        address registry = factory.deployRegistry(ADMIN1, "Test Registry");
        AgentRegistry reg = AgentRegistry(registry);
        
        // Admin should be able to set other metadata
        vm.prank(ADMIN1);
        reg.setContractMetadata("description", bytes("A test registry"));
        
        bytes memory desc = reg.getContractMetadata("description");
        assertEq(string(desc), "A test registry", "Should be able to set other metadata");
    }
    
    function test_105____deployRegistryWithName____CanRegisterAgents() public {
        address registry = factory.deployRegistry(ADMIN1, "Test Registry");
        AgentRegistry reg = AgentRegistry(registry);
        
        vm.prank(ADMIN1);
        uint256 agentId = reg.register(OWNER1, "mcp", "https://example.com/agent", AGENT_ACCOUNT1);
        
        assertEq(agentId, 0, "First agent ID should be 0");
        assertEq(reg.ownerOf(0), OWNER1, "Owner should be set");
    }
    
    /* ============================================================== */
    /*         DETERMINISTIC REGISTRY DEPLOYMENT WITH NAME            */
    /* ============================================================== */
    
    function test_110____deployRegistryDeterministicWithName____SetsNameMetadata() public {
        bytes32 salt = keccak256("test-salt");
        string memory name = "Deterministic Registry";
        address registry = factory.deployRegistryDeterministic(ADMIN1, salt, name);
        
        AgentRegistry reg = AgentRegistry(registry);
        bytes memory nameBytes = reg.getContractMetadata("name");
        assertEq(string(nameBytes), name, "Name should be set correctly");
    }
    
    function test_111____deployRegistryDeterministicWithName____AddressMatchesPrediction() public {
        bytes32 salt = keccak256("deterministic-name-test");
        
        address predicted = factory.predictRegistryAddress(salt);
        address deployed = factory.deployRegistryDeterministic(ADMIN1, salt, "Test Name");
        
        assertEq(deployed, predicted, "Deployed address should match prediction");
    }
    
    function test_112____deployRegistryDeterministicWithName____InitializesWithAdmin() public {
        bytes32 salt = keccak256("admin-test");
        address registry = factory.deployRegistryDeterministic(ADMIN1, salt, "Test");
        AgentRegistry reg = AgentRegistry(registry);
        
        assertTrue(
            reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), ADMIN1),
            "Admin should have DEFAULT_ADMIN_ROLE"
        );
    }
    
    function test_113____deployRegistryDeterministicWithName____FactoryRolesRenounced() public {
        bytes32 salt = keccak256("renounce-test");
        address registry = factory.deployRegistryDeterministic(ADMIN1, salt, "Test");
        AgentRegistry reg = AgentRegistry(registry);
        
        assertFalse(
            reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), address(factory)),
            "Factory should not have DEFAULT_ADMIN_ROLE"
        );
    }
    
    /* ============================================================== */
    /*         COMBINED DEPLOYMENT WITH NAME (REGISTRY + REGISTRAR)   */
    /* ============================================================== */
    
    function test_120____combinedDeployWithName____SetsNameMetadata() public {
        string memory name = "Combined Registry";
        (address registry, address registrar) = factory.deploy(ADMIN1, 0.01 ether, 1000, name);
        
        AgentRegistry reg = AgentRegistry(registry);
        bytes memory nameBytes = reg.getContractMetadata("name");
        assertEq(string(nameBytes), name, "Name should be set correctly");
        
        assertNotEq(registrar, address(0), "Registrar should be deployed");
    }
    
    function test_121____combinedDeployWithName____DeploysBothContracts() public {
        (address registry, address registrar) = factory.deploy(ADMIN1, 0.01 ether, 1000, "Test Registry");
        
        assertNotEq(registry, address(0), "Registry should be deployed");
        assertNotEq(registrar, address(0), "Registrar should be deployed");
        assertTrue(registry.code.length > 0, "Registry should have code");
        assertTrue(registrar.code.length > 0, "Registrar should have code");
    }
    
    function test_122____combinedDeployWithName____RegistrarLinkedToRegistry() public {
        (address registry, address registrar) = factory.deploy(ADMIN1, 0.01 ether, 1000, "Test");
        
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        assertEq(address(reg.registry()), registry, "Registrar should point to registry");
    }
    
    function test_123____combinedDeployWithName____RegistrarHasCorrectConfig() public {
        uint256 mintPrice = 0.05 ether;
        uint256 maxSupply = 500;
        
        (, address registrar) = factory.deploy(ADMIN1, mintPrice, maxSupply, "Test Registry");
        
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        assertEq(reg.mintPrice(), mintPrice, "Mint price should be set");
        assertEq(reg.maxSupply(), maxSupply, "Max supply should be set");
        assertEq(reg.owner(), ADMIN1, "Owner should be admin");
    }
    
    function test_124____combinedDeployWithName____AdminHasAllRoles() public {
        (address registry, ) = factory.deploy(ADMIN1, 0.01 ether, 1000, "Test Registry");
        AgentRegistry reg = AgentRegistry(registry);
        
        assertTrue(
            reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), ADMIN1),
            "Admin should have DEFAULT_ADMIN_ROLE"
        );
        assertTrue(
            reg.hasRole(reg.REGISTRAR_ROLE(), ADMIN1),
            "Admin should have REGISTRAR_ROLE"
        );
        assertTrue(
            reg.hasRole(reg.METADATA_ADMIN_ROLE(), ADMIN1),
            "Admin should have METADATA_ADMIN_ROLE"
        );
    }
    
    function test_125____combinedDeployWithName____FactoryRolesRenounced() public {
        (address registry, ) = factory.deploy(ADMIN1, 0.01 ether, 1000, "Test Registry");
        AgentRegistry reg = AgentRegistry(registry);
        
        assertFalse(
            reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), address(factory)),
            "Factory should not have DEFAULT_ADMIN_ROLE"
        );
        assertFalse(
            reg.hasRole(reg.REGISTRAR_ROLE(), address(factory)),
            "Factory should not have REGISTRAR_ROLE"
        );
        assertFalse(
            reg.hasRole(reg.METADATA_ADMIN_ROLE(), address(factory)),
            "Factory should not have METADATA_ADMIN_ROLE"
        );
    }
    
    function test_126____combinedDeployWithName____CanMintThroughRegistrar() public {
        (address registry, address registrar) = factory.deploy(ADMIN1, 0.01 ether, 1000, "Test Registry");
        
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        AgentRegistry agentReg = AgentRegistry(registry);
        
        // Open minting
        vm.prank(ADMIN1);
        reg.openMinting();
        
        // Mint an agent
        vm.deal(OWNER1, 1 ether);
        vm.prank(OWNER1);
        uint256 agentId = reg.mint{value: 0.01 ether}();
        
        assertEq(agentId, 0, "First agent ID should be 0");
        assertEq(agentReg.ownerOf(0), OWNER1, "Owner should be OWNER1");
    }
    
    function test_127____combinedDeployWithName____TracksBothContracts() public {
        (address registry, address registrar) = factory.deploy(ADMIN1, 0.01 ether, 1000, "Test Registry");
        
        assertEq(factory.getDeployedRegistriesCount(), 1, "Should have 1 registry");
        assertEq(factory.getDeployedRegistrarsCount(), 1, "Should have 1 registrar");
        assertTrue(factory.isDeployedRegistry(registry), "Registry should be tracked");
        assertTrue(factory.isDeployedRegistrar(registrar), "Registrar should be tracked");
        assertEq(factory.registryToRegistrar(registry), registrar, "Mapping should be set");
    }
    
    /* ============================================================== */
    /*    DETERMINISTIC COMBINED DEPLOYMENT WITH NAME                 */
    /* ============================================================== */
    
    function test_130____deployDeterministicWithName____SetsNameMetadata() public {
        bytes32 registrySalt = keccak256("registry-salt");
        bytes32 registrarSalt = keccak256("registrar-salt");
        string memory name = "Deterministic Combined Registry";
        
        (address registry, ) = factory.deployDeterministic(
            ADMIN1,
            0.01 ether,
            1000,
            registrySalt,
            registrarSalt,
            name
        );
        
        AgentRegistry reg = AgentRegistry(registry);
        bytes memory nameBytes = reg.getContractMetadata("name");
        assertEq(string(nameBytes), name, "Name should be set correctly");
    }
    
    function test_131____deployDeterministicWithName____AddressMatchesPrediction() public {
        bytes32 registrySalt = keccak256("registry-prediction");
        bytes32 registrarSalt = keccak256("registrar-prediction");
        
        address predicted = factory.predictRegistryAddress(registrySalt);
        (address deployed, ) = factory.deployDeterministic(
            ADMIN1,
            0.01 ether,
            1000,
            registrySalt,
            registrarSalt,
            "Test Name"
        );
        
        assertEq(deployed, predicted, "Deployed address should match prediction");
    }
    
    function test_132____deployDeterministicWithName____DeploysBothContracts() public {
        bytes32 registrySalt = keccak256("both-contracts");
        bytes32 registrarSalt = keccak256("both-contracts-registrar");
        
        (address registry, address registrar) = factory.deployDeterministic(
            ADMIN1,
            0.01 ether,
            1000,
            registrySalt,
            registrarSalt,
            "Test Registry"
        );
        
        assertNotEq(registry, address(0), "Registry should be deployed");
        assertNotEq(registrar, address(0), "Registrar should be deployed");
    }
    
    function test_133____deployDeterministicWithName____RegistrarHasCorrectConfig() public {
        bytes32 registrySalt = keccak256("config-test");
        bytes32 registrarSalt = keccak256("config-test-registrar");
        uint256 mintPrice = 0.05 ether;
        uint256 maxSupply = 500;
        
        (, address registrar) = factory.deployDeterministic(
            ADMIN1,
            mintPrice,
            maxSupply,
            registrySalt,
            registrarSalt,
            "Test Registry"
        );
        
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        assertEq(reg.mintPrice(), mintPrice, "Mint price should be set");
        assertEq(reg.maxSupply(), maxSupply, "Max supply should be set");
    }
    
    function test_134____deployDeterministicWithName____AdminHasAllRoles() public {
        bytes32 registrySalt = keccak256("roles-test");
        bytes32 registrarSalt = keccak256("roles-test-registrar");
        
        (address registry, ) = factory.deployDeterministic(
            ADMIN1,
            0.01 ether,
            1000,
            registrySalt,
            registrarSalt,
            "Test Registry"
        );
        
        AgentRegistry reg = AgentRegistry(registry);
        assertTrue(
            reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), ADMIN1),
            "Admin should have DEFAULT_ADMIN_ROLE"
        );
        assertTrue(
            reg.hasRole(reg.REGISTRAR_ROLE(), ADMIN1),
            "Admin should have REGISTRAR_ROLE"
        );
        assertTrue(
            reg.hasRole(reg.METADATA_ADMIN_ROLE(), ADMIN1),
            "Admin should have METADATA_ADMIN_ROLE"
        );
    }
    
    function test_135____deployDeterministicWithName____FactoryRolesRenounced() public {
        bytes32 registrySalt = keccak256("renounce-deterministic");
        bytes32 registrarSalt = keccak256("renounce-deterministic-registrar");
        
        (address registry, ) = factory.deployDeterministic(
            ADMIN1,
            0.01 ether,
            1000,
            registrySalt,
            registrarSalt,
            "Test Registry"
        );
        
        AgentRegistry reg = AgentRegistry(registry);
        assertFalse(
            reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), address(factory)),
            "Factory should not have DEFAULT_ADMIN_ROLE"
        );
    }
    
    function test_136____deployDeterministicWithName____CanMintThroughRegistrar() public {
        bytes32 registrySalt = keccak256("mint-test");
        bytes32 registrarSalt = keccak256("mint-test-registrar");
        
        (address registry, address registrar) = factory.deployDeterministic(
            ADMIN1,
            0.01 ether,
            1000,
            registrySalt,
            registrarSalt,
            "Test Registry"
        );
        
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        AgentRegistry agentReg = AgentRegistry(registry);
        
        // Open minting
        vm.prank(ADMIN1);
        reg.openMinting();
        
        // Mint an agent
        vm.deal(OWNER1, 1 ether);
        vm.prank(OWNER1);
        uint256 agentId = reg.mint{value: 0.01 ether}();
        
        assertEq(agentId, 0, "First agent ID should be 0");
        assertEq(agentReg.ownerOf(0), OWNER1, "Owner should be OWNER1");
    }
    
    /* ============================================================== */
    /*                        FUZZ TESTS                              */
    /* ============================================================== */
    
    function testFuzz_deploy(address admin) public {
        vm.assume(admin != address(0));
        
        address registry = factory.deploy(admin);
        AgentRegistry reg = AgentRegistry(registry);
        
        assertTrue(reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), admin), "Admin should have role");
    }
    
    function testFuzz_deterministicAddress(bytes32 salt) public {
        address predicted = factory.predictRegistryAddress(salt);
        address deployed = factory.deployRegistryDeterministic(ADMIN1, salt);
        
        assertEq(deployed, predicted, "Deployed should match predicted");
    }
    
    function testFuzz_multipleDeployments(uint8 count) public {
        vm.assume(count > 0 && count <= 50); // Limit to avoid gas issues
        
        for (uint8 i = 0; i < count; i++) {
            factory.deploy(address(uint160(i + 1)));
        }
        
        assertEq(factory.getDeployedRegistriesCount(), count, "Count should match");
    }
    
    function testFuzz_combinedDeploy(uint256 mintPrice, uint256 maxSupply) public {
        vm.assume(mintPrice <= 100 ether);
        vm.assume(maxSupply <= 1_000_000);
        
        (address registry, address registrar) = factory.deploy(ADMIN1, mintPrice, maxSupply);
        
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        assertEq(reg.mintPrice(), mintPrice, "Mint price should match");
        assertEq(reg.maxSupply(), maxSupply, "Max supply should match");
        assertEq(address(reg.registry()), registry, "Registry should match");
    }
    
    function testFuzz_deployRegistryWithName(address admin, string memory name) public {
        vm.assume(admin != address(0));
        
        address registry = factory.deployRegistry(admin, name);
        AgentRegistry reg = AgentRegistry(registry);
        
        assertTrue(reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), admin), "Admin should have role");
        bytes memory nameBytes = reg.getContractMetadata("name");
        assertEq(string(nameBytes), name, "Name should be set correctly");
    }
    
    function testFuzz_deployRegistryDeterministicWithName(address admin, bytes32 salt, string memory name) public {
        vm.assume(admin != address(0));
        
        address predicted = factory.predictRegistryAddress(salt);
        address deployed = factory.deployRegistryDeterministic(admin, salt, name);
        
        assertEq(deployed, predicted, "Deployed should match predicted");
        AgentRegistry reg = AgentRegistry(deployed);
        bytes memory nameBytes = reg.getContractMetadata("name");
        assertEq(string(nameBytes), name, "Name should be set correctly");
    }
    
    function testFuzz_combinedDeployWithName(uint256 mintPrice, uint256 maxSupply, string memory name) public {
        vm.assume(mintPrice <= 100 ether);
        vm.assume(maxSupply <= 1_000_000);
        
        (address registry, address registrar) = factory.deploy(ADMIN1, mintPrice, maxSupply, name);
        
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        assertEq(reg.mintPrice(), mintPrice, "Mint price should match");
        assertEq(reg.maxSupply(), maxSupply, "Max supply should match");
        
        AgentRegistry agentReg = AgentRegistry(registry);
        bytes memory nameBytes = agentReg.getContractMetadata("name");
        assertEq(string(nameBytes), name, "Name should be set correctly");
    }
    
    function testFuzz_deployDeterministicWithName(
        address admin,
        uint256 mintPrice,
        uint256 maxSupply,
        bytes32 registrySalt,
        bytes32 registrarSalt,
        string memory name
    ) public {
        vm.assume(admin != address(0));
        vm.assume(mintPrice <= 100 ether);
        vm.assume(maxSupply <= 1_000_000);
        
        address predicted = factory.predictRegistryAddress(registrySalt);
        (address registry, address registrar) = factory.deployDeterministic(
            admin,
            mintPrice,
            maxSupply,
            registrySalt,
            registrarSalt,
            name
        );
        
        assertEq(registry, predicted, "Registry address should match prediction");
        AgentRegistrar reg = AgentRegistrar(payable(registrar));
        assertEq(reg.mintPrice(), mintPrice, "Mint price should match");
        assertEq(reg.maxSupply(), maxSupply, "Max supply should match");
        
        AgentRegistry agentReg = AgentRegistry(registry);
        bytes memory nameBytes = agentReg.getContractMetadata("name");
        assertEq(string(nameBytes), name, "Name should be set correctly");
    }
}
