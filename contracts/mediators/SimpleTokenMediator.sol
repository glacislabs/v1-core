// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {IGlacisTokenClient} from "../interfaces/IGlacisTokenClient.sol";
import {IGlacisRouter} from "../interfaces/IGlacisRouter.sol";
import {IGlacisClient} from "../interfaces/IGlacisClient.sol";
import {IXERC20} from "../interfaces/IXERC20.sol";
import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {GlacisRemoteCounterpartManager} from "../managers/GlacisRemoteCounterpartManager.sol";
import {GlacisClient__CanOnlyBeCalledByRouter} from "../client/GlacisClient.sol";
import {AddressBytes32} from "../libraries/AddressBytes32.sol";

error SimpleTokenMediator__OnlyTokenMediatorAllowed();
error SimpleTokenMediator__IncorrectTokenVariant(address, uint256);
error SimpleTokenMediator__DestinationChainUnavailable();
error SimpleTokenMediator__TokenMapInitializationIncorrect();

/// This contract is initialized in the same way that the SimpleTokenMediator is. It allows
/// developers to deploy their own mediator without any extra Glacis interfaces. Developers
/// using this must ensure that their token has the same address on each chain.
contract SimpleTokenMediator is
    GlacisRemoteCounterpartManager,
    IGlacisClient
{
    using AddressBytes32 for address;
    using AddressBytes32 for bytes32;

    event SimpleTokenMediator__TokensMinted(address, address, uint256);
    event SimpleTokenMediator__TokensBurnt(address, address, uint256);

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

    address public xERC20Token;

    /// @notice Allows the owner to set the single xERC20 that this mediator sends
    /// @param _xERC20Token The address of the token that this mediator sends
    function setXERC20(address _xERC20Token) public onlyOwner {
        xERC20Token = _xERC20Token;
    }

    /// @notice Routes the payload to the specific address on destination chain through GlacisRouter using GMPs
    /// specified in gmps array
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param gmps The GMP Ids to use for routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param tokenAmount Amount of token to send to remote contract
    function route(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        uint8[] memory gmps,
        address[] memory customAdapters,
        uint256[] memory fees,
        address refundAddress,
        uint256 tokenAmount
    ) public payable virtual returns (bytes32, uint256) {
        bytes32 destinationTokenMediator = remoteCounterpart[chainId];
        if (destinationTokenMediator == bytes32(0))
            revert SimpleTokenMediator__DestinationChainUnavailable();

        IXERC20(xERC20Token).burn(msg.sender, tokenAmount);
        bytes memory tokenPayload = packTokenPayload(
            to,
            tokenAmount,
            payload
        );
        emit SimpleTokenMediator__TokensBurnt(msg.sender, xERC20Token, tokenAmount);
        return
            IGlacisRouter(GLACIS_ROUTER).route{value: msg.value}(
                chainId,
                destinationTokenMediator,
                tokenPayload,
                gmps,
                customAdapters,
                fees,
                refundAddress,
                true // Token Mediator always enables retry
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
    /// @param tokenAmount Amount of token to send to remote contract
    function routeRetry(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        uint8[] memory gmps,
        address[] memory customAdapters,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce,
        uint256 tokenAmount
    ) public payable virtual returns (bytes32) {
        // Pack with a function (otherwise stack too deep)
        bytes memory tokenPayload = packTokenPayload(
            to,
            tokenAmount,
            payload
        );

        // Use helper function (otherwise stack too deep)
        return _routeRetry(
            chainId,
            tokenPayload,
            gmps,
            customAdapters,
            fees,
            refundAddress,
            messageId,
            nonce
        );
    }

    function _routeRetry(
        uint256 chainId,
        bytes memory tokenPayload,
        uint8[] memory gmps,
        address[] memory customAdapters,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce
    ) private returns(bytes32) {
        bytes32 destinationTokenMediator = remoteCounterpart[chainId];
        if (destinationTokenMediator == bytes32(0))
            revert SimpleTokenMediator__DestinationChainUnavailable();

        return
            IGlacisRouter(GLACIS_ROUTER).routeRetry{value: msg.value}(
                chainId,
                destinationTokenMediator,
                tokenPayload,
                gmps,
                customAdapters,
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
            revert SimpleTokenMediator__OnlyTokenMediatorAllowed();
        }

        (
            bytes32 to,
            bytes32 originalFrom,
            address sourceToken,
            address token,
            uint256 tokenAmount,
            bytes memory originalPayload
        ) = abi.decode(
                payload,
                (bytes32, bytes32, address, address, uint256, bytes)
            );

        // Ensure that the destination token accepts the source token.
        if (sourceToken != token) {
            revert SimpleTokenMediator__IncorrectTokenVariant(
                sourceToken,
                fromChainId
            );
        }

        // Mint & execute
        address toAddress = to.toAddress();
        IXERC20(token).mint(toAddress, tokenAmount);
        emit SimpleTokenMediator__TokensMinted(toAddress, token, tokenAmount);
        IGlacisTokenClient client = IGlacisTokenClient(toAddress);

        if (toAddress.code.length > 0) {
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
            bytes32 to,
            bytes32 originalFrom,
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
                xERC20Token,
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
        bytes32 fromAddress,
        uint160 fromGmpId,
        bytes memory payload
    ) external view returns (bool) {
        // First checks to ensure that the SimpleTokenMediator is speaking to a registered remote version
        if (fromAddress != remoteCounterpart[fromChainId]) return false;

        (
            bytes32 to,
            bytes32 originalFrom,
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
                fromGmpId,
                originalPayload
            );
    }

    function isCustomAdapter(
        address adapter,
        GlacisCommons.GlacisData memory glacisData,
        bytes memory payload
    ) public override returns (bool) {
        (
            bytes32 to,
            ,
            uint256 tokenAmount,

        ) = decodeTokenPayload(payload);

        // If the destination smart contract is an EOA, then it is not.
        address toAddress = to.toAddress();
        if (toAddress.code.length == 0) {
            return false;
        }

        // Forwards check to the token client
        return
            IGlacisTokenClient(toAddress).isCustomAdapter(
                adapter,
                glacisData,
                payload,
                xERC20Token,
                tokenAmount
            );
    }

    function packTokenPayload(
        bytes32 to,
        uint256 tokenAmount,
        bytes memory payload
    ) internal view returns (bytes memory) {
        return
            abi.encode(
                to,
                msg.sender.toBytes32(),
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
            bytes32 to,
            bytes32 originalFrom,
            uint256 tokenAmount,
            bytes memory originalPayload
        )
    {
        (
            to,
            originalFrom,
            tokenAmount,
            originalPayload
        ) = abi.decode(
            payload,
            (bytes32, bytes32, uint256, bytes)
        );
    }
}
