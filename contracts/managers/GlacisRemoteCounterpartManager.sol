// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error GlacisRemoteCounterpartManager__RemoteMediatorCannotHaveChainIdZero();
error GlacisRemoteCounterpartManager__MediatorsAndChainIDsMustHaveSameLength();

contract GlacisRemoteCounterpartManager is Ownable {

    mapping(uint256 => address) public remoteCounterpart;

    /// @notice Adds an authorized glacis counterpart component in a remote chain that interacts with this component
    /// @param chainIds An array with chains of the glacis remote components
    /// @param glacisComponents An array of addresses of the glacis components on remote chains
    function addRemoteCounterpart(
        uint256[] calldata chainIds,
        address[] calldata glacisComponents
    ) external onlyOwner {
        if (chainIds.length != glacisComponents.length)
            revert GlacisRemoteCounterpartManager__MediatorsAndChainIDsMustHaveSameLength();

        for (uint256 i; i < chainIds.length; ++i) {
            if (chainIds[i] == 0)
                revert GlacisRemoteCounterpartManager__RemoteMediatorCannotHaveChainIdZero();
            remoteCounterpart[chainIds[i]] = glacisComponents[i];
        }
    }

    /// @notice Removes an authorized glacis counterpart component on remote chain that this components interacts with
    /// @param chainId The chainId to remove the remote component
    function removeRemoteCounterpart(uint256 chainId) external onlyOwner {
        if (chainId == 0)
            revert GlacisRemoteCounterpartManager__RemoteMediatorCannotHaveChainIdZero();
        delete remoteCounterpart[chainId];
    }
}
