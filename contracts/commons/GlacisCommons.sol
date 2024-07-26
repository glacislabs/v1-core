// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

/// @title Glacis Commons
/// @dev Contract for utility functions and structures common to Glacis Client and Infrastructure
contract GlacisCommons {
    struct GlacisData {
        bytes32 messageId;
        uint256 nonce;
        bytes32 originalFrom;
        bytes32 originalTo;
    }

    struct GlacisTokenData {
        address glacisToken;
        uint256 glacisTokenAmount;
    }

    struct GlacisRoute {
        uint256 fromChainId; // WILDCARD means any chain
        bytes32 fromAddress; // WILDCARD means any address
        address fromAdapter; // WILDCARD means any GMP, can also hold address
    }

    struct CrossChainGas {
        uint128 gasLimit;
        uint128 nativeCurrencyValue;
    }

    uint160 constant public WILDCARD = type(uint160).max;
    uint256 constant public GLACIS_RESERVED_IDS = 248;
}
