// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

/// @title String to Address Library
/// @notice A library that a string to addresses
library AddressString {
    error AddressString__InvalidByteValue(bytes1 b);

    /// @notice Converts an hex string to address
    /// @param _hexString The hex string to be converted
    function toAddress(
        string memory _hexString
    ) internal pure returns (address) {
        bytes memory byte_sString = bytes(_hexString);
        uint160 _parsedBytes = 0;
        for (uint256 i = 0; i < byte_sString.length; i += 2) {
            _parsedBytes *= 256;
            uint8 byte_Value = parseByteToUint8(byte_sString[i]);
            byte_Value *= 16;
            byte_Value += parseByteToUint8(byte_sString[i + 1]);
            _parsedBytes += byte_Value;
        }
        return address(bytes20(_parsedBytes));
    }

    /// @notice Converts a bytes1 to uint8
    /// @param _byte The byte value to convert
    function parseByteToUint8(bytes1 _byte) internal pure returns (uint8) {
        if (uint8(_byte) >= 48 && uint8(_byte) <= 57) {
            return uint8(_byte) - 48;
        } else if (uint8(_byte) >= 65 && uint8(_byte) <= 70) {
            return uint8(_byte) - 55;
        } else if (uint8(_byte) >= 97 && uint8(_byte) <= 102) {
            return uint8(_byte) - 87;
        } else {
            revert AddressString__InvalidByteValue(_byte);
        }
    }
}
