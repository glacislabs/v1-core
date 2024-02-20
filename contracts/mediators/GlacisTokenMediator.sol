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

error GlacisTokenMediator__OnlyTokenMediatorAllowed();
error GlacisTokenMediator__IncorrectTokenVariant(address, uint256);
error GlacisTokenMediator__DestinationChainUnavailable();

contract GlacisTokenMediator is
    IGlacisTokenMediator,
    GlacisRemoteCounterpartManager,
    IGlacisClient
{
    constructor(
        address glacisRouter_,
        uint256 quorum,
        address owner
    ) IGlacisClient(quorum) {
        // Approve conversation between token routers in all chains through all GMPs
        GLACIS_ROUTER = glacisRouter_;
        transferOwnership(owner);
    }

    address public immutable GLACIS_ROUTER;

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using GMPs
    /// specified in gmps array
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param gmps The GMP Ids to use for routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param retriable True if this message could be retried
    /// @param token Token (implementing XERC20 standard) to be sent to remote contract
    /// @param tokenAmount Amount of token to send to remote contract
    function route(
        uint256 chainId,
        address to,
        bytes memory payload,
        uint8[] memory gmps,
        uint256[] memory fees,
        address refundAddress,
        bool retriable,
        address token,
        uint256 tokenAmount
    ) public payable virtual returns (bytes32) {
        address destinationTokenMediator = remoteCounterpart[chainId];
        if (destinationTokenMediator == address(0))
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
                gmps,
                fees,
                refundAddress,
                retriable
            );
    }

    /// @notice Retries routing the payload to the specific address on destination chain using specified GMPs
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param gmps The GMP Ids to use for routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param messageId The message ID of the message to retry
    /// @param nonce The nonce emitted by the original message routing
    /// @param token Token (implementing XERC20 standard) to be sent to remote contract
    /// @param tokenAmount Amount of token to send to remote contract
    function routeRetry(
        uint256 chainId,
        address to,
        bytes memory payload,
        uint8[] memory gmps,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce,
        address token,
        uint256 tokenAmount
    ) public payable virtual returns (bytes32) {
        address destinationTokenMediator = remoteCounterpart[chainId];
        if (destinationTokenMediator == address(0))
            revert GlacisTokenMediator__DestinationChainUnavailable();

        // Pack with a function (otherwise stack too deep)
        bytes memory tokenPayload = packTokenPayload(
            chainId,
            to,
            token,
            tokenAmount,
            payload
        );

        return
            IGlacisRouter(GLACIS_ROUTER).routeRetry{value: msg.value}(
                chainId,
                destinationTokenMediator,
                tokenPayload,
                gmps,
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
        address fromAddress,
        bytes memory payload
    ) public override {
        // Ensure that the executor is the glacis router and that the source is from an accepted mediator.
        if (msg.sender != GLACIS_ROUTER)
            revert GlacisClient__CanOnlyBeCalledByRouter();
        if (fromAddress != remoteCounterpart[fromChainId]) {
            revert GlacisTokenMediator__OnlyTokenMediatorAllowed();
        }

        (
            address to,
            address originalFrom,
            address sourceToken,
            address token,
            uint256 tokenAmount,
            bytes memory originalPayload
        ) = abi.decode(
                payload,
                (address, address, address, address, uint256, bytes)
            );

        // Ensure that the destination token accepts the source token.
        if (
            sourceToken != token &&
            sourceToken != getTokenVariant(token, fromChainId)
        ) {
            revert GlacisTokenMediator__IncorrectTokenVariant(
                sourceToken,
                fromChainId
            );
        }

        // Mint & execute
        IXERC20(token).mint(to, tokenAmount);
        emit GlacisTokenMediator__TokensMinted(to, token, tokenAmount);
        IGlacisTokenClient client = IGlacisTokenClient(to);

        if (to.code.length > 0) {
            client.receiveMessageWithTokens(
                fromGmpIds,
                fromChainId,
                originalFrom,
                originalPayload,
                token,
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
            address to,
            address originalFrom,
            ,
            address token,
            uint256 tokenAmount,
            bytes memory originalPayload
        ) = decodeTokenPayload(payload);
        glacisData.originalFrom = originalFrom;
        glacisData.originalTo = to;

        // If the destination smart contract is an EOA, then we assume "1".
        if (to.code.length == 0) {
            return 1;
        }

        return
            IGlacisTokenClient(to).getQuorum(
                glacisData,
                originalPayload,
                token,
                tokenAmount
            );
    }

    /// @notice Queries if a route from path GMP+Chain+Address is allowed for this client
    /// @param fromChainId Source chain Id
    /// @param fromAddress Source address
    /// @param fromGmpId source GMP Id
    /// @return True if route is allowed, false otherwise
    function isAllowedRoute(
        uint256 fromChainId,
        address fromAddress,
        uint8 fromGmpId,
        bytes memory payload
    ) external view returns (bool) {
        // First checks to ensure that the GlacisTokenMediator is speaking to a registered remote version
        if (fromAddress != remoteCounterpart[fromChainId]) return false;

        (
            address to,
            address originalFrom,
            ,
            ,
            ,
            bytes memory originalPayload
        ) = decodeTokenPayload(payload);

        // If the destination smart contract is an EOA, then we allow it.
        if (to.code.length == 0) {
            return true;
        }

        // Forwards check to the token client
        return
            IGlacisTokenClient(to).isAllowedRoute(
                fromChainId,
                originalFrom,
                fromGmpId,
                originalPayload
            );
    }

    function getTokenVariant(
        address token,
        uint256 chainId
    ) internal view returns (address destinationToken) {
        try IXERC20GlacisExtension(token).getTokenVariant(chainId) returns (
            address variant
        ) {
            if (variant == address(0)) destinationToken = token;
            else destinationToken = variant;
        } catch {
            destinationToken = token;
        }
    }

    function packTokenPayload(
        uint256 chainId,
        address to,
        address token,
        uint256 tokenAmount,
        bytes memory payload
    ) internal view returns (bytes memory) {
        return
            abi.encode(
                to,
                msg.sender,
                token,
                getTokenVariant(token, chainId),
                tokenAmount,
                payload
            );
    }

    function decodeTokenPayload(
        bytes memory payload
    )
        internal
        pure
        returns (
            address to,
            address originalFrom,
            address sourceToken,
            address token,
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
            (address, address, address, address, uint256, bytes)
        );
    }
}
