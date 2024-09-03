// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IGlacisRemoteCounterpartManager} from "../interfaces/IGlacisRemoteCounterpartManager.sol";

error GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero();
error GlacisRemoteCounterpartManager__CounterpartsAndChainIDsMustHaveSameLength();

/// @title Glacis Remote Counterpart Manager
/// @notice An inheritable contract that allows an owner to add and remove remote counterparts
/// @notice Is an ownable contract
contract GlacisRemoteCounterpartManager is
    IGlacisRemoteCounterpartManager,
    Ownable2Step
{
    mapping(uint256 => bytes32) internal remoteCounterpart;

    /// @notice Adds an authorized glacis counterpart component in a remote chain that interacts with this component
    /// @param chainIDs An array with chains of the glacis remote components
    /// @param counterpart An array of addresses of the glacis components on remote chains
    function addRemoteCounterparts(
        uint256[] calldata chainIDs,
        bytes32[] calldata counterpart
    ) external onlyOwner {
        if (chainIDs.length != counterpart.length)
            revert GlacisRemoteCounterpartManager__CounterpartsAndChainIDsMustHaveSameLength();
        for (uint256 i; i < chainIDs.length; ++i) {
            if (chainIDs[i] == 0)
                revert GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero();
            remoteCounterpart[chainIDs[i]] = counterpart[i];
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
    ) public view returns (bytes32) {
        return remoteCounterpart[chainId];
    }
}
