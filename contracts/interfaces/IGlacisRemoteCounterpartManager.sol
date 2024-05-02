// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

/// @title IGlacisRemoteCounterpartManager
/// @notice An interface that defines the existence and addition of a contract's remote counterparts
interface IGlacisRemoteCounterpartManager {
    /// @notice Adds an authorized glacis counterpart component in a remote chain that interacts with this component
    /// @param chainIds An array with chains of the glacis remote components
    /// @param glacisComponents An array of addresses of the glacis components on remote chains
    function addRemoteCounterparts(
        uint256[] calldata chainIds,
        bytes32[] calldata glacisComponents
    ) external;

    /// @notice Removes an authorized glacis counterpart component on remote chain that this components interacts with
    /// @param chainId The chainId to remove the remote component
    function removeRemoteCounterpart(uint256 chainId) external;

    /// @notice Gets an authorized glacis counterpart component on remote chain that this components interacts with
    /// @param chainId The chainId to of the remote component
    function getRemoteCounterpart(uint256 chainId) external returns (bytes32);
}
