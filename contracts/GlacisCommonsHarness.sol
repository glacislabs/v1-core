// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisCommons} from "../../contracts/commons/GlacisCommons.sol";

/// @title Glacis Commons Harness
/// @dev Contract for testing GlacisCommons internal functions
contract GlacisCommonsHarness is GlacisCommons {
    /// @notice De-serialize a uint8 bitmap to an uint8 array
    /// @param bitmap The bitmap to be de-serialized
    /// @return The de-serialized array
    function uint8ToUint8Array(
        uint8 bitmap
    ) public pure returns (uint8[] memory) {
        return _uint8ToUint8Array(bitmap);
    }

    /// @notice Queries if a bit is ON on a bitmap
    /// @param bitmap The bitmap to be de-serialized
    /// @param bitIndex The bitindex to query
    /// @return True if the bit is on, false otherwise
    function isBitSet(uint8 bitmap, uint8 bitIndex) public pure returns (bool) {
        return _isBitSet(bitmap, bitIndex);
    }

    /// @notice Set a bit to ON on a bitmap
    /// @param bitmap The bitmap to be modified
    /// @param bitIndex The bitindex to set to 1
    /// @return the modified bitmap with the bit set
    function setBit(uint8 bitmap, uint8 bitIndex) public pure returns (uint8) {
        return _setBit(bitmap, bitIndex);
    }
}
