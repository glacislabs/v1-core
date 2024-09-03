// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {IGlacisAccessControlClient} from "../interfaces/IGlacisAccessControlClient.sol";

/// @title Glacis Access Control Client
/// @dev This contract encapsulates Glacis Access Control client logic. Contracts inheriting this will have access to
/// Glacis Access control features  
abstract contract GlacisAccessControlClient is GlacisCommons, IGlacisAccessControlClient {
    mapping(uint256 => mapping(bytes32 => mapping(address => bool))) public allowedRoutes;

    bytes32 constant internal WILD_BYTES = bytes32(uint256(WILDCARD));
    address constant internal WILD_ADDR = address(WILDCARD);

    /// @notice Adds an allowed route for this client
    /// @param route Route to be added
    function _addAllowedRoute(
        GlacisRoute memory route
    ) internal {
        allowedRoutes[route.fromChainId][route.fromAddress][route.fromAdapter] = true;
    }

    /// @notice Removes an allowed route for this client
    /// @param route Allowed route to be removed
    function _removeAllowedRoute(
        GlacisRoute calldata route
    ) internal {
        allowedRoutes[route.fromChainId][route.fromAddress][route.fromAdapter] = false;
    }

    /// @notice Queries if a route from path GMP+Chain+Address is allowed for this client
    /// @param route_ Incoming message route
    /// @return True if route is allowed, false otherwise
    function isAllowedRoute(
        GlacisRoute memory route_,
        bytes memory // payload
    ) public view override returns (bool) {
        return
            allowedRoutes[route_.fromChainId][route_.fromAddress][route_.fromAdapter] ||
            allowedRoutes[WILDCARD][route_.fromAddress][route_.fromAdapter] ||
            allowedRoutes[WILDCARD][WILD_BYTES][route_.fromAdapter] ||
            allowedRoutes[route_.fromChainId][WILD_BYTES][route_.fromAdapter] ||
            (uint160(route_.fromAdapter) <= GLACIS_RESERVED_IDS && (
                allowedRoutes[route_.fromChainId][route_.fromAddress][WILD_ADDR] ||
                allowedRoutes[route_.fromChainId][WILD_BYTES][WILD_ADDR] ||
                allowedRoutes[WILDCARD][WILD_BYTES][WILD_ADDR]
            ));
    }
}
