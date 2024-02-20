// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {IGlacisRouter} from "../../interfaces/IGlacisRouter.sol";
import {GlacisAbstractAdapter} from "../GlacisAbstractAdapter.sol";
import {SimpleNonblockingLzApp} from "./SimpleNonblockingLzApp.sol";
import {GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid} from "../GlacisAbstractAdapter.sol";

error GlacisLayerZeroAdapter__LZChainIdNotAccepted(uint256);

/// @title Glacis Adapter for Layer Zero GMP
/// @notice This adapter receives GlacisRouter requests through the _sendMessage function and forwards them to
/// LayerZero. Also receives LayerZero requests through the _nonblockingLzReceive function and routes
/// them to GlacisRouter
/// @dev Layer Zero uses its own chain ID system, which is uint16 and requires a mapping to Glacis chain IDs
contract GlacisLayerZeroAdapter is
    SimpleNonblockingLzApp,
    GlacisAbstractAdapter
{
    constructor(
        address lzEndpoint_,
        address glacisRouter_,
        address owner_
    )
        SimpleNonblockingLzApp(lzEndpoint_)
        GlacisAbstractAdapter(IGlacisRouter(glacisRouter_), owner_)
    {}

    mapping(uint256 => uint16) public glacisChainIdToAdapterChainId;
    mapping(uint16 => uint256) public adapterChainIdToGlacisChainId;

    /// @notice Sets the corresponding LayerZero chain ID for the specified Glacis chain ID
    /// @param glacisIDs Glacis chain IDs
    /// @param lzIDs Layer Zero chain IDs
    function setGlacisChainIds(
        uint256[] calldata glacisIDs,
        uint16[] calldata lzIDs
    ) external onlyOwner {
        uint256 glacisIDsLen = glacisIDs.length;
        if (glacisIDsLen != lzIDs.length)
            revert GlacisAbstractAdapter__IDArraysMustBeSameLength();

        for (uint256 i; i < glacisIDsLen; ) {
            uint256 glacisID = glacisIDs[i];
            uint16 lzID = lzIDs[i];

            if (glacisID == 0)
                revert GlacisAbstractAdapter__DestinationChainIdNotValid();

            glacisChainIdToAdapterChainId[glacisID] = lzID;
            adapterChainIdToGlacisChainId[lzID] = glacisID;

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Gets the corresponding LayerZero chain ID for the specified Glacis chain ID
    /// @param chainId Glacis chain ID
    /// @return The corresponding LayerZero chain Id as bytes32
    function adapterChainID(uint256 chainId) external view returns (uint16) {
        return glacisChainIdToAdapterChainId[chainId];
    }

    /// @notice Queries if the specified Glacis chain ID is supported by this adapter
    /// @param chainId Glacis chain ID
    /// @return True if chain is supported, false otherwise
    function chainIsAvailable(uint256 chainId) public view returns (bool) {
        return glacisChainIdToAdapterChainId[chainId] != 0;
    }


    /// @notice Dispatch payload to specified Glacis chain ID and address through LayerZero GMP
    /// @param toChainId Destination chain (Glacis ID)
    /// @param refundAddress The address to refund native asset surplus
    /// @param payload Payload to send
    function _sendMessage(
        uint256 toChainId,
        address refundAddress,
        bytes memory payload
    ) internal override {
        uint16 _dstchainId = glacisChainIdToAdapterChainId[toChainId];
        if (_dstchainId == 0)
            revert IGlacisAdapter__ChainIsNotAvailable(toChainId);
        _lzSend({
            _dstChainId: glacisChainIdToAdapterChainId[toChainId],
            _dstChainAddress: remoteCounterpart[toChainId],
            _payload: payload,
            _refundAddress: payable(refundAddress),
            _zroPaymentAddress: address(0x0),
            _adapterParams: bytes(""),
            _nativeFee: msg.value
        });
    }

    /// @notice Receives route message from LayerZero and routes it to GlacisRouter
    /// @param srcChainId Source chain (LayerZero ID)
    /// @param sourceAddress Source address on remote chain
    /// @param payload Payload to route
    function _nonblockingLzReceive(
        uint16 srcChainId,
        bytes memory sourceAddress, // srcAddress, will be the other adapter
        uint64,
        bytes memory payload
    )
        internal
        override
        onlyAuthorizedAdapter(
            adapterChainIdToGlacisChainId[srcChainId],
            address(uint160(bytes20(sourceAddress)))
        )
    {
        if (adapterChainIdToGlacisChainId[srcChainId] == 0)
            revert GlacisLayerZeroAdapter__LZChainIdNotAccepted(srcChainId);
        GLACIS_ROUTER.receiveMessage(
            adapterChainIdToGlacisChainId[srcChainId],
            payload
        );
    }
}
