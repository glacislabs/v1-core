// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGlacisCrossChainTokenRegistry} from "../interfaces/IGlacisCrossChainTokenRegistry.sol";

error GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero();
error GlacisRemoteCounterpartManager__RemoteCounterpartsAndChainIDsMustHaveSameLength();

contract GlacisCrossChainTokenRegistry is
    IGlacisCrossChainTokenRegistry,
    Ownable
{
    mapping(uint256 chainId => mapping(address sourceToken => address destinationToken))
        public remoteTokenCounterpart;

    /// @notice Adds an authorized glacis counterpart component in a remote chain that interacts with this component
    /// @param chainIds An array with chains to be registered
    /// @param sourceTokens An array of token addresses on this chain
    /// @param destinationTokens An array of token addresses on remote chain
    function addTokenCounterparts(
        uint256[] calldata chainIds,
        address[] calldata sourceTokens,
        address[] calldata destinationTokens
    ) external override onlyOwner {
        if (
            chainIds.length != sourceTokens.length &&
            chainIds.length != destinationTokens.length
        )
            revert GlacisRemoteCounterpartManager__RemoteCounterpartsAndChainIDsMustHaveSameLength();
        for (uint256 i; i < chainIds.length; ++i) {
            if (chainIds[i] == 0)
                revert GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero();
            remoteTokenCounterpart[chainIds[i]][
                sourceTokens[i]
            ] = destinationTokens[i];
        }
    }

    /// @notice Removes an authorized glacis counterpart component on remote chain that this components interacts with
    /// @param chainId The chainId to remove the remote component
    /// @param sourceToken The address of the token on this chain
    function removeTokenCounterpart(
        uint256 chainId,
        address sourceToken
    ) external override onlyOwner {
        if (chainId == 0)
            revert GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero();
        delete remoteTokenCounterpart[chainId][sourceToken];
    }

    /// @notice Gets an authorized glacis counterpart component on remote chain that this components interacts with
    /// @param chainId The chainId to of the remote component
    /// @param sourceToken The address of the token on this chain
    function getTokenCounterpart(
        uint256 chainId,
        address sourceToken
    ) public view override returns (address) {
        return remoteTokenCounterpart[chainId][sourceToken];
    }
}
