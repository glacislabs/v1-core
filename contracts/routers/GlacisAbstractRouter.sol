// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {IGlacisRouterEvents} from "../interfaces/IGlacisRouter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error GlacisAbstractRouter__OnlyAdaptersAllowed(); //0x55ff424d
error GlacisAbstractRouter__InvalidAdapterAddress(); //0xa46f71e2
error GlacisAbstractRouter__GMPIDCannotBeZero(); //0x4332f55b

abstract contract GlacisAbstractRouter is
    GlacisCommons,
    IGlacisRouterEvents,
    Ownable
{
    uint256 internal immutable GLACIS_CHAIN_ID;

    mapping(uint8 => address) public glacisGMPIdToAdapter;
    mapping(address => uint8) public adapterToGlacisGMPId;
    uint256 private nonce;

    constructor(uint256 chainID) {
        // @dev Must store chain ID due to possibility of hard fork
        GLACIS_CHAIN_ID = chainID;
    }

    /// @notice Registers a GMP adapter
    /// @param glacisGMPId_ The Glacis ID of the GMP
    /// @param glacisAdapter The address of the deployed adapter
    function registerAdapter(
        uint8 glacisGMPId_,
        address glacisAdapter
    ) external virtual onlyOwner {
        if (glacisAdapter == address(0))
            revert GlacisAbstractRouter__InvalidAdapterAddress();
        if (glacisGMPId_ == 0) revert GlacisAbstractRouter__GMPIDCannotBeZero();

        // Unregister previous adapter
        delete glacisGMPIdToAdapter[glacisGMPId_];
        delete adapterToGlacisGMPId[glacisGMPIdToAdapter[glacisGMPId_]];

        // Adds new adapter
        glacisGMPIdToAdapter[glacisGMPId_] = glacisAdapter;
        adapterToGlacisGMPId[glacisAdapter] = glacisGMPId_;
    }

    /// @notice Unregisters a GMP adapter
    /// @param glacisGMPId_ The Glacis ID of the GMP
    /// @param glacisAdapter The address of the deployed adapter
    function unRegisterAdapter(
        uint8 glacisGMPId_,
        address glacisAdapter
    ) external virtual onlyOwner {
        if (glacisAdapter == address(0))
            revert GlacisAbstractRouter__InvalidAdapterAddress();
        if (glacisGMPId_ == 0) revert GlacisAbstractRouter__GMPIDCannotBeZero();
        delete glacisGMPIdToAdapter[glacisGMPId_];
        delete adapterToGlacisGMPId[glacisAdapter];
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
        address to,
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
            msg.sender,
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
        address to,
        uint256 messageNonce,
        bytes memory payload
    ) public view returns (bool) {
        return
            _validateGlacisMessageId(
                messageId,
                toChainId,
                fromChainId,
                to,
                msg.sender,
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
        address to,
        address messageSender,
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

    /// @notice Verifies that the sender address is one of the adapters
    modifier onlyAdapter() {
        if (adapterToGlacisGMPId[msg.sender] == 0)
            revert GlacisAbstractRouter__OnlyAdaptersAllowed();
        _;
    }
}
