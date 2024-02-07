// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

/// @title Glacis Commons
/// @dev Contract for utility functions and structures common to Glacis Client and Infrastructure
contract GlacisCommons {
    struct GlacisData {
        bytes32 messageId;
        uint256 nonce;
        address originalFrom;
        address originalTo;
    }

    struct GlacisTokenData {
        address glacisToken;
        uint256 glacisTokenAmount;
    }

    struct GlacisRoute {
        uint256 fromChainId; // 0 means any chain
        address fromAddress; // 0x00 means any address
        uint8 fromGmpId; // 0 means any GMP
    }

    /// @notice De-serialize a uint8 bitmap to an uint8 array
    /// @param bitmap The bitmap to be de-serialized
    /// @return The de-serialized array
    function _uint8ToUint8Array(
        uint8 bitmap
    ) internal pure returns (uint8[] memory) {
        uint8[] memory result = new uint8[](8);
        uint8 size;
        for (uint8 i = 0; i < 8; i++) {
            // Extract each bit from the uint8 value and store it as a uint8 element in the array
            if ((bitmap >> i) & uint8(1) == uint8(1)) result[size++] = i + 1;
        }
        assembly {
            mstore(result, size)
        }
        return result;
    }

    /// @notice Queries if a bit is ON on a bitmap
    /// @param bitmap The bitmap to be queried
    /// @param bitIndex The bitindex to query
    /// @return True if the bit is on, false otherwise
    function _isBitSet(
        uint8 bitmap,
        uint8 bitIndex
    ) internal pure returns (bool) {
        return (bitmap & (uint8(1) << bitIndex)) != 0;
    }

    /// @notice Set a bit to ON on a bitmap
    /// @param bitmap The bitmap to be modified
    /// @param bitIndex The bitindex to set to 1
    /// @return the modified bitmap with the bit set
    function _setBit(
        uint8 bitmap,
        uint8 bitIndex
    ) internal pure returns (uint8) {
        return bitmap | (uint8(1) << bitIndex);
    }
}
