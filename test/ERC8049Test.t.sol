// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {ERC8049} from "../src/extensions/ERC8049.sol";
import {IERC8049} from "../src/interfaces/IERC8049.sol";

/**
 * @title MockERC8049
 * @dev Mock contract to test ERC8049 extension
 */
contract MockERC8049 is ERC8049 {
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    function setContractMetadata(string calldata key, bytes calldata value) external onlyOwner {
        _setContractMetadata(key, value);
    }
}

/**
 * @title ERC8049Test
 * @dev Tests for ERC8049 Contract-Level Onchain Metadata extension
 */
contract ERC8049Test is Test {
    
    /* --- State Variables --- */
    
    MockERC8049 public registry;
    
    /* --- Test Addresses --- */
    
    address constant ADMIN = address(0x1111111111111111111111111111111111111111);
    address constant OTHER = address(0x2222222222222222222222222222222222222222);
    
    /* --- Setup --- */
    
    function setUp() public {
        vm.prank(ADMIN);
        registry = new MockERC8049();
    }
    
    /* --- getContractMetadata Tests --- */
    
    function test_001____getContractMetadata____ReturnsEmptyForUnsetKey() public view {
        bytes memory value = registry.getContractMetadata("nonexistent");
        assertEq(value.length, 0);
    }
    
    function test_002____getContractMetadata____ReturnsSetValue() public {
        vm.prank(ADMIN);
        registry.setContractMetadata("name", bytes("Test Registry"));
        
        bytes memory value = registry.getContractMetadata("name");
        assertEq(string(value), "Test Registry");
    }
    
    function test_003____getContractMetadata____DifferentKeysAreSeparate() public {
        vm.prank(ADMIN);
        registry.setContractMetadata("name", bytes("Registry Name"));
        
        vm.prank(ADMIN);
        registry.setContractMetadata("description", bytes("Registry Description"));
        
        assertEq(string(registry.getContractMetadata("name")), "Registry Name");
        assertEq(string(registry.getContractMetadata("description")), "Registry Description");
    }
    
    /* --- _setContractMetadata Tests --- */
    
    function test_004____setContractMetadata____OwnerCanSetMetadata() public {
        vm.prank(ADMIN);
        registry.setContractMetadata("symbol", bytes("REG"));
        
        assertEq(string(registry.getContractMetadata("symbol")), "REG");
    }
    
    function test_005____setContractMetadata____NonOwnerCannotSetMetadata() public {
        vm.prank(OTHER);
        vm.expectRevert("Not owner");
        registry.setContractMetadata("name", bytes("Hacked"));
    }
    
    function test_006____setContractMetadata____CanUpdateExistingKey() public {
        vm.prank(ADMIN);
        registry.setContractMetadata("name", bytes("Old Name"));
        
        vm.prank(ADMIN);
        registry.setContractMetadata("name", bytes("New Name"));
        
        assertEq(string(registry.getContractMetadata("name")), "New Name");
    }
    
    function test_007____setContractMetadata____CanSetEmptyValue() public {
        vm.prank(ADMIN);
        registry.setContractMetadata("name", bytes("Test"));
        
        vm.prank(ADMIN);
        registry.setContractMetadata("name", bytes(""));
        
        assertEq(registry.getContractMetadata("name").length, 0);
    }
    
    /* --- Event Tests --- */
    
    function test_008____events____ContractMetadataUpdatedEventEmitted() public {
        vm.prank(ADMIN);
        vm.expectEmit(true, false, false, true);
        emit IERC8049.ContractMetadataUpdated("name", "name", bytes("Test"));
        
        registry.setContractMetadata("name", bytes("Test"));
    }
    
    function test_009____events____EventEmittedOnUpdate() public {
        vm.prank(ADMIN);
        registry.setContractMetadata("name", bytes("Old"));
        
        vm.prank(ADMIN);
        vm.expectEmit(true, false, false, true);
        emit IERC8049.ContractMetadataUpdated("name", "name", bytes("New"));
        
        registry.setContractMetadata("name", bytes("New"));
    }
    
    /* --- Standard Metadata Keys Tests --- */
    
    function test_010____standardKeys____NameKey() public {
        vm.prank(ADMIN);
        registry.setContractMetadata("name", bytes("My Registry"));
        
        assertEq(string(registry.getContractMetadata("name")), "My Registry");
    }
    
    function test_011____standardKeys____DescriptionKey() public {
        vm.prank(ADMIN);
        registry.setContractMetadata("description", bytes("A registry for tokens"));
        
        assertEq(string(registry.getContractMetadata("description")), "A registry for tokens");
    }
    
    function test_012____standardKeys____ImageKey() public {
        vm.prank(ADMIN);
        registry.setContractMetadata("image", bytes("ipfs://QmHash"));
        
        assertEq(string(registry.getContractMetadata("image")), "ipfs://QmHash");
    }
    
    function test_013____standardKeys____SymbolKey() public {
        vm.prank(ADMIN);
        registry.setContractMetadata("symbol", bytes("REG"));
        
        assertEq(string(registry.getContractMetadata("symbol")), "REG");
    }
    
    /* --- Diamond Storage Tests --- */
    
    function test_014____diamondStorage____StorageIsPersistent() public {
        vm.prank(ADMIN);
        registry.setContractMetadata("persistent", bytes("data"));
        
        // Verify the value persists across calls
        assertEq(string(registry.getContractMetadata("persistent")), "data");
    }
    
    /* --- Fuzz Tests --- */
    
    function testFuzz_015____fuzz____SetAndGetContractMetadata(
        string calldata key,
        bytes calldata value
    ) public {
        vm.prank(ADMIN);
        registry.setContractMetadata(key, value);
        
        assertEq(registry.getContractMetadata(key), value);
    }
    
    function testFuzz_016____fuzz____MultipleKeys(
        bytes calldata value1,
        bytes calldata value2,
        bytes calldata value3
    ) public {
        vm.startPrank(ADMIN);
        registry.setContractMetadata("key1", value1);
        registry.setContractMetadata("key2", value2);
        registry.setContractMetadata("key3", value3);
        vm.stopPrank();
        
        assertEq(registry.getContractMetadata("key1"), value1);
        assertEq(registry.getContractMetadata("key2"), value2);
        assertEq(registry.getContractMetadata("key3"), value3);
    }
    
    /* --- Interface Support Tests --- */
    
    function test_017____interface____ImplementsIERC8049() public view {
        // Verify the contract has the expected function
        bytes memory result = registry.getContractMetadata("test");
        assertEq(result.length, 0);
    }
}



