// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {IGlacisAccessControlClient} from "../interfaces/IGlacisAccessControlClient.sol";
error GlacisAccessControlClient__RouteAlreadyAdded();

/// @title Glacis Access Control Client
/// @dev This contract encapsulates Glacis Access Control client logic. Contracts inheriting this will have access to
/// Glacis Access control features  
abstract contract GlacisAccessControlClient is GlacisCommons, IGlacisAccessControlClient {
    GlacisRoute[] private allowedRoutes;

    /// @notice Adds an allowed route for this client
    /// @param allowedRoute Route to be added
    function _addAllowedRoute(
        GlacisRoute memory allowedRoute
    ) internal {
        if (
            !isAllowedRoute(
                allowedRoute.fromChainId,
                allowedRoute.fromAddress,
                allowedRoute.fromApdater,
                ""
            )
        ) allowedRoutes.push(allowedRoute);
        else revert GlacisAccessControlClient__RouteAlreadyAdded();
    }

    /// @notice Get all allowed routes for this client
    /// @return Complete allowed routes array
    function getAllowedRoutes()
        external
        view
        returns (GlacisRoute[] memory)
    {
        return allowedRoutes;
    }

    /// @notice Removes an allowed route for this client
    /// @param route Allowed route to be removed
    function _removeAllowedRoute(
        GlacisRoute calldata route
    ) internal {
        for (uint256 i = 0; i < allowedRoutes.length; i++) {
            GlacisCommons.GlacisRoute memory allowedRoute = allowedRoutes[i];
            if (
                allowedRoute.fromApdater == route.fromApdater &&
                allowedRoute.fromChainId == route.fromChainId &&
                allowedRoute.fromAddress == route.fromAddress
            ) {
                allowedRoutes[i] = allowedRoutes[allowedRoutes.length - 1];
                allowedRoutes.pop();
            }
        }
    }

    /// @notice Removes all allowed routes for this client
    function _removeAllAllowedRoutes() internal {
        delete allowedRoutes;
    }

    /// @notice Queries if a route from path GMP+Chain+Address is allowed for this client
    /// @param fromChainId Source chain Id
    /// @param fromAddress Source address
    /// @param fromApdater source GMP Id
    /// @return True if route is allowed, false otherwise
    function isAllowedRoute(
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes32 fromApdater,
        bytes memory // payload
    ) public view override returns (bool) {
        for (uint256 i = 0; i < allowedRoutes.length; i++) {
            GlacisCommons.GlacisRoute memory allowedRoute = allowedRoutes[i];
            if (
                (allowedRoute.fromApdater == fromApdater ||
                    // NOTE: Wildcard should not allow any adapter to make any message, just Glacis' reserved IDs
                    (allowedRoute.fromApdater == 0 && uint(fromApdater) <= GLACIS_RESERVED_IDS)
                ) &&
                (allowedRoute.fromChainId == fromChainId ||
                    allowedRoute.fromChainId == 0) &&
                (allowedRoute.fromAddress == fromAddress ||
                    allowedRoute.fromAddress == bytes32(0))
            ) {
                return true;
            }
        }
        return false;
    }
}
