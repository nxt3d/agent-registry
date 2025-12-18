// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/AgentRegistry.sol";
import "../src/interfaces/IAgentRegistry.sol";
import {IERC8048} from "../src/interfaces/IERC8048.sol";
import {IERC8049} from "../src/interfaces/IERC8049.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title AgentRegistryTest
 * @dev Comprehensive tests for the AgentRegistry contract
 * 
 * This test verifies:
 * - ERC-6909 functionality with single ownership
 * - Registration and metadata
 * - Access control
 * - ERC-6909-style token authorization
 */
contract AgentRegistryTest is Test {
    
    /* --- State Variables --- */
    
    AgentRegistry public registry;
    
    /* --- Test Addresses --- */
    
    address constant ADMIN = address(0x1111111111111111111111111111111111111111);
    address constant REGISTRAR = address(0x2222222222222222222222222222222222222222);
    address constant METADATA_ADMIN = address(0x3333333333333333333333333333333333333333);
    address constant OWNER1 = address(0x4444444444444444444444444444444444444444);
    address constant OWNER2 = address(0x5555555555555555555555555555555555555555);
    address constant OPERATOR1 = address(0x6666666666666666666666666666666666666666);
    address constant AGENT_ACCOUNT1 = address(0x7777777777777777777777777777777777777777);
    address constant RANDOM_USER = address(0x8888888888888888888888888888888888888888);
    
    /* --- Setup --- */
    
    function setUp() public {
        // Deploy registry - this contract becomes the admin
        registry = new AgentRegistry();
        
        // Grant roles to test addresses
        registry.grantRole(registry.DEFAULT_ADMIN_ROLE(), ADMIN);
        registry.grantRole(registry.REGISTRAR_ROLE(), REGISTRAR);
        registry.grantRole(registry.METADATA_ADMIN_ROLE(), METADATA_ADMIN);
    }
    
    /* --- Helper Functions --- */
    
    function _createMetadataEntry(string memory key, bytes memory value) internal pure returns (IAgentRegistry.MetadataEntry memory) {
        return IAgentRegistry.MetadataEntry({key: key, value: value});
    }
    
    function _registerBasicAgent() internal returns (uint256) {
        vm.prank(REGISTRAR);
        return registry.register(OWNER1, "mcp", "https://agent.example.com", AGENT_ACCOUNT1);
    }
    
    /* --- Registration Tests --- */
    
    function test_001____registration____BasicRegistrationWorks() public {
        vm.prank(REGISTRAR);
        uint256 agentId = registry.register(OWNER1, "mcp", "https://agent.example.com", AGENT_ACCOUNT1);
        
        assertEq(agentId, 0);
        assertEq(registry.ownerOf(agentId), OWNER1);
        assertEq(registry.balanceOf(OWNER1, agentId), 1);
        assertEq(registry.agentIndex(), 1);
    }
    
    function test_002____registration____MetadataIsSetCorrectly() public {
        vm.prank(REGISTRAR);
        uint256 agentId = registry.register(OWNER1, "mcp", "https://agent.example.com", AGENT_ACCOUNT1);
        
        assertEq(string(registry.getMetadata(agentId, "endpoint_type")), "mcp");
        assertEq(string(registry.getMetadata(agentId, "endpoint")), "https://agent.example.com");
        assertEq(abi.decode(registry.getMetadata(agentId, "agent_account"), (address)), AGENT_ACCOUNT1);
    }
    
    function test_003____registration____EmptyFieldsAreNotSet() public {
        vm.prank(REGISTRAR);
        uint256 agentId = registry.register(OWNER1, "", "", address(0));
        
        assertEq(registry.getMetadata(agentId, "endpoint_type").length, 0);
        assertEq(registry.getMetadata(agentId, "endpoint").length, 0);
        assertEq(registry.getMetadata(agentId, "agent_account").length, 0);
    }
    
    function test_004____registration____MetadataArrayRegistrationWorks() public {
        IAgentRegistry.MetadataEntry[] memory metadata = new IAgentRegistry.MetadataEntry[](3);
        metadata[0] = _createMetadataEntry("name", bytes("My Agent"));
        metadata[1] = _createMetadataEntry("endpoint_type", bytes("a2a"));
        metadata[2] = _createMetadataEntry("endpoint", bytes("https://a2a.example.com"));
        
        vm.prank(REGISTRAR);
        uint256 agentId = registry.register(OWNER1, metadata);
        
        assertEq(agentId, 0);
        assertEq(registry.ownerOf(agentId), OWNER1);
        assertEq(string(registry.getMetadata(agentId, "name")), "My Agent");
        assertEq(string(registry.getMetadata(agentId, "endpoint_type")), "a2a");
    }
    
    function test_005____registration____BatchRegistrationWorks() public {
        address[] memory owners = new address[](3);
        owners[0] = OWNER1;
        owners[1] = OWNER2;
        owners[2] = OWNER1;
        
        IAgentRegistry.MetadataEntry[][] memory metadata = new IAgentRegistry.MetadataEntry[][](3);
        
        metadata[0] = new IAgentRegistry.MetadataEntry[](1);
        metadata[0][0] = _createMetadataEntry("name", bytes("Agent 1"));
        
        metadata[1] = new IAgentRegistry.MetadataEntry[](1);
        metadata[1][0] = _createMetadataEntry("name", bytes("Agent 2"));
        
        metadata[2] = new IAgentRegistry.MetadataEntry[](1);
        metadata[2][0] = _createMetadataEntry("name", bytes("Agent 3"));
        
        vm.prank(REGISTRAR);
        uint256[] memory agentIds = registry.registerBatch(owners, metadata);
        
        assertEq(agentIds.length, 3);
        assertEq(agentIds[0], 0);
        assertEq(agentIds[1], 1);
        assertEq(agentIds[2], 2);
        
        assertEq(registry.ownerOf(0), OWNER1);
        assertEq(registry.ownerOf(1), OWNER2);
        assertEq(registry.ownerOf(2), OWNER1);
        
        assertEq(string(registry.getMetadata(0, "name")), "Agent 1");
        assertEq(string(registry.getMetadata(1, "name")), "Agent 2");
        assertEq(string(registry.getMetadata(2, "name")), "Agent 3");
    }
    
    function test_006____registration____BatchRegistrationRevertsOnMismatch() public {
        address[] memory owners = new address[](2);
        owners[0] = OWNER1;
        owners[1] = OWNER2;
        
        IAgentRegistry.MetadataEntry[][] memory metadata = new IAgentRegistry.MetadataEntry[][](1);
        metadata[0] = new IAgentRegistry.MetadataEntry[](0);
        
        vm.prank(REGISTRAR);
        vm.expectRevert(AgentRegistry.ArrayLengthMismatch.selector);
        registry.registerBatch(owners, metadata);
    }
    
    function test_007____registration____OnlyRegistrarCanRegister() public {
        vm.prank(RANDOM_USER);
        vm.expectRevert();
        registry.register(OWNER1, "mcp", "https://example.com", address(0));
    }
    
    /* --- Access Control Tests --- */
    
    function test_008____accessControl____AdminCanGrantRoles() public {
        vm.prank(ADMIN);
        registry.grantRole(registry.REGISTRAR_ROLE(), RANDOM_USER);
        
        assertTrue(registry.hasRole(registry.REGISTRAR_ROLE(), RANDOM_USER));
    }
    
    function test_009____accessControl____NonAdminCannotGrantRoles() public {
        bytes32 registrarRole = registry.REGISTRAR_ROLE();
        
        vm.expectRevert();
        vm.prank(RANDOM_USER);
        registry.grantRole(registrarRole, OWNER1);
    }
    
    function test_010____accessControl____MetadataAdminCanSetContractMetadata() public {
        vm.prank(METADATA_ADMIN);
        registry.setContractMetadata("name", bytes("Agent Registry"));
        
        assertEq(string(registry.getContractMetadata("name")), "Agent Registry");
    }
    
    function test_011____accessControl____NonMetadataAdminCannotSetContractMetadata() public {
        vm.prank(RANDOM_USER);
        vm.expectRevert();
        registry.setContractMetadata("name", bytes("Agent Registry"));
    }
    
    /* --- ERC-6909 Transfer Tests --- */
    
    function test_012____transfer____OwnerCanTransfer() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(OWNER1);
        bool success = registry.transfer(OWNER2, agentId, 1);
        
        assertTrue(success);
        assertEq(registry.ownerOf(agentId), OWNER2);
        assertEq(registry.balanceOf(OWNER1, agentId), 0);
        assertEq(registry.balanceOf(OWNER2, agentId), 1);
    }
    
    function test_013____transfer____TransferRevertsOnInvalidAmount() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(OWNER1);
        vm.expectRevert(AgentRegistry.InvalidAmount.selector);
        registry.transfer(OWNER2, agentId, 2);
    }
    
    function test_014____transfer____TransferRevertsIfNotOwner() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.InsufficientBalance.selector, RANDOM_USER, agentId));
        registry.transfer(OWNER2, agentId, 1);
    }
    
    function test_015____transferFrom____OperatorCanTransferFrom() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(OWNER1);
        registry.setOperator(OPERATOR1, true);
        
        vm.prank(OPERATOR1);
        bool success = registry.transferFrom(OWNER1, OWNER2, agentId, 1);
        
        assertTrue(success);
        assertEq(registry.ownerOf(agentId), OWNER2);
    }
    
    function test_016____transferFrom____ApprovedSpenderCanTransferFrom() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(OWNER1);
        registry.approve(OPERATOR1, agentId, 1);
        
        vm.prank(OPERATOR1);
        bool success = registry.transferFrom(OWNER1, OWNER2, agentId, 1);
        
        assertTrue(success);
        assertEq(registry.ownerOf(agentId), OWNER2);
        
        // Allowance should be consumed (ERC-6909 compliant)
        assertEq(registry.allowance(OWNER1, OPERATOR1, agentId), 0);
    }
    
    function test_017____transferFrom____AllowanceIsConsumedAfterTransfer() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(OWNER1);
        registry.approve(OPERATOR1, agentId, 1);
        assertEq(registry.allowance(OWNER1, OPERATOR1, agentId), 1);
        
        vm.prank(OPERATOR1);
        registry.transferFrom(OWNER1, OWNER2, agentId, 1);
        
        // Allowance consumed after transfer
        assertEq(registry.allowance(OWNER1, OPERATOR1, agentId), 0);
    }
    
    function test_018____transferFrom____RevertsWithoutApproval() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.InsufficientPermission.selector, RANDOM_USER, agentId));
        registry.transferFrom(OWNER1, OWNER2, agentId, 1);
    }
    
    /* --- ERC-6909 Approval Tests --- */
    
    function test_019____approval____ApproveWorks() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(OWNER1);
        bool success = registry.approve(OPERATOR1, agentId, 1);
        
        assertTrue(success);
        assertEq(registry.allowance(OWNER1, OPERATOR1, agentId), 1);
    }
    
    function test_020____approval____ApproveCanBeRevoked() public {
        uint256 agentId = _registerBasicAgent();
        
        // Approve
        vm.prank(OWNER1);
        registry.approve(OPERATOR1, agentId, 1);
        assertEq(registry.allowance(OWNER1, OPERATOR1, agentId), 1);
        
        // Revoke with 0
        vm.prank(OWNER1);
        registry.approve(OPERATOR1, agentId, 0);
        assertEq(registry.allowance(OWNER1, OPERATOR1, agentId), 0);
    }
    
    function test_021____approval____SetOperatorWorks() public {
        vm.prank(OWNER1);
        bool success = registry.setOperator(OPERATOR1, true);
        
        assertTrue(success);
        assertTrue(registry.isOperator(OWNER1, OPERATOR1));
    }
    
    function test_022____approval____SetOperatorCanBeRevoked() public {
        vm.prank(OWNER1);
        registry.setOperator(OPERATOR1, true);
        
        vm.prank(OWNER1);
        registry.setOperator(OPERATOR1, false);
        
        assertFalse(registry.isOperator(OWNER1, OPERATOR1));
    }
    
    /* --- Token Metadata Authorization Tests --- */
    
    function test_023____tokenMetadata____OwnerCanSetMetadata() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(OWNER1);
        registry.setMetadata(agentId, "description", bytes("A helpful agent"));
        
        assertEq(string(registry.getMetadata(agentId, "description")), "A helpful agent");
    }
    
    function test_024____tokenMetadata____OperatorCanSetMetadata() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(OWNER1);
        registry.setOperator(OPERATOR1, true);
        
        vm.prank(OPERATOR1);
        registry.setMetadata(agentId, "description", bytes("Updated by operator"));
        
        assertEq(string(registry.getMetadata(agentId, "description")), "Updated by operator");
    }
    
    function test_025____tokenMetadata____NonOwnerNonOperatorCannotSetMetadata() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(RANDOM_USER);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.InsufficientPermission.selector, RANDOM_USER, agentId));
        registry.setMetadata(agentId, "description", bytes("Should fail"));
    }
    
    function test_026____tokenMetadata____ApprovedSpenderCannotSetMetadata() public {
        uint256 agentId = _registerBasicAgent();
        
        // Approve for transfer, but not operator
        vm.prank(OWNER1);
        registry.approve(OPERATOR1, agentId, 1);
        
        // Allowance doesn't grant metadata modification rights (only operator does)
        vm.prank(OPERATOR1);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.InsufficientPermission.selector, OPERATOR1, agentId));
        registry.setMetadata(agentId, "description", bytes("Should fail"));
    }
    
    function test_027____tokenMetadata____SetMetadataRevertsForNonExistentAgent() public {
        vm.prank(OWNER1);
        vm.expectRevert(AgentRegistry.AgentNotFound.selector);
        registry.setMetadata(999, "description", bytes("Should fail"));
    }
    
    /* --- Contract Metadata Tests --- */
    
    function test_028____contractMetadata____SetAndGetWorks() public {
        vm.prank(METADATA_ADMIN);
        registry.setContractMetadata("name", bytes("Agent Registry"));
        
        vm.prank(METADATA_ADMIN);
        registry.setContractMetadata("description", bytes("A registry for AI agents"));
        
        assertEq(string(registry.getContractMetadata("name")), "Agent Registry");
        assertEq(string(registry.getContractMetadata("description")), "A registry for AI agents");
    }
    
    function test_029____contractMetadata____CanUpdateExistingKey() public {
        vm.prank(METADATA_ADMIN);
        registry.setContractMetadata("name", bytes("Old Name"));
        
        vm.prank(METADATA_ADMIN);
        registry.setContractMetadata("name", bytes("New Name"));
        
        assertEq(string(registry.getContractMetadata("name")), "New Name");
    }
    
    /* --- OwnerOf Tests --- */
    
    function test_030____ownerOf____ReturnsCorrectOwner() public {
        uint256 agentId = _registerBasicAgent();
        
        assertEq(registry.ownerOf(agentId), OWNER1);
    }
    
    function test_031____ownerOf____RevertsForNonExistentAgent() public {
        vm.expectRevert(AgentRegistry.AgentNotFound.selector);
        registry.ownerOf(999);
    }
    
    /* --- ERC-165 Tests --- */
    
    function test_032____supportsInterface____SupportsERC6909() public view {
        assertTrue(registry.supportsInterface(0x0f632fb3));
    }
    
    function test_033____supportsInterface____SupportsOnchainMetadata() public view {
        assertTrue(registry.supportsInterface(type(IERC8048).interfaceId));
    }
    
    function test_034____supportsInterface____SupportsContractMetadata() public view {
        assertTrue(registry.supportsInterface(type(IERC8049).interfaceId));
    }
    
    function test_035____supportsInterface____SupportsAccessControl() public view {
        assertTrue(registry.supportsInterface(type(IAccessControl).interfaceId));
    }
    
    function test_036____supportsInterface____SupportsERC165() public view {
        assertTrue(registry.supportsInterface(0x01ffc9a7));
    }
    
    /* --- Event Tests --- */
    
    function test_037____events____RegisteredEventEmitted() public {
        vm.prank(REGISTRAR);
        vm.expectEmit(true, true, false, true);
        emit IAgentRegistry.Registered(0, OWNER1, "mcp", "https://agent.example.com", AGENT_ACCOUNT1);
        
        registry.register(OWNER1, "mcp", "https://agent.example.com", AGENT_ACCOUNT1);
    }
    
    function test_038____events____TransferEventEmittedOnMint() public {
        vm.prank(REGISTRAR);
        vm.expectEmit(true, true, true, true);
        emit IAgentRegistry.Transfer(REGISTRAR, address(0), OWNER1, 0, 1);
        
        registry.register(OWNER1, "mcp", "https://agent.example.com", AGENT_ACCOUNT1);
    }
    
    function test_039____events____MetadataSetEventEmitted() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(OWNER1);
        vm.expectEmit(true, true, false, true);
        emit IERC8048.MetadataSet(agentId, "description", "description", bytes("Test"));
        
        registry.setMetadata(agentId, "description", bytes("Test"));
    }
    
    function test_040____events____ContractMetadataUpdatedEventEmitted() public {
        vm.prank(METADATA_ADMIN);
        vm.expectEmit(true, false, false, true);
        emit IERC8049.ContractMetadataUpdated("name", "name", bytes("Registry"));
        
        registry.setContractMetadata("name", bytes("Registry"));
    }
    
    /* --- Edge Cases --- */
    
    function test_041____edgeCases____TransferUpdatesOwnership() public {
        uint256 agentId = _registerBasicAgent();
        
        vm.prank(OWNER1);
        registry.transfer(OWNER2, agentId, 1);
        
        // After transfer, new owner can set metadata
        vm.prank(OWNER2);
        registry.setMetadata(agentId, "newkey", bytes("newvalue"));
        
        assertEq(string(registry.getMetadata(agentId, "newkey")), "newvalue");
        
        // Old owner cannot set metadata
        vm.prank(OWNER1);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.InsufficientPermission.selector, OWNER1, agentId));
        registry.setMetadata(agentId, "anotherkey", bytes("value"));
    }
    
    function test_042____edgeCases____MultipleAgentsHaveSeparateOwnership() public {
        vm.startPrank(REGISTRAR);
        uint256 agent1 = registry.register(OWNER1, "mcp", "https://a1.com", address(0));
        uint256 agent2 = registry.register(OWNER2, "mcp", "https://a2.com", address(0));
        vm.stopPrank();
        
        assertEq(registry.ownerOf(agent1), OWNER1);
        assertEq(registry.ownerOf(agent2), OWNER2);
        
        assertEq(registry.balanceOf(OWNER1, agent1), 1);
        assertEq(registry.balanceOf(OWNER1, agent2), 0);
        assertEq(registry.balanceOf(OWNER2, agent1), 0);
        assertEq(registry.balanceOf(OWNER2, agent2), 1);
    }
    
    function test_043____edgeCases____OperatorApprovalIsGlobal() public {
        vm.startPrank(REGISTRAR);
        uint256 agent1 = registry.register(OWNER1, "mcp", "https://a1.com", address(0));
        uint256 agent2 = registry.register(OWNER1, "mcp", "https://a2.com", address(0));
        vm.stopPrank();
        
        vm.prank(OWNER1);
        registry.setOperator(OPERATOR1, true);
        
        // Operator can modify both agents
        vm.startPrank(OPERATOR1);
        registry.setMetadata(agent1, "key", bytes("val1"));
        registry.setMetadata(agent2, "key", bytes("val2"));
        vm.stopPrank();
        
        assertEq(string(registry.getMetadata(agent1, "key")), "val1");
        assertEq(string(registry.getMetadata(agent2, "key")), "val2");
    }
    
    /* --- Fuzz Tests --- */
    
    function testFuzz_044____fuzz____RegisterAndOwnerOf(address owner) public {
        vm.assume(owner != address(0));
        
        vm.prank(REGISTRAR);
        uint256 agentId = registry.register(owner, "mcp", "https://example.com", address(0));
        
        assertEq(registry.ownerOf(agentId), owner);
        assertEq(registry.balanceOf(owner, agentId), 1);
    }
    
    function testFuzz_045____fuzz____SetAndGetMetadata(uint256, string calldata key, bytes calldata value) public {
        // Register an agent first
        vm.prank(REGISTRAR);
        uint256 realAgentId = registry.register(OWNER1, "mcp", "", address(0));
        
        // Use the real agent ID
        vm.prank(OWNER1);
        registry.setMetadata(realAgentId, key, value);
        
        assertEq(registry.getMetadata(realAgentId, key), value);
    }
}

