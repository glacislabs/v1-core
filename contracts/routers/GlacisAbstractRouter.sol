// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {IGlacisRouterEvents} from "../interfaces/IGlacisRouter.sol";
import {AddressBytes32} from "../libraries/AddressBytes32.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

error GlacisAbstractRouter__InvalidAdapterAddress(); //0xa46f71e2
error GlacisAbstractRouter__GMPIDCannotBeZero(); //0x4332f55b
error GlacisAbstractRouter__GMPIDTooHigh();

/// @title Glacis Abstract Router
/// @notice A base class for the GlacisRouter
abstract contract GlacisAbstractRouter is
    GlacisCommons,
    IGlacisRouterEvents,
    Ownable2Step
{
    using AddressBytes32 for address;

    uint256 internal immutable GLACIS_CHAIN_ID;

    mapping(uint8 => address) public glacisGMPIdToAdapter;
    mapping(address => uint8) public adapterToGlacisGMPId;
    uint256 private nonce;

    /// @param chainID The chain ID that will be injected in messages
    constructor(uint256 chainID) {
        // @dev Must store chain ID due to possibility of hard fork
        GLACIS_CHAIN_ID = chainID;
    }

    /// @notice Registers a GMP adapter
    /// @param glacisGMPId The Glacis ID of the GMP
    /// @param glacisAdapter The address of the deployed adapter
    function registerAdapter(
        uint8 glacisGMPId,
        address glacisAdapter
    ) external virtual onlyOwner {
        if (glacisAdapter == address(0))
            revert GlacisAbstractRouter__InvalidAdapterAddress();
        if (glacisGMPId == 0) revert GlacisAbstractRouter__GMPIDCannotBeZero();
        if (glacisGMPId > GlacisCommons.GLACIS_RESERVED_IDS) revert GlacisAbstractRouter__GMPIDTooHigh();

        // Unregister previous adapter
        delete adapterToGlacisGMPId[glacisGMPIdToAdapter[glacisGMPId]];
        delete glacisGMPIdToAdapter[glacisGMPId];

        // Adds new adapter
        glacisGMPIdToAdapter[glacisGMPId] = glacisAdapter;
        adapterToGlacisGMPId[glacisAdapter] = glacisGMPId;
    }

    /// @notice Unregisters a GMP adapter
    /// @param glacisGMPId The Glacis ID of the GMP
    function unRegisterAdapter(
        uint8 glacisGMPId
    ) external virtual onlyOwner {
        address adapter = glacisGMPIdToAdapter[glacisGMPId];
        if (adapter == address(0))
            revert GlacisAbstractRouter__InvalidAdapterAddress();
        if (glacisGMPId == 0) revert GlacisAbstractRouter__GMPIDCannotBeZero();
        
        delete glacisGMPIdToAdapter[glacisGMPId];
        delete adapterToGlacisGMPId[adapter];
    }

    /// @notice Creates a messageId
    /// @dev this Id is used to Identify identical messages on the destination chain and to verify that a retry message
    ///  has identical data
    /// @param toChainId The destination chain of the message
    /// @param to The destination address of the message
    /// @param payload The payload of the message
    /// @return messageId , messageNonce : The message Id and the message nonce, this two parameters will be required
    /// if implementing message retrying
    function _createGlacisMessageId(
        uint256 toChainId,
        bytes32 to,
        bytes memory payload
    ) internal returns (bytes32 messageId, uint256 messageNonce) {
        messageNonce = nonce++;
        messageId = keccak256(
            abi.encode(
                toChainId,
                GLACIS_CHAIN_ID,
                to,
                keccak256(payload),
                msg.sender,
                messageNonce
            )
        );
        emit GlacisAbstractRouter__MessageIdCreated(
            messageId,
            msg.sender.toBytes32(),
            messageNonce
        );
    }

    /// @notice Validates a message Id
    /// @param messageId The Message Id of the message
    /// @param toChainId The destination chain of the message
    /// @param fromChainId The source chain of the message
    /// @param to The destination address of the message
    /// @param messageNonce The nonce of the message
    /// @param payload The payload of the message
    /// @return true if the message Id is valid, false otherwise
    function validateGlacisMessageId(
        bytes32 messageId,
        uint256 toChainId,
        uint256 fromChainId,
        bytes32 to,
        uint256 messageNonce,
        bytes memory payload
    ) public view returns (bool) {
        return
            _validateGlacisMessageId(
                messageId,
                toChainId,
                fromChainId,
                to,
                msg.sender.toBytes32(),
                messageNonce,
                payload
            );
    }

    /// @notice Validates a message Id
    /// @param messageId The Message Id of the message
    /// @param toChainId The destination chain of the message
    /// @param fromChainId The source chain of the message
    /// @param to The destination address of the message
    /// @param messageSender The sender of the message
    /// @param messageNonce The nonce of the message
    /// @param payload The payload of the message
    /// @return true if the message Id is valid, false otherwise
    function _validateGlacisMessageId(
        bytes32 messageId,
        uint256 toChainId,
        uint256 fromChainId,
        bytes32 to,
        bytes32 messageSender,
        uint256 messageNonce,
        bytes memory payload
    ) internal pure returns (bool) {
        bytes32 id = keccak256(
            abi.encode(
                toChainId,
                fromChainId,
                to,
                keccak256(payload),
                messageSender,
                messageNonce
            )
        );

        return id == messageId;
    }
}
