// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC8048} from "../interfaces/IERC8048.sol";

/**
 * @title ERC8048
 * @author @nxt3d
 * @notice Abstract extension for ERC-8048 Onchain Token Metadata
 * @dev Token-standard agnostic - works with ERC-721, ERC-6909, ERC-1155, etc.
 *      Uses Diamond Storage pattern for predictable storage locations.
 *      Implementing contracts must define their own authorization logic.
 */
abstract contract ERC8048 is IERC8048 {
    /// @custom:storage-location erc8048.onchain.metadata.storage
    struct ERC8048Storage {
        mapping(uint256 tokenId => mapping(string key => bytes value)) metadata;
    }

    // keccak256("erc8048.onchain.metadata.storage")
    bytes32 private constant ERC8048_STORAGE_LOCATION =
        0x1d573f2bd60f6bb1db4803946b72dd4484532d479f45b50538c89a2000f39b92;

    function _getERC8048Storage() private pure returns (ERC8048Storage storage $) {
        bytes32 location = ERC8048_STORAGE_LOCATION;
        assembly {
            $.slot := location
        }
    }

    /// @inheritdoc IERC8048
    function getMetadata(uint256 tokenId, string calldata key) external view virtual returns (bytes memory) {
        ERC8048Storage storage $ = _getERC8048Storage();
        return $.metadata[tokenId][key];
    }

    /**
     * @notice Internal function to set metadata for a token
     * @dev Call this from your public setMetadata function after checking authorization
     * @param tokenId The token ID to set metadata for
     * @param key The metadata key
     * @param value The metadata value as bytes
     */
    function _setMetadata(uint256 tokenId, string calldata key, bytes calldata value) internal virtual {
        ERC8048Storage storage $ = _getERC8048Storage();
        $.metadata[tokenId][key] = value;
        emit MetadataSet(tokenId, key, key, value);
    }

    /**
     * @notice Internal function to set metadata using memory strings (for internal use)
     * @param tokenId The token ID to set metadata for
     * @param key The metadata key
     * @param value The metadata value as bytes
     */
    function _setMetadataUnchecked(uint256 tokenId, string memory key, bytes memory value) internal virtual {
        ERC8048Storage storage $ = _getERC8048Storage();
        $.metadata[tokenId][key] = value;
        emit MetadataSet(tokenId, key, key, value);
    }
}






