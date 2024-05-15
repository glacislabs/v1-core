// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {IGlacisRouter} from "../interfaces/IGlacisRouter.sol";
import {GlacisClientOwnable} from "../client/GlacisClientOwnable.sol";
import {IXERC20} from "../interfaces/IXERC20.sol";
import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {GlacisRemoteCounterpartManager} from "../managers/GlacisRemoteCounterpartManager.sol";
import {AddressBytes32} from "../libraries/AddressBytes32.sol";

error SimpleTokenMediator__OnlyTokenMediatorAllowed();
error SimpleTokenMediator__IncorrectTokenVariant(address, uint256);
error SimpleTokenMediator__DestinationChainUnavailable();
error SimpleTokenMediator__TokenMapInitializationIncorrect();

/// @title Simple Token Mediator
/// @notice This contract burns and mints XERC-20 tokens without additional 
/// features. There is no additional Glacis XERC-20 interface, tokens cannot
/// be sent with a payload, and there is no special interface for a client to
/// inherit from.  
/// The `route` function has been replaced with a `sendCrossChain` 
/// function to differentiate it from the routing with payload that the 
/// GlacisTokenMediator has. Similarly, the retry function has been replaced
/// with a `sendCrossChainRetry`.  
/// Developers using this must ensure that their token has the same address on 
/// each chain. 
contract SimpleTokenMediator is
    GlacisRemoteCounterpartManager,
    GlacisClientOwnable
{
    using AddressBytes32 for address;
    using AddressBytes32 for bytes32;

    event SimpleTokenMediator__TokensMinted(address, address, uint256);
    event SimpleTokenMediator__TokensBurnt(address, address, uint256);

    constructor(
        address _glacisRouter,
        uint256 _quorum,
        address _owner
    ) GlacisClientOwnable(_glacisRouter, _quorum, _owner) { }

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
    /// @param adapters The GMP Adapters to use for routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param tokenAmount Amount of token to send to remote contract
    function sendCrossChain(
        uint256 chainId,
        bytes32 to,
        address[] memory adapters,
        uint256[] memory fees,
        address refundAddress,
        uint256 tokenAmount
    ) public payable virtual returns (bytes32, uint256) {
        bytes32 destinationTokenMediator = remoteCounterpart[chainId];
        if (destinationTokenMediator == bytes32(0))
            revert SimpleTokenMediator__DestinationChainUnavailable();

        IXERC20(xERC20Token).burn(msg.sender, tokenAmount);
        bytes memory tokenPayload = packTokenPayload(to, tokenAmount);
        emit SimpleTokenMediator__TokensBurnt(msg.sender, xERC20Token, tokenAmount);
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
    /// @param adapters The GMP Adapters to use for routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    /// @param messageId The message ID of the message to retry
    /// @param nonce The nonce emitted by the original message routing
    /// @param tokenAmount Amount of token to send to remote contract
    function sendCrossChainRetry(
        uint256 chainId,
        bytes32 to,
        address[] memory adapters,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce,
        uint256 tokenAmount
    ) public payable virtual returns (bytes32) {
        // Pack with a function
        bytes memory tokenPayload = packTokenPayload(to, tokenAmount);

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
            revert SimpleTokenMediator__DestinationChainUnavailable();

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
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param fromChainId Source address
    /// @param payload Received payload from Glacis Router
    function _receiveMessage(
        address[] memory,   // fromAdapters
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes memory payload
    ) internal override {
        // Ensure that the executor is the glacis router and that the source is from an accepted mediator.
        if (fromAddress != remoteCounterpart[fromChainId]) {
            revert SimpleTokenMediator__OnlyTokenMediatorAllowed();
        }

        (bytes32 to, uint256 tokenAmount) = decodeTokenPayload(payload);

        // Mint
        address toAddress = to.toAddress();
        IXERC20(xERC20Token).mint(toAddress, tokenAmount);
        emit SimpleTokenMediator__TokensMinted(toAddress, xERC20Token, tokenAmount);
    }

    function packTokenPayload(
        bytes32 to,
        uint256 tokenAmount
    ) internal pure returns (bytes memory) {
        return abi.encode(to, tokenAmount);
    }

    function decodeTokenPayload(
        bytes memory payload
    ) internal pure returns (bytes32 to, uint256 tokenAmount) {
        (
            to,
            tokenAmount
        ) = abi.decode(payload, (bytes32, uint256));
    }
}
