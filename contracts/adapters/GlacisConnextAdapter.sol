// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisAbstractAdapter} from "./GlacisAbstractAdapter.sol";
import {IGlacisRouter} from "../routers/GlacisRouter.sol";
import {IConnext} from "@connext/interfaces/core/IConnext.sol";
import {IXReceiver} from "@connext/interfaces/core/IXReceiver.sol";
import {GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__NoRemoteAdapterForChainId, GlacisAbstractAdapter__ChainIsNotAvailable} from "./GlacisAbstractAdapter.sol";
import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {AddressBytes32} from "../libraries/AddressBytes32.sol";

error GlacisConnextAdapter__OnlyConnextBridgeAllowed();

/// @title Glacis Adapter for Hyperlane
/// @notice A Glacis Adapter for the cannonical Hyperlane network. Sends messages through dispatch() and receives
/// messages via handle()
/// @notice Opted to create our own mailbox client because Hyperlane's base Mailbox refund address was static
contract GlacisConnextAdapter is IXReceiver, GlacisAbstractAdapter {
    using AddressBytes32 for bytes32;
    using AddressBytes32 for address;

    IConnext public immutable CONNEXT;

    mapping(uint256 => uint32) public glacisChainIdToAdapterChainId;
    mapping(uint32 => uint256) public adapterChainIdToGlacisChainId;

    /// @param _glacisRouter This chain's glacis router
    /// @param _connext This chain's Connext bridge
    /// @param _owner This adapter's owner
    constructor(
        address _glacisRouter,
        address _connext,
        address _owner
    ) GlacisAbstractAdapter(IGlacisRouter(_glacisRouter), _owner) {
        CONNEXT = IConnext(_connext);
    }

    /// @notice Sets the corresponding Hyperlane domain for the specified Glacis chain ID
    /// @param chainIds Glacis chain IDs
    /// @param domains Hyperlane corresponding chain domains
    function setGlacisChainIds(
        uint256[] memory chainIds,
        uint32[] memory domains
    ) public onlyOwner {
        uint256 chainIdLen = chainIds.length;
        if (chainIdLen != domains.length)
            revert GlacisAbstractAdapter__IDArraysMustBeSameLength();

        for (uint256 i; i < chainIdLen; ) {
            uint256 chainId = chainIds[i];
            uint32 chainLabel = domains[i];

            if (chainId == 0)
                revert GlacisAbstractAdapter__DestinationChainIdNotValid();

            glacisChainIdToAdapterChainId[chainId] = chainLabel;
            adapterChainIdToGlacisChainId[chainLabel] = chainId;

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Gets the corresponding Hyperlane domain ID for the specified Glacis chain ID
    /// @param chainId Glacis chain ID
    /// @return The corresponding Hyperlane domain ID
    function adapterChainID(uint256 chainId) external view returns (uint32) {
        return glacisChainIdToAdapterChainId[chainId];
    }

    /// @notice Queries if the specified Glacis chain ID is supported by this adapter
    /// @param chainId Glacis chain ID
    /// @return True if chain is supported, false otherwise
    function chainIsAvailable(
        uint256 chainId
    ) public view virtual returns (bool) {
        return glacisChainIdToAdapterChainId[chainId] != 0;
    }

    /// @notice Dispatch payload to specified Glacis chain ID and address through Hyperlane
    /// @param toChainId Destination chain (Glacis ID)
    /// @param payload Payload to send
    function _sendMessage(
        uint256 toChainId,
        address,
        GlacisCommons.CrossChainGas memory,
        bytes memory payload
    ) internal override onlyGlacisRouter {
        uint32 destinationDomain = glacisChainIdToAdapterChainId[toChainId];
        bytes32 destinationAddress = remoteCounterpart[toChainId];

        if (destinationAddress == bytes32(0))
            revert GlacisAbstractAdapter__NoRemoteAdapterForChainId(toChainId);
        if (destinationDomain == 0)
            revert GlacisAbstractAdapter__ChainIsNotAvailable(toChainId);

        CONNEXT.xcall{value: msg.value}(
            destinationDomain, 
            // This should not present any problems so long as we do not add non-EVM chains
            destinationAddress.toAddress(), 
            address(0), // _asset: use address zero for 0-value transfers
            address(this), // _delegate: address that can revert or forceLocal on destination
            0, // _amount: 0 because no funds are being transferred
            0, // _slippage: can be anything between 0-10000 because no funds are being transferred
            payload // _callData: the encoded calldata to send
        );
    }

    /// @notice Receives messages from Hyperlane
    /// @param _originSender The origin's sender address
    /// @param _origin The Connext domain ID
    /// @param _callData The bytes payload of the message
    function xReceive(
        bytes32, // _transferId
        uint256, // _amount
        address, // _asset
        address _originSender,
        uint32 _origin,
        bytes memory _callData
    )
        external
        onlyAuthorizedAdapter(adapterChainIdToGlacisChainId[_origin], _originSender.toBytes32())
        returns (bytes memory)
    {
        if (msg.sender != address(CONNEXT)) {
            revert GlacisConnextAdapter__OnlyConnextBridgeAllowed();
        }

        GLACIS_ROUTER.receiveMessage(adapterChainIdToGlacisChainId[_origin], _callData);

        return "";
    }

    // TODO: special delegate stuff with connext
    // https://docs.connext.network/developers/guides/handling-failures#increasing-slippage-tolerance
}
