// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {IGlacisRouter} from "../interfaces/IGlacisRouter.sol";
import {IGlacisClient} from "../interfaces/IGlacisClient.sol";
import {GlacisAccessControlClient} from "../client/GlacisAccessControlClient.sol";
error GlacisClient__CanOnlyBeCalledByRouter();
error GlacisClient__InvalidRouterAddress();

/// @title Glacis Client
/// @dev This contract encapsulates Glacis client side logic, contracts inheriting this will have access to all
/// Glacis features
abstract contract GlacisClient is GlacisAccessControlClient, IGlacisClient {
    address public immutable GLACIS_ROUTER;
    GlacisCommons.GlacisRoute[] private allowedRoutes;

    event GlacisClient__MessageRouted(
        bytes32 messageId,
        uint256 toChainId,
        bytes32 to
    );

    constructor(
        address glacisRouter_,
        uint256 quorum
    ) GlacisAccessControlClient() IGlacisClient(quorum) {
        if (glacisRouter_ == address(0))
            revert GlacisClient__InvalidRouterAddress();
        GLACIS_ROUTER = glacisRouter_;
    }

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using a single specified GMP
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param gmp Glacis ID of the GMP to be used for the routing
    /// @param refundAddress Address to refund excess gas payment
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    function _routeSingle(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        uint8 gmp,
        address refundAddress,
        uint256 gasPayment
    ) internal returns (bytes32) {
        uint8[] memory gmps = new uint8[](1);
        gmps[0] = gmp;
        uint256[] memory fees = new uint256[](1);
        fees[0] = gasPayment;
        bytes32 messageId = IGlacisRouter(GLACIS_ROUTER).route{
            value: gasPayment
        }(chainId, to, payload, gmps, emptyCustomAdapters(), fees, refundAddress, false);
        emit GlacisClient__MessageRouted(messageId, chainId, to);
        return messageId;
    }

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using
    /// specified GMPs.
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param gmps The GMP Ids to use for redundant routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    /// @param gmps Glacis ID of the GMP to be used for the routing
    function _routeRedundant(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        uint8[] memory gmps,
        uint256[] memory fees,
        address refundAddress,
        uint256 gasPayment
    ) internal returns (bytes32) {
        bytes32 messageId = IGlacisRouter(GLACIS_ROUTER).route{
            value: gasPayment
        }(chainId, to, payload, gmps, emptyCustomAdapters(), fees, refundAddress, false);
        emit GlacisClient__MessageRouted(messageId, chainId, to);
        return messageId;
    }

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using GMPs
    /// specified in gmps array
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param gmps The GMP Ids to use for routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param retriable True to enable retry feature for this message
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    function _route(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        uint8[] memory gmps,
        address[] memory customAdapters,
        uint256[] memory fees,
        address refundAddress,
        bool retriable,
        uint256 gasPayment
    ) internal returns (bytes32) {
        bytes32 messageId = IGlacisRouter(GLACIS_ROUTER).route{
            value: gasPayment
        }(chainId, to, payload, gmps, customAdapters, fees, refundAddress, retriable);
        emit GlacisClient__MessageRouted(messageId, chainId, to);
        return messageId;
    }

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using GMPs
    /// specified in gmps array
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param gmps The GMP Ids to use for routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param messageId The message ID of the message to retry
    /// @param nonce The nonce emitted by the original sent message
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    function _retryRoute(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        uint8[] memory gmps,
        address[] memory customAdapters,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce,
        uint256 gasPayment
    ) internal returns (bytes32) {
        IGlacisRouter(GLACIS_ROUTER).routeRetry{value: gasPayment}(
            chainId,
            to,
            payload,
            gmps,
            customAdapters,
            fees,
            refundAddress,
            messageId,
            nonce
        );
        emit GlacisClient__MessageRouted(messageId, chainId, to);
        return messageId;
    }

    /// @notice Receives message from GMP(s) through GlacisRouter
    /// @param fromGmpIds ID of the GMP that sent this message (that reached quorum requirements)
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param fromAddress Source address on source chain
    /// @param payload Routed payload
    function receiveMessage(
        uint8[] memory fromGmpIds,
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes memory payload
    ) external virtual override {
        if (msg.sender != GLACIS_ROUTER)
            revert GlacisClient__CanOnlyBeCalledByRouter();

        _receiveMessage(fromGmpIds, fromChainId, fromAddress, payload);
    }

    /// @notice Receives message from GMP(s) through GlacisRouter
    /// @param fromGmpIds GMP Id
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param fromAddress Source address on source chain
    /// @param payload Routed payload
    function _receiveMessage(
        uint8[] memory fromGmpIds,
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes memory payload
    ) internal virtual {}

    /// @notice Helper function to create an empty array of custom adapters.
    function emptyCustomAdapters() internal pure returns(address[] memory) {
        return new address[](0);
    }
}
