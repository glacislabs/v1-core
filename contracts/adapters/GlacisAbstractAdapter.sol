// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {IGlacisRouter} from "../interfaces/IGlacisRouter.sol";
import {IGlacisAdapter} from "../interfaces/IGlacisAdapter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error GlacisAbstractAdapter__OnlyGlacisRouterAllowed();
error GlacisAbstractAdapter__OnlyAdapterAllowed();
error GlacisAbstractAdapter__DestinationChainIdNotValid();
error GlacisAbstractAdapter__InvalidAdapterAddress();
error GlacisAbstractAdapter__InvalidChainId();
error GlacisAbstractAdapter__ChainCannotBeZero();
error GlacisAbstractAdapter__NoAdapterConfiguredForChain();
error GlacisAbstractAdapter__SourceChainNotRegistered();
error GlacisAbstractAdapter__IDArraysMustBeSameLength();
error GlacisAbstractAdapter__NoRemoteAdapterForChainId(uint256 chainId); //0xb295f036

/// @title Glacis Abstract Adapter for all GMPs
/// @notice All adapters inheriting from this contract will be able to receive GlacisRouter requests through _sendMessage
/// function
abstract contract GlacisAbstractAdapter is IGlacisAdapter, Ownable {
    IGlacisRouter public immutable GLACIS_ROUTER;

    mapping(uint256 => address) public remoteAdapters;

    constructor(IGlacisRouter _glacisRouter, address owner_) {
        transferOwnership(owner_);
        GLACIS_ROUTER = _glacisRouter;
    }

    /// @notice Dispatch payload to specified Glacis chain ID and address through a Glacis Adapter implementation
    /// @param toChainId Destination chain (Glacis ID)
    /// @param refundAddress The address to refund native asset surplus
    /// @param payload Payload to send
    function sendMessage(
        uint256 toChainId,
        address refundAddress,
        bytes calldata payload
    ) external payable override onlyGlacisRouter {
        _sendMessage(toChainId, refundAddress, payload);
    }

    /// @notice Dispatch payload to specified Glacis chain ID and address through a Glacis Adapter implementation
    /// @param toChainId Destination chain (Glacis ID)
    /// @param refundAddress The address to refund native asset surplus
    /// @param payload Payload to send
    function _sendMessage(
        uint256 toChainId,
        address refundAddress,
        bytes memory payload
    ) internal virtual;

    /// Verifies that the sender request is always GlacisRouter
    modifier onlyGlacisRouter() {
        if (msg.sender != address(GLACIS_ROUTER))
            revert GlacisAbstractAdapter__OnlyGlacisRouterAllowed();
        _;
    }

    /// @notice Adds a remote adapter on a destination chain where this adapter can route messages
    /// @param chainId The chainId to add the remote adapter
    /// @param adapter The address of the adapter on remote chain
    function _addRemoteAdapter(
        uint256 chainId,
        address adapter
    ) internal onlyOwner {
        if (address(adapter) == address(0))
            revert GlacisAbstractAdapter__InvalidAdapterAddress();
        if (chainId == 0) revert GlacisAbstractAdapter__ChainCannotBeZero();
        remoteAdapters[chainId] = adapter;
    }

    /// @notice Removes an authorized adapter on remote chain that this adapter accepts messages from
    /// @param chainId The chainId to remove the remote adapter
    function _removeRemoteAdapter(uint256 chainId) internal onlyOwner {
        if (chainId == 0) revert GlacisAbstractAdapter__ChainCannotBeZero();
        delete remoteAdapters[chainId];
    }

    /// @notice Verifies that the source address of the request is an authorized adapter
    /// @param sourceAddress Source address
    modifier onlyAuthorizedAdapter(uint256 chainId, address sourceAddress) {
        if (
            chainId == 0 ||
            remoteAdapters[chainId] == address(0) ||
            sourceAddress != remoteAdapters[chainId]
        ) {
            revert GlacisAbstractAdapter__OnlyAdapterAllowed();
        }
        _;
    }
}
