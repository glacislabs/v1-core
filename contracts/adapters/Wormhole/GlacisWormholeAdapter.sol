// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IWormholeRelayer} from "./IWormholeRelayer.sol";
import {IWormholeReceiver} from "./IWormholeReceiver.sol";
import {GlacisAbstractAdapter} from "../GlacisAbstractAdapter.sol";
import {IGlacisRouter} from "../../routers/GlacisRouter.sol";
import {GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__SourceChainNotRegistered} from "../GlacisAbstractAdapter.sol";

error GlacisWormholeAdapter__OnlyRelayerAllowed();
error GlacisWormholeAdapter__AlreadyProcessedVAA();
error GlacisWormholeAdapter__NotEnoughValueForCrossChainTransaction();
error GlacisWormholeAdapter__RefundAddressMustReceiveNativeCurrency();

/// @title Glacis Adapter for Wormhole GMP
/// @notice This adapter receives GlacisRouter requests through the _sendMessage function and forwards them to
/// Wormhole. Also receives Wormhole requests through the receiveWormholeMessages function and routes
/// them to GlacisRouter
contract GlacisWormholeAdapter is IWormholeReceiver, GlacisAbstractAdapter {
    IWormholeRelayer public immutable WORMHOLE_RELAYER;
    mapping(bytes32 => bool) public seenDeliveryVaaHashes;

    mapping(uint256 => uint16) public glacisChainIdToAdapterChainId;
    mapping(uint16 => uint256) public adapterChainIdToGlacisChainId;

    uint256 internal constant GAS_LIMIT = 900000;
    uint16 internal immutable WORMHOLE_CHAIN_ID;

    uint256 internal constant RECEIVER_VALUE = 0;

    constructor(
        IGlacisRouter _glacisRouter,
        address _wormholeRelayer,
        uint16 wormholeChainId,
        address owner_
    ) GlacisAbstractAdapter(_glacisRouter, owner_) {
        WORMHOLE_RELAYER = IWormholeRelayer(_wormholeRelayer);
        WORMHOLE_CHAIN_ID = wormholeChainId;
    }

    /// @notice Dispatch payload to specified Glacis chain ID and address through Wormhole GMP
    /// @param toChainId Destination chain (Glacis ID)
    /// @param refundAddress The address to refund native asset surplus
    /// @param payload Payload to send
    function _sendMessage(
        uint256 toChainId,
        address refundAddress,
        bytes memory payload
    ) internal override {
        uint16 destinationChainId = glacisChainIdToAdapterChainId[toChainId];
        (uint256 nativePriceQuote, ) = WORMHOLE_RELAYER.quoteEVMDeliveryPrice(
            destinationChainId,
            RECEIVER_VALUE,
            GAS_LIMIT
        );

        if (nativePriceQuote > msg.value)
            revert GlacisWormholeAdapter__NotEnoughValueForCrossChainTransaction();

        WORMHOLE_RELAYER.sendPayloadToEvm{value: nativePriceQuote}(
            destinationChainId,
            address(this),
            payload,
            RECEIVER_VALUE,
            GAS_LIMIT,
            WORMHOLE_CHAIN_ID,
            refundAddress
        );

        if (msg.value > nativePriceQuote) {
            (bool successful, ) = address(refundAddress).call{
                value: msg.value - nativePriceQuote
            }("");
            if (!successful)
                revert GlacisWormholeAdapter__RefundAddressMustReceiveNativeCurrency();
        }
    }

    /// @notice Receives route message from Wormhole and routes it to GlacisRouter
    /// @param payload Payload to route
    /// @param sourceAddress Source address on remote chain
    /// @param sourceChain Source chain (Wormhole ID)
    /// @param deliveryHash Wormhole delivery hash
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    )
        external
        payable
        onlyAuthorizedAdapter(
            adapterChainIdToGlacisChainId[sourceChain],
            address(uint160(bytes20(sourceAddress << 96)))
        )
    {
        if (msg.sender != address(WORMHOLE_RELAYER))
            revert GlacisWormholeAdapter__OnlyRelayerAllowed();
        if (seenDeliveryVaaHashes[deliveryHash])
            revert GlacisWormholeAdapter__AlreadyProcessedVAA();

        uint256 sourceChainGlacisId = adapterChainIdToGlacisChainId[
            sourceChain
        ];
        if (sourceChainGlacisId == 0)
            revert GlacisAbstractAdapter__SourceChainNotRegistered();

        // Ensure no duplicate deliveries
        seenDeliveryVaaHashes[deliveryHash] = true;

        // Forward to the router
        GLACIS_ROUTER.receiveMessage(sourceChainGlacisId, payload);
    }

    /// @notice Sets the corresponding Wormhole chain label for the specified Glacis chain ID
    /// @param glacisIDs Glacis chain IDs
    /// @param whIDs Wormhole corresponding chain IDs
    function setGlacisChainIds(
        uint256[] memory glacisIDs,
        uint16[] memory whIDs
    ) external onlyOwner {
        uint256 len = glacisIDs.length;
        if (len != whIDs.length)
            revert GlacisAbstractAdapter__IDArraysMustBeSameLength();
        for (uint256 i; i < len; ) {
            uint256 gID = glacisIDs[i];
            uint16 whID = whIDs[i];
            if (gID == 0)
                revert GlacisAbstractAdapter__DestinationChainIdNotValid();
            glacisChainIdToAdapterChainId[gID] = whID;
            adapterChainIdToGlacisChainId[whID] = gID;

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Gets the corresponding Axelar chain label for the specified Glacis chain ID
    /// @param chainId Glacis chain ID
    /// @return The corresponding Axelar label
    function adapterChainID(uint256 chainId) external view returns (uint16) {
        return glacisChainIdToAdapterChainId[chainId];
    }

    /// @notice Queries if the specified Glacis chain ID is supported by this adapter
    /// @param chainId Glacis chain ID
    /// @return True if chain is supported, false otherwise
    function chainIsAvailable(uint256 chainId) public view returns (bool) {
        return glacisChainIdToAdapterChainId[chainId] != 0;
    }

    /// @notice Adds a remote adapter on a destination chain where this adapter can route messages
    /// @param chainId The chainId to add the remote adapter
    /// @param adapter The address of the adapter on remote chain
    function addRemoteAdapter(uint256 chainId, address adapter) external {
        if (!chainIsAvailable(chainId))
            revert GlacisAbstractAdapter__DestinationChainIdNotValid();
        _addRemoteAdapter(chainId, adapter);
    }

    /// @notice Removes an authorized adapter on remote chain that this adapter accepts messages from
    /// @param chainId The chainId to remove the remote adapter
    function removeRemoteAdapter(uint256 chainId) external {
        _removeRemoteAdapter(chainId);
    }
}
