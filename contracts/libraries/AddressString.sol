// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

library AddressString {
    /// @notice Converts an hex string to address
    /// @param hexString_ The hex string to be converted
    function toAddress(
        string memory hexString_
    ) internal pure returns (address) {
        bytes memory byte_sString = bytes(hexString_);
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
    /// @param byte_ The byte value to convert
    function parseByteToUint8(bytes1 byte_) internal pure returns (uint8) {
        if (uint8(byte_) >= 48 && uint8(byte_) <= 57) {
            return uint8(byte_) - 48;
        } else if (uint8(byte_) >= 65 && uint8(byte_) <= 70) {
            return uint8(byte_) - 55;
        } else if (uint8(byte_) >= 97 && uint8(byte_) <= 102) {
            return uint8(byte_) - 87;
        } else {
            revert(string(abi.encode("Invalid byte value: ", byte_)));
        }
    }
}
