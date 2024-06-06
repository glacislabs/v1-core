// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {IGlacisTokenMediator} from "../interfaces/IGlacisTokenMediator.sol";
import {IGlacisTokenClient} from "../interfaces/IGlacisTokenClient.sol";
import {GlacisClient} from "../client/GlacisClient.sol";
import {GlacisCommons} from "../commons/GlacisCommons.sol";

error GlacisTokenClient__CanOnlyBeCalledByTokenRouter();

/// @title Glacis Token Client
/// @dev This contract encapsulates Glacis Token Passing client logic, contracts inheriting this will have access to all
/// Glacis Token Passing and Message Passing features
abstract contract GlacisTokenClient is GlacisClient, IGlacisTokenClient {
    address public immutable GLACIS_TOKEN_ROUTER;
    event GlacisTokenClient__MessageRouted(
        bytes32 messageId,
        uint256 toChainId,
        bytes32 to
    );

    constructor(
        address glacisTokenMediator_,
        address glacisRouter_,
        uint256 quorum
    ) GlacisClient(glacisRouter_, quorum) {
        GLACIS_TOKEN_ROUTER = glacisTokenMediator_;
    }

    /// @notice Convenient method - Routes message and tokens to destination through GlacisTokenMediator using specified GMP without any additional feature
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapter Glacis ID or address of the adapter of the GMP to be used for the routing
    /// @param refundAddress Address to refund excess gas payment
    /// @param token Token (implementing XERC20 standard) to be sent to remote contract
    /// @param tokenAmount Amount of token to send to remote contract
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    function _routeWithTokensSingle(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address adapter,
        address refundAddress,
        address token,
        uint256 tokenAmount,
        uint256 gasPayment
    ) internal returns (bytes32) {
        address[] memory adapters = new address[](1);
        adapters[0] = adapter;
        AdapterIncentives[] memory fees = new AdapterIncentives[](1);
        fees[0] = AdapterIncentives({
            gasLimit: 0,
            nativeCurrencyValue: uint128(msg.value)
        });
        return
            _routeWithTokens(
                chainId,
                to,
                payload,
                adapters,
                fees,
                refundAddress,
                token,
                tokenAmount,
                gasPayment
            );
    }

    /// @notice Convenient method - Routes message and tokens to destination through GlacisTokenMediator using specified GMPs with redundancy feature
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param adapters The GMP Ids to use for routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param token A token address inheriting GlacisToken or GlacisTokenProxy standard (xERC-20)
    /// @param tokenAmount Amount of token to send to remote contract
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    function _routeWithTokensRedundant(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        AdapterIncentives[] memory fees,
        address refundAddress,
        address token,
        uint256 tokenAmount,
        uint256 gasPayment
    ) internal returns (bytes32) {
        return
            _routeWithTokens(
                chainId,
                to,
                payload,
                adapters,
                fees,
                refundAddress,
                token,
                tokenAmount,
                gasPayment
            );
    }

    /// @notice Routes message and tokens to destination through GlacisTokenMediator using any feature
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload The bytes payload to send across chains
    /// @param adapters An array of adapters to be used for the routing
    /// @param fees An array of values to send to the gmps & custom adapters. Should sum to the gasPayment
    /// @param refundAddress Address to refund excess gas payment
    /// @param token A token address inheriting GlacisToken or GlacisTokenProxy standard (xERC-20)
    /// @param tokenAmount Amount of token to send to remote contract
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    function _routeWithTokens(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        AdapterIncentives[] memory fees,
        address refundAddress,
        address token,
        uint256 tokenAmount,
        uint256 gasPayment
    ) internal returns (bytes32) {
        (bytes32 messageId,) = IGlacisTokenMediator(GLACIS_TOKEN_ROUTER).route{
            value: gasPayment
        }(chainId, to, payload, adapters, fees, refundAddress, token, tokenAmount);
        emit GlacisTokenClient__MessageRouted(messageId, chainId, to);
        return messageId;
    }

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using GMPs
    /// specified in gmps array
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload The bytes payload to send across chains
    /// @param adapters An array of custom adapters to be used for the routing
    /// @param fees An array of values to send to the gmps & custom adapters. Should sum to the gasPayment
    /// @param refundAddress Address to refund excess gas payment
    /// @param messageId The message ID of the message to retry
    /// @param nonce The nonce emitted by the original sent message
    /// @param token A token address inheriting GlacisToken or GlacisTokenProxy standard (xERC-20)
    /// @param tokenAmount Amount of token to send to remote contract
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    function _retryRouteWithTokens(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        AdapterIncentives[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce,
        address token,
        uint256 tokenAmount,
        uint256 gasPayment
    ) internal returns (bytes32) {
        IGlacisTokenMediator(GLACIS_TOKEN_ROUTER).routeRetry{value: gasPayment}(
            chainId,
            to,
            payload,
            adapters,
            fees,
            refundAddress,
            messageId,
            nonce,
            token,
            tokenAmount
        );
        emit GlacisTokenClient__MessageRouted(messageId, chainId, to);
        return messageId;
    }

    /// @notice Receives message from GMP(s) through GlacisTokenMediator
    /// @param fromAdapters Addresses that sent this message (that reached quorum requirements)
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param fromAddress Source address on source chain
    /// @param payload Routed payload
    /// @param token The address of the token being sent across chains
    /// @param tokenAmount The amount of the token being sent across chains
    function receiveMessageWithTokens(
        address[] memory fromAdapters,
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes memory payload,
        address token,
        uint256 tokenAmount
    ) external {
        if (msg.sender != GLACIS_TOKEN_ROUTER)
            revert GlacisTokenClient__CanOnlyBeCalledByTokenRouter();
        _receiveMessageWithTokens(
            fromAdapters,
            fromChainId,
            fromAddress,
            payload,
            token,
            tokenAmount
        );
    }

    /// @notice Receives message from GMP(s) through GlacisTokenMediator
    /// @param fromAdapters Adapter addresses
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param fromAddress Source address on source chain
    /// @param payload Routed payload
    /// @param token The address of the token being sent across chains
    /// @param tokenAmount The amount of the token being sent across chains
    function _receiveMessageWithTokens(
        address[] memory fromAdapters,
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes memory payload,
        address token,
        uint256 tokenAmount
    ) internal virtual {}

    /// @notice The quorum of messages that the contract expects with a specific message from the
    ///         token router
    /// @param glacisData The glacis config data that comes with the message
    function getQuorum(
        GlacisCommons.GlacisData memory glacisData,
        bytes memory payload,
        address, // token
        uint256 // tokenAmount
    ) external view virtual override returns (uint256) {
        return getQuorum(glacisData, payload);
    }
}
