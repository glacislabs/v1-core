// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

error GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero();
error GlacisRemoteCounterpartManager__RemoteCounterpartsAndChainIDsMustHaveSameLength();

interface IGlacisCrossChainTokenRegistry {
    /// @notice Adds an authorized glacis counterpart cross chain token in a remote chain that interacts with this component
    /// @param chainIds An array with chains of the glacis remote components
    /// @param sourceTokens An array of token local addresses to be registered
    /// @param destinationTokens An array of toke remote addresses to be registered
    function addTokenCounterparts(
        uint256[] calldata chainIds,
        address[] calldata sourceTokens,
        address[] calldata destinationTokens
    ) external;

    /// @notice Removes an authorized glacis counterpart component on remote chain that this components interacts with
    /// @param chainId The chainId to remove the remote component
    /// @param sourceToken The address of the token on this chain
    function removeTokenCounterpart(
        uint256 chainId,
        address sourceToken
    ) external;

    /// @notice Gets an authorized glacis counterpart component on remote chain that this components interacts with
    /// @param chainId The chainId to of the remote component
    /// @param sourceToken The address of the token on this chain
    function getTokenCounterpart(
        uint256 chainId,
        address sourceToken
    ) external returns (address);
}
