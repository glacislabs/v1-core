// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {IWormholeRelayer} from "./IWormholeRelayer.sol";
import {IWormholeReceiver} from "./IWormholeReceiver.sol";
import {GlacisAbstractAdapter} from "../GlacisAbstractAdapter.sol";
import {IGlacisRouter} from "../../routers/GlacisRouter.sol";
import {GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__SourceChainNotRegistered, GlacisAbstractAdapter__ChainIsNotAvailable, GlacisAbstractAdapter__NoRemoteAdapterForChainId} from "../GlacisAbstractAdapter.sol";
import {AddressBytes32} from "../../libraries/AddressBytes32.sol";
import {GlacisCommons} from "../../commons/GlacisCommons.sol";

error GlacisWormholeAdapter__OnlyRelayerAllowed();
error GlacisWormholeAdapter__AlreadyProcessedVAA();
error GlacisWormholeAdapter__NotEnoughValueForCrossChainTransaction();
error GlacisWormholeAdapter__RefundAddressMustReceiveNativeCurrency();

/// @title Glacis Adapter for Wormhole
/// @notice A Glacis Adapter for the Wormhole network. Sends messages through the Wormhole Relayer's
/// sendPayloadToEvm() and receives messages via receiveWormholeMessages()
contract GlacisWormholeAdapter is IWormholeReceiver, GlacisAbstractAdapter {
    using AddressBytes32 for bytes32;

    IWormholeRelayer public immutable WORMHOLE_RELAYER;
    mapping(bytes32 => bool) public seenDeliveryVaaHashes;

    mapping(uint256 => uint16) public glacisChainIdToAdapterChainId;
    mapping(uint16 => uint256) public adapterChainIdToGlacisChainId;

    uint256 internal constant GAS_LIMIT = 900000;
    uint16 internal immutable WORMHOLE_CHAIN_ID;
    uint256 internal constant RECEIVER_VALUE = 0;

    event GlacisWormholeAdapter__SetGlacisChainIDs(uint256[] chainIDs, uint16[] whIDs);

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
        GlacisCommons.CrossChainGas memory incentives,
        bytes memory payload
    ) internal override {
        uint16 _dstchainId = glacisChainIdToAdapterChainId[toChainId];
        bytes32 counterpart = remoteCounterpart[toChainId];

        if (_dstchainId == 0)
            revert GlacisAbstractAdapter__ChainIsNotAvailable(toChainId);
        if (counterpart == bytes32(0))
            revert GlacisAbstractAdapter__NoRemoteAdapterForChainId(toChainId);

        uint256 selectedGasLimit = incentives.gasLimit > 0
            ? incentives.gasLimit
            : GAS_LIMIT;
        (uint256 nativePriceQuote, ) = WORMHOLE_RELAYER.quoteEVMDeliveryPrice(
            _dstchainId,
            RECEIVER_VALUE,
            selectedGasLimit
        );

        if (nativePriceQuote > msg.value)
            revert GlacisWormholeAdapter__NotEnoughValueForCrossChainTransaction();

        // Will use the given gas limit, otherwise it will automatically set the
        // gas limit to 900k (not recommended)
        WORMHOLE_RELAYER.sendPayloadToEvm{value: nativePriceQuote}(
            _dstchainId,
            counterpart.toAddress(),
            payload,
            RECEIVER_VALUE,
            selectedGasLimit,
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
        bytes[] memory, // Not using additional VAAs
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    )
        external
        payable
        onlyAuthorizedAdapter(
            adapterChainIdToGlacisChainId[sourceChain],
            sourceAddress
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
    /// @param chainIDs Glacis chain IDs
    /// @param whIDs Wormhole corresponding chain IDs
    function setGlacisChainIds(
        uint256[] memory chainIDs,
        uint16[] memory whIDs
    ) external onlyOwner {
        uint256 len = chainIDs.length;
        if (len != whIDs.length)
            revert GlacisAbstractAdapter__IDArraysMustBeSameLength();
        for (uint256 i; i < len; ) {
            uint256 gID = chainIDs[i];
            uint16 whID = whIDs[i];
            if (gID == 0)
                revert GlacisAbstractAdapter__DestinationChainIdNotValid();
            glacisChainIdToAdapterChainId[gID] = whID;
            adapterChainIdToGlacisChainId[whID] = gID;

            unchecked {
                ++i;
            }
        }

        emit GlacisWormholeAdapter__SetGlacisChainIDs(chainIDs, whIDs);
    }

    /// @notice Gets the corresponding Wormhole chain ID for the specified Glacis chain ID
    /// @param chainId Glacis chain ID
    /// @return The corresponding Wormhole chain ID
    function adapterChainID(uint256 chainId) external view returns (uint16) {
        return glacisChainIdToAdapterChainId[chainId];
    }

    /// @notice Queries if the specified Glacis chain ID is supported by this adapter
    /// @param chainId Glacis chain ID
    /// @return True if chain is supported, false otherwise
    function chainIsAvailable(uint256 chainId) public view returns (bool) {
        return glacisChainIdToAdapterChainId[chainId] != 0;
    }
}
