// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

interface IGlacisAccessControlClient {
    /// @notice Adds an allowed route for this client
    /// @notice Queries if a route from path GMP+Chain+Address is allowed for this client
    /// @return True if route is allowed, false otherwise
    function isAllowedRoute(
        uint256 fromChainId,
        address fromAddress,
        uint8 fromGmpId,
        bytes memory payload
    ) external view returns (bool);
}
