// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

library AddressBytes32 {
    /// @notice Converts an address to bytes32
    /// @param addr The address to be converted
    function toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function toAddress(bytes32 b) internal pure returns (address) {
        return address(uint160(uint256(b)));
    }
}
