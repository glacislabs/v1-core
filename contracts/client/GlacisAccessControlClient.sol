// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {IGlacisAccessControlClient} from "../interfaces/IGlacisAccessControlClient.sol";
error GlacisAccessControlClient__RouteAlreadyAdded();

/// @title Glacis Access Control Client
/// @dev This contract encapsulates Glacis Access Control client logic. Contracts inheriting this will have access to
/// Glacis Access control features  
abstract contract GlacisAccessControlClient is GlacisCommons, IGlacisAccessControlClient {
    mapping(uint256 => mapping(bytes32 => mapping(address => bool))) private allowedRoutes;

    bytes32 constant internal WILD_BYTES = bytes32(uint256(WILDCARD));
    address constant internal WILD_ADDR = address(uint160(uint256(WILDCARD)));

    /// @notice Adds an allowed route for this client
    /// @param route Route to be added
    function _addAllowedRoute(
        GlacisRoute memory route
    ) internal {
        if (
            !isAllowedRoute(
                route.fromChainId,
                route.fromAddress,
                route.fromAdapter,
                ""
            )
        ) allowedRoutes[route.fromChainId][route.fromAddress][route.fromAdapter] = true;
        else revert GlacisAccessControlClient__RouteAlreadyAdded();
    }

    /// @notice Removes an allowed route for this client
    /// @param route Allowed route to be removed
    function _removeAllowedRoute(
        GlacisRoute calldata route
    ) internal {
        allowedRoutes[route.fromChainId][route.fromAddress][route.fromAdapter] = false;
    }

    /// @notice Queries if a route from path GMP+Chain+Address is allowed for this client
    /// @param fromChainId Source chain Id
    /// @param fromAddress Source address
    /// @param fromAdapter source GMP Id
    /// @return True if route is allowed, false otherwise
    function isAllowedRoute(
        uint256 fromChainId,
        bytes32 fromAddress,
        address fromAdapter,
        bytes memory // payload
    ) public view override returns (bool) {
        return
            allowedRoutes[fromChainId][fromAddress][fromAdapter] ||
            allowedRoutes[WILDCARD][fromAddress][fromAdapter] ||
            allowedRoutes[WILDCARD][WILD_BYTES][fromAdapter] ||
            allowedRoutes[fromChainId][WILD_BYTES][fromAdapter] ||
            (uint160(fromAdapter) <= GLACIS_RESERVED_IDS && (
                allowedRoutes[fromChainId][fromAddress][WILD_ADDR] ||
                allowedRoutes[fromChainId][WILD_BYTES][WILD_ADDR] ||
                allowedRoutes[WILDCARD][WILD_BYTES][WILD_ADDR]
            ));
    }
}
