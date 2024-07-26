// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

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

    event GlacisClient__MessageRouted(
        bytes32 indexed messageId,
        uint256 toChainId,
        bytes32 to
    );
    
    event GlacisClient__MessageArrived(
        address[] fromAdapters,
        uint256 fromChainId,
        bytes32 fromAddress
    );

    /// @param _glacisRouter This chain's deployment of the GlacisRouter  
    /// @param _quorum The initial default quorum for this client. If dynamic quorum is to be implemented (depending on payload)
    /// this value can be ignored and set to 0  
    constructor(
        address _glacisRouter,
        uint256 _quorum
    ) GlacisAccessControlClient() IGlacisClient(_quorum) {
        if (_glacisRouter == address(0))
            revert GlacisClient__InvalidRouterAddress();
        GLACIS_ROUTER = _glacisRouter;
    }

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using a single specified GMP
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapter Glacis ID of the GMP to be used for the routing
    /// @param refundAddress Address to refund excess gas payment
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    function _routeSingle(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address adapter,
        address refundAddress,
        uint256 gasPayment
    ) internal returns (bytes32) {
        address[] memory adapters = new address[](1);
        adapters[0] = adapter;
        CrossChainGas[] memory fees = new CrossChainGas[](1);
        fees[0] = CrossChainGas({ 
            gasLimit: 0,
            nativeCurrencyValue: uint128(gasPayment)
        });
        (bytes32 messageId,) = IGlacisRouter(GLACIS_ROUTER).route{
            value: gasPayment
        }(chainId, to, payload, adapters, fees, refundAddress, false);
        emit GlacisClient__MessageRouted(messageId, chainId, to);
        return messageId;
    }

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using
    /// specified GMPs.
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapters The adapters to use for redundant routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    function _routeRedundant(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        CrossChainGas[] memory fees,
        address refundAddress,
        uint256 gasPayment
    ) internal returns (bytes32) {
        (bytes32 messageId,) = IGlacisRouter(GLACIS_ROUTER).route{
            value: gasPayment
        }(chainId, to, payload, adapters, fees, refundAddress, false);
        emit GlacisClient__MessageRouted(messageId, chainId, to);
        return messageId;
    }

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using GMPs
    /// specified in gmps array
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapters An array of custom adapters to be used for the routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param retriable True to enable retry feature for this message
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    function _route(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        CrossChainGas[] memory fees,
        address refundAddress,
        bool retriable,
        uint256 gasPayment
    ) internal returns (bytes32,uint256) {
        (bytes32 messageId,uint256 nonce) = IGlacisRouter(GLACIS_ROUTER).route{
            value: gasPayment
        }(chainId, to, payload, adapters, fees, refundAddress, retriable);
        emit GlacisClient__MessageRouted(messageId, chainId, to);
        return (messageId,nonce);
    }

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using GMPs
    /// specified in gmps array
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapters An array of adapters to be used for the routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param messageId The message ID of the message to retry
    /// @param nonce The nonce emitted by the original sent message
    /// @param gasPayment Amount of gas to cover source and destination gas fees (excess will be refunded)
    function _retryRoute(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        CrossChainGas[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce,
        uint256 gasPayment
    ) internal returns (bytes32) {
        IGlacisRouter(GLACIS_ROUTER).routeRetry{value: gasPayment}(
            chainId,
            to,
            payload,
            adapters,
            fees,
            refundAddress,
            messageId,
            nonce
        );
        emit GlacisClient__MessageRouted(messageId, chainId, to);
        return messageId;
    }

    /// @notice Receives message from GMP(s) through GlacisRouter
    /// @param fromAdapters addresses of the adapters sent this message (that reached quorum requirements)
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param fromAddress Source address on source chain
    /// @param payload Routed payload
    function receiveMessage(
        address[] memory fromAdapters,
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes memory payload
    ) external virtual override {
        if (msg.sender != GLACIS_ROUTER)
            revert GlacisClient__CanOnlyBeCalledByRouter();
        _receiveMessage(fromAdapters, fromChainId, fromAddress, payload);
        emit GlacisClient__MessageArrived(fromAdapters, fromChainId, fromAddress);
    }

    /// @notice Receives message from GMP(s) through GlacisRouter
    /// @param fromAdapters Adapter addresses
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param fromAddress Source address on source chain
    /// @param payload Routed payload
    function _receiveMessage(
        address[] memory fromAdapters,
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes memory payload
    ) internal virtual {}
}
