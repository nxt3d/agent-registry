// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {ERC8048} from "../src/extensions/ERC8048.sol";
import {IERC8048} from "../src/interfaces/IERC8048.sol";

/**
 * @title MockERC8048
 * @dev Mock contract to test ERC8048 extension
 */
contract MockERC8048 is ERC8048 {
    mapping(uint256 => address) public owners;
    
    function mint(address to, uint256 tokenId) external {
        owners[tokenId] = to;
    }
    
    function setMetadata(uint256 tokenId, string calldata key, bytes calldata value) external {
        require(owners[tokenId] == msg.sender, "Not owner");
        _setMetadata(tokenId, key, value);
    }
    
    function setMetadataUnchecked(uint256 tokenId, string memory key, bytes memory value) external {
        _setMetadataUnchecked(tokenId, key, value);
    }
}

/**
 * @title ERC8048Test
 * @dev Tests for ERC8048 Onchain Token Metadata extension
 */
contract ERC8048Test is Test {
    
    /* --- State Variables --- */
    
    MockERC8048 public token;
    
    /* --- Test Addresses --- */
    
    address constant OWNER = address(0x1111111111111111111111111111111111111111);
    address constant OTHER = address(0x2222222222222222222222222222222222222222);
    
    /* --- Setup --- */
    
    function setUp() public {
        token = new MockERC8048();
        token.mint(OWNER, 1);
        token.mint(OWNER, 2);
        token.mint(OTHER, 3);
    }
    
    /* --- getMetadata Tests --- */
    
    function test_001____getMetadata____ReturnsEmptyForUnsetKey() public view {
        bytes memory value = token.getMetadata(1, "nonexistent");
        assertEq(value.length, 0);
    }
    
    function test_002____getMetadata____ReturnsSetValue() public {
        vm.prank(OWNER);
        token.setMetadata(1, "name", bytes("Test Token"));
        
        bytes memory value = token.getMetadata(1, "name");
        assertEq(string(value), "Test Token");
    }
    
    function test_003____getMetadata____DifferentTokensHaveSeparateMetadata() public {
        vm.prank(OWNER);
        token.setMetadata(1, "name", bytes("Token 1"));
        
        vm.prank(OWNER);
        token.setMetadata(2, "name", bytes("Token 2"));
        
        assertEq(string(token.getMetadata(1, "name")), "Token 1");
        assertEq(string(token.getMetadata(2, "name")), "Token 2");
    }
    
    function test_004____getMetadata____DifferentKeysAreSeparate() public {
        vm.prank(OWNER);
        token.setMetadata(1, "key1", bytes("value1"));
        
        vm.prank(OWNER);
        token.setMetadata(1, "key2", bytes("value2"));
        
        assertEq(string(token.getMetadata(1, "key1")), "value1");
        assertEq(string(token.getMetadata(1, "key2")), "value2");
    }
    
    /* --- _setMetadata Tests --- */
    
    function test_005____setMetadata____OwnerCanSetMetadata() public {
        vm.prank(OWNER);
        token.setMetadata(1, "description", bytes("A test token"));
        
        assertEq(string(token.getMetadata(1, "description")), "A test token");
    }
    
    function test_006____setMetadata____NonOwnerCannotSetMetadata() public {
        vm.prank(OTHER);
        vm.expectRevert("Not owner");
        token.setMetadata(1, "description", bytes("Hacked"));
    }
    
    function test_007____setMetadata____CanUpdateExistingKey() public {
        vm.prank(OWNER);
        token.setMetadata(1, "name", bytes("Old Name"));
        
        vm.prank(OWNER);
        token.setMetadata(1, "name", bytes("New Name"));
        
        assertEq(string(token.getMetadata(1, "name")), "New Name");
    }
    
    function test_008____setMetadata____CanSetEmptyValue() public {
        vm.prank(OWNER);
        token.setMetadata(1, "name", bytes("Test"));
        
        vm.prank(OWNER);
        token.setMetadata(1, "name", bytes(""));
        
        assertEq(token.getMetadata(1, "name").length, 0);
    }
    
    /* --- _setMetadataUnchecked Tests --- */
    
    function test_009____setMetadataUnchecked____WorksWithMemoryStrings() public {
        token.setMetadataUnchecked(1, "dynamic_key", bytes("dynamic_value"));
        
        assertEq(string(token.getMetadata(1, "dynamic_key")), "dynamic_value");
    }
    
    /* --- Event Tests --- */
    
    function test_010____events____MetadataSetEventEmitted() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, false, true);
        emit IERC8048.MetadataSet(1, "name", "name", bytes("Test"));
        
        token.setMetadata(1, "name", bytes("Test"));
    }
    
    function test_011____events____MetadataSetEventEmittedOnUpdate() public {
        vm.prank(OWNER);
        token.setMetadata(1, "name", bytes("Old"));
        
        vm.prank(OWNER);
        vm.expectEmit(true, true, false, true);
        emit IERC8048.MetadataSet(1, "name", "name", bytes("New"));
        
        token.setMetadata(1, "name", bytes("New"));
    }
    
    /* --- Diamond Storage Tests --- */
    
    function test_012____diamondStorage____StorageIsPersistent() public {
        vm.prank(OWNER);
        token.setMetadata(1, "persistent", bytes("data"));
        
        // Deploy a new instance pointing to same storage would require proxy pattern
        // For now, just verify the value persists across calls
        assertEq(string(token.getMetadata(1, "persistent")), "data");
    }
    
    /* --- Fuzz Tests --- */
    
    function testFuzz_013____fuzz____SetAndGetMetadata(
        uint256 tokenId,
        string calldata key,
        bytes calldata value
    ) public {
        // Mint token to owner
        token.mint(OWNER, tokenId);
        
        vm.prank(OWNER);
        token.setMetadata(tokenId, key, value);
        
        assertEq(token.getMetadata(tokenId, key), value);
    }
    
    function testFuzz_014____fuzz____MultipleKeysPerToken(
        uint256 tokenId,
        bytes calldata value1,
        bytes calldata value2
    ) public {
        token.mint(OWNER, tokenId);
        
        vm.startPrank(OWNER);
        token.setMetadata(tokenId, "key1", value1);
        token.setMetadata(tokenId, "key2", value2);
        vm.stopPrank();
        
        assertEq(token.getMetadata(tokenId, "key1"), value1);
        assertEq(token.getMetadata(tokenId, "key2"), value2);
    }
    
    /* --- Interface Support Tests --- */
    
    function test_015____interface____ImplementsIERC8048() public view {
        // Verify the contract has the expected function
        bytes memory result = token.getMetadata(1, "test");
        assertEq(result.length, 0);
    }
}






