// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGlacisRemoteCounterpartManager} from "../interfaces/IGlacisRemoteCounterpartManager.sol";

error GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero();
error GlacisRemoteCounterpartManager__MediatorsAndChainIDsMustHaveSameLength();

contract GlacisRemoteCounterpartManager is
    IGlacisRemoteCounterpartManager,
    Ownable
{
    mapping(uint256 => address) public remoteCounterpart;

    /// @notice Adds an authorized glacis counterpart component in a remote chain that interacts with this component
    /// @param chainIds An array with chains of the glacis remote components
    /// @param counterpart An array of addresses of the glacis components on remote chains
    function addRemoteCounterparts(
        uint256[] calldata chainIds,
        address[] calldata counterpart
    ) external onlyOwner {
        if (chainIds.length != counterpart.length)
            revert GlacisRemoteCounterpartManager__MediatorsAndChainIDsMustHaveSameLength();
        for (uint256 i; i < chainIds.length; ++i) {
            if (chainIds[i] == 0)
                revert GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero();
            remoteCounterpart[chainIds[i]] = counterpart[i];
        }
    }

    /// @notice Removes an authorized glacis counterpart component on remote chain that this components interacts with
    /// @param chainId The chainId to remove the remote component
    function removeRemoteCounterpart(uint256 chainId) external onlyOwner {
        if (chainId == 0)
            revert GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero();
        delete remoteCounterpart[chainId];
    }

    /// @notice Gets an authorized glacis counterpart component on remote chain that this components interacts with
    /// @param chainId The chainId to of the remote component
    function getRemoteCounterpart(
        uint256 chainId
    ) public view returns (address) {
        return remoteCounterpart[chainId];
    }
}
