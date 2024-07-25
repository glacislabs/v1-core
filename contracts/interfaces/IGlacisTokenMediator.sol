// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";

/// @title IGlacisTokenMediator
/// @notice An interface of a mediator that sends XERC20s with a payload across chains  
interface IGlacisTokenMediator {
    event GlacisTokenMediator__TokensBurnt(
        address from,
        address token,
        uint256 amount
    );
    event GlacisTokenMediator__TokensMinted(
        address to,
        address token,
        uint256 amount
    );

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using GMPs
    /// specified in gmps array
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapters An array of custom adapters to be used for the routing
    /// @param fees Payment for each GMP & custom adapter to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param token Token (implementing XERC20 standard) to be sent to remote contract
    /// @param tokenAmount Amount of token to send to remote contract
    /// @return A tuple with a bytes32 messageId and a uint256 nonce
    function route(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        GlacisCommons.CrossChainGas[] memory fees,
        address refundAddress,
        address token,
        uint256 tokenAmount
    ) external payable returns (bytes32, uint256);

    /// @notice Retries routing the payload to the specific address on destination chain using specified GMPs
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapters An array of custom adapters to be used for the routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param messageId The message ID of the message to retry
    /// @param nonce The nonce emitted by the original message routing
    /// @param token Token (implementing XERC20 standard) to be sent to remote contract
    /// @param tokenAmount Amount of token to send to remote contract
    /// @return A tuple with a bytes32 messageId and a uint256 nonce
    function routeRetry(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        GlacisCommons.CrossChainGas[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce,
        address token,
        uint256 tokenAmount
    ) external payable returns (bytes32, uint256);
}
