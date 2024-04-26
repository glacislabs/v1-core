// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

/// @title IGlacisAccessControlClient
/// @notice An interface that determines Glacis' required access control
interface IGlacisAccessControlClient {
    /// @notice Adds an allowed route for this client
    /// @notice Queries if a route from path GMP+Chain+Address is allowed for this client
    /// @param fromChainId The chain ID of a message's origin
    /// @param fromAddress The source address of a message's origin
    /// @param fromGmpId The GMP ID or custom adapter address of a message's origin
    /// @param payload The payload of a message
    /// @return True if route is allowed, false otherwise
    function isAllowedRoute(
        uint256 fromChainId,
        bytes32 fromAddress,
        uint160 fromGmpId, // Could also be address
        bytes memory payload
    ) external view returns (bool);
}
