// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;
import {GlacisCommons} from "../commons/GlacisCommons.sol";

/// @title IGlacisAccessControlClient
/// @notice An interface that determines Glacis' required access control
interface IGlacisAccessControlClient {
    /// @notice Adds an allowed route for this client
    /// @notice Queries if a route from path GMP+Chain+Address is allowed for this client
    /// @param route The origin route for the message
    /// @param payload The payload of a message
    /// @return True if route is allowed, false otherwise
    function isAllowedRoute(
        GlacisCommons.GlacisRoute memory route,
        bytes memory payload
    ) external view returns (bool);
}
