// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {IGlacisTokenClient} from "../interfaces/IGlacisTokenClient.sol";
import {IGlacisRouter} from "../interfaces/IGlacisRouter.sol";
import {IGlacisTokenMediator} from "../interfaces/IGlacisTokenMediator.sol";
import {IGlacisClient} from "../interfaces/IGlacisClient.sol";
import {IXERC20, IXERC20GlacisExtension} from "../interfaces/IXERC20.sol";
import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {GlacisRemoteCounterpartManager} from "../managers/GlacisRemoteCounterpartManager.sol";
import {GlacisClient__CanOnlyBeCalledByRouter} from "../client/GlacisClient.sol";
import {AddressBytes32} from "../libraries/AddressBytes32.sol";

error GlacisTokenMediator__OnlyTokenMediatorAllowed();
error GlacisTokenMediator__IncorrectTokenVariant(bytes32, uint256);
error GlacisTokenMediator__DestinationChainUnavailable();

/// @title Glacis Token Mediator
/// @notice A middleware contract that formats Glacis messages to include XERC20 support
contract GlacisTokenMediator is
    IGlacisTokenMediator,
    GlacisRemoteCounterpartManager,
    IGlacisClient
{
    using AddressBytes32 for address;
    using AddressBytes32 for bytes32;

    /// @param _glacisRouter This chain's deployment of the GlacisRouter  
    /// @param _quorum The default quorum that you would like. If you implement dynamic quorum, this value can be ignored and 
    /// set to 0  
    /// @param _owner The owner of this contract
    constructor(
        address _glacisRouter,
        uint256 _quorum,
        address _owner
    ) IGlacisClient(_quorum) {
        // Approve conversation between token routers in all chains through all GMPs
        GLACIS_ROUTER = _glacisRouter;
        transferOwnership(_owner);
    }

    address public immutable GLACIS_ROUTER;

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
    function route(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        uint256[] memory fees,
        address refundAddress,
        address token,
        uint256 tokenAmount
    ) public payable virtual returns (bytes32, uint256) {
        bytes32 destinationTokenMediator = remoteCounterpart[chainId];
        if (destinationTokenMediator == bytes32(0))
            revert GlacisTokenMediator__DestinationChainUnavailable();

        IXERC20(token).burn(msg.sender, tokenAmount);
        bytes memory tokenPayload = packTokenPayload(
            chainId,
            to,
            token,
            tokenAmount,
            payload
        );
        emit GlacisTokenMediator__TokensBurnt(msg.sender, token, tokenAmount);
        return
            IGlacisRouter(GLACIS_ROUTER).route{value: msg.value}(
                chainId,
                destinationTokenMediator,
                tokenPayload,
                adapters,
                fees,
                refundAddress,
                true // Token Mediator always enables retry
            );
    }

    /// @notice Retries routing the payload to the specific address on destination chain using specified GMPs
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapters An array of adapters to be used for the routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param messageId The message ID of the message to retry
    /// @param nonce The nonce emitted by the original message routing
    /// @param token Token (implementing XERC20 standard) to be sent to remote contract
    /// @param tokenAmount Amount of token to send to remote contract
    function routeRetry(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce,
        address token,
        uint256 tokenAmount
    ) public payable virtual returns (bytes32) {
        // Pack with a function (otherwise stack too deep)
        bytes memory tokenPayload = packTokenPayload(
            chainId,
            to,
            token,
            tokenAmount,
            payload
        );

        // Use helper function (otherwise stack too deep)
        return _routeRetry(
            chainId,
            tokenPayload,
            adapters,
            fees,
            refundAddress,
            messageId,
            nonce
        );
    }

    /// @notice An internal routing function that helps with stack too deep
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param tokenPayload Formatted payload to be routed
    /// @param adapters An array of custom adapters to be used for the routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param messageId The message ID of the message to retry
    /// @param nonce The nonce emitted by the original message routing
    function _routeRetry(
        uint256 chainId,
        bytes memory tokenPayload,
        address[] memory adapters,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce
    ) private returns(bytes32) {
        bytes32 destinationTokenMediator = remoteCounterpart[chainId];
        if (destinationTokenMediator == bytes32(0))
            revert GlacisTokenMediator__DestinationChainUnavailable();

        return
            IGlacisRouter(GLACIS_ROUTER).routeRetry{value: msg.value}(
                chainId,
                destinationTokenMediator,
                tokenPayload,
                adapters,
                fees,
                refundAddress,
                messageId,
                nonce
            );
    }

    /// @notice Receives a cross chain message from an IGlacisAdapter.
    /// @param fromGmpIds Used GMP Ids for routing
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param fromChainId Source address
    /// @param payload Received payload from Glacis Router
    function receiveMessage(
        uint8[] memory fromGmpIds,
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes memory payload
    ) public override {
        // Ensure that the executor is the glacis router and that the source is from an accepted mediator.
        if (msg.sender != GLACIS_ROUTER)
            revert GlacisClient__CanOnlyBeCalledByRouter();
        if (fromAddress != remoteCounterpart[fromChainId]) {
            revert GlacisTokenMediator__OnlyTokenMediatorAllowed();
        }

        (
            bytes32 to,
            bytes32 originalFrom,
            bytes32 sourceToken,
            bytes32 token,
            uint256 tokenAmount,
            bytes memory originalPayload
        ) = abi.decode(
                payload,
                (bytes32, bytes32, bytes32, bytes32, uint256, bytes)
            );

        // Ensure that the destination token accepts the source token.
        if (
            sourceToken != token &&
            sourceToken != getTokenVariant(token.toAddress(), fromChainId)
        ) {
            revert GlacisTokenMediator__IncorrectTokenVariant(
                sourceToken,
                fromChainId
            );
        }

        // Mint & execute
        address toAddress = to.toAddress();
        IXERC20(token.toAddress()).mint(toAddress, tokenAmount);
        emit GlacisTokenMediator__TokensMinted(toAddress, token.toAddress(), tokenAmount);
        IGlacisTokenClient client = IGlacisTokenClient(toAddress);

        if (toAddress.code.length > 0) {
            client.receiveMessageWithTokens(
                fromGmpIds,
                fromChainId,
                originalFrom,
                originalPayload,
                token.toAddress(),
                tokenAmount
            );
        }
    }

    /// @notice The quorum of messages that the contract expects with a specific message from the
    ///         token router
    /// @param glacisData The glacis config data that comes with the message
    /// @param payload The payload that comes with the message
    function getQuorum(
        GlacisCommons.GlacisData memory glacisData,
        bytes memory payload
    ) public view override returns (uint256) {
        (
            bytes32 to,
            bytes32 originalFrom,
            ,
            bytes32 token,
            uint256 tokenAmount,
            bytes memory originalPayload
        ) = decodeTokenPayload(payload);
        glacisData.originalFrom = originalFrom;
        glacisData.originalTo = to;

        // If the destination smart contract is an EOA, then we assume "1".
        address toAddress = to.toAddress();
        if (toAddress.code.length == 0) {
            return 1;
        }

        return
            IGlacisTokenClient(toAddress).getQuorum(
                glacisData,
                originalPayload,
                token.toAddress(),
                tokenAmount
            );
    }

    /// @notice Queries if a route from path GMP+Chain+Address is allowed for this client
    /// @param fromChainId Source chain Id
    /// @param fromAddress Source address
    /// @param fromAdapter source GMP Id
    /// @return True if route is allowed, false otherwise
    function isAllowedRoute(
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes32 fromAdapter,
        bytes memory payload
    ) external view returns (bool) {
        // First checks to ensure that the GlacisTokenMediator is speaking to a registered remote version
        if (fromAddress != remoteCounterpart[fromChainId]) return false;

        (
            bytes32 to,
            bytes32 originalFrom,
            ,
            ,
            ,
            bytes memory originalPayload
        ) = decodeTokenPayload(payload);

        // If the destination smart contract is an EOA, then we allow it.
        address toAddress = to.toAddress();
        if (toAddress.code.length == 0) {
            return true;
        }

        // Forwards check to the token client
        return
            IGlacisTokenClient(toAddress).isAllowedRoute(
                fromChainId,
                originalFrom,
                fromAdapter,
                originalPayload
            );
    }

    /// @notice Determines if a token from a chain ID is a token variant for this chain's token
    /// @param token The address of the token in question  
    /// @param chainId The chain ID that the token in question is deployed
    function getTokenVariant(
        address token,
        uint256 chainId
    ) internal view returns (bytes32 destinationToken) {
        try IXERC20GlacisExtension(token).getTokenVariant(chainId) returns (
            bytes32 variant
        ) {
            if (variant == bytes32(0)) destinationToken = token.toBytes32();
            else destinationToken = variant;
        } catch {
            destinationToken = token.toBytes32();
        }
    }

    /// @notice Packs a token payload (helps with stack too deep)
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param token Token (implementing XERC20 standard) to be sent to remote contract
    /// @param tokenAmount Amount of token to send to remote contract
    /// @param payload Payload to be routed
    function packTokenPayload(
        uint256 chainId,
        bytes32 to,
        address token,
        uint256 tokenAmount,
        bytes memory payload
    ) internal view returns (bytes memory) {
        return
            abi.encode(
                to,
                msg.sender.toBytes32(),
                token.toBytes32(),
                getTokenVariant(token, chainId),
                tokenAmount,
                payload
            );
    }

    /// @notice Decodes a received token payload 
    /// @param payload The payload
    function decodeTokenPayload(
        bytes memory payload
    )
        internal
        pure
        returns (
            bytes32 to,
            bytes32 originalFrom,
            bytes32 sourceToken,
            bytes32 token,
            uint256 tokenAmount,
            bytes memory originalPayload
        )
    {
        (
            to,
            originalFrom,
            sourceToken,
            token,
            tokenAmount,
            originalPayload
        ) = abi.decode(
            payload,
            (bytes32, bytes32, bytes32, bytes32, uint256, bytes)
        );
    }
}
