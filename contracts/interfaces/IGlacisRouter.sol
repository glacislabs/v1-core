// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";

/// @title IGlacisRouterEvents
/// @notice An interface that defines a GlacisRouter's events
abstract contract IGlacisRouterEvents is GlacisCommons
{
    event GlacisAbstractRouter__MessageIdCreated(
        bytes32 indexed messageId,
        bytes32 indexed sender,
        uint256 nonce
    );
    event GlacisRouter__ReceivedMessage(
        bytes32 indexed messageId,
        bytes32 indexed from,
        uint256 indexed fromChainId,
        bytes32 to
    );
    event GlacisRouter__MessageDispatched(
        bytes32 indexed messageId,
        bytes32 indexed from,
        uint256 indexed toChainId,
        bytes32 to,
        bytes data,
        address[] adapters,
        CrossChainGas[] fees,
        address refundAddress,
        bool retriable
    );
    event GlacisRouter__MessageRetried(
        bytes32 indexed messageId,
        bytes32 indexed from,
        uint256 indexed toChainId,
        bytes32 to,
        bytes data,
        address[] adapters,
        CrossChainGas[] fees,
        address refundAddress
    );
}

/// @title IGlacisRouter
/// @notice An interface that defines an interface that sends and receives messages across chains
interface IGlacisRouter {
    /// @notice Routes the payload to the specific address on the destination chain
    /// using specified GMPs with quorum and retribale feature
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapters An array of custom adapters to be used for the routing
    /// @param fees Array of fees to be sent to each GMP & custom adapter for routing (must be same length as gmps)
    /// @param refundAddress An (ideally EOA) address for native currency to be sent to that are greater than fees charged
    /// @param retriable True if this message could be retried
    function route(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        GlacisCommons.CrossChainGas[] memory fees,
        address refundAddress,
        bool retriable
    ) external payable returns (bytes32, uint256);

    /// @notice Retries routing the payload to the specific address on destination chain
    /// using specified GMPs and quorum
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapters An array of custom adapters to be used for the routing
    /// @param fees Array of fees to be sent to each GMP for routing (must be same length as gmps)
    /// @param refundAddress An (ideally EOA) address for native currency to be sent to that are greater than fees charged
    /// @param messageId The messageId to retry
    /// @param nonce Unique value for this message routing
    function routeRetry(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        GlacisCommons.CrossChainGas[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce
    ) external payable returns (bytes32);

    /// @notice Receives a cross chain message from an IGlacisAdapter.
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param glacisPayload Received payload with embedded GlacisData
    function receiveMessage(
        uint256 fromChainId,
        bytes memory glacisPayload
    ) external;
}
