// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IGlacisRouter} from "../../interfaces/IGlacisRouter.sol";
import {OAppNoPeer} from "./v2/OAppNoPeer.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppReceiver.sol";
import {MessagingParams} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {GlacisAbstractAdapter} from "../GlacisAbstractAdapter.sol";
import {AddressBytes32} from "../../libraries/AddressBytes32.sol";
import {GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__ChainIsNotAvailable, GlacisAbstractAdapter__NoRemoteAdapterForChainId, GlacisAbstractAdapter__OnlyAdapterAllowed} from "../GlacisAbstractAdapter.sol";
import {GlacisCommons} from "../../commons/GlacisCommons.sol";

error GlacisLayerZeroV2Adapter__PeersDisabledUseCounterpartInstead();

contract GlacisLayerZeroV2Adapter is OAppNoPeer, GlacisAbstractAdapter {
    using AddressBytes32 for bytes32;
    using OptionsBuilder for bytes;

    constructor(
        address _glacisRouter,
        address _lzEndpoint,
        address _owner
    )
        OAppNoPeer(_lzEndpoint, _owner)
        GlacisAbstractAdapter(IGlacisRouter(_glacisRouter), _owner)
    {}

    uint128 internal constant DEFAULT_GAS_LIMIT = 350_000;

    mapping(uint256 => uint32) internal glacisChainIdToAdapterChainId;
    mapping(uint32 => uint256) public adapterChainIdToGlacisChainId;

    event GlacisLayerZeroV2Adapter__SetGlacisChainIDs(
        uint256[] chainIDs,
        uint32[] lzIDs
    );

    /// @notice Sets the corresponding LayerZero chain ID for the specified Glacis chain ID
    /// @param chainIDs Glacis chain IDs
    /// @param lzIDs Layer Zero chain IDs
    function setGlacisChainIds(
        uint256[] calldata chainIDs,
        uint32[] calldata lzIDs
    ) external onlyOwner {
        uint256 glacisIDsLen = chainIDs.length;
        if (glacisIDsLen != lzIDs.length)
            revert GlacisAbstractAdapter__IDArraysMustBeSameLength();

        for (uint256 i; i < glacisIDsLen; ) {
            uint256 glacisID = chainIDs[i];
            uint32 lzID = lzIDs[i];

            if (glacisID == 0)
                revert GlacisAbstractAdapter__DestinationChainIdNotValid();

            glacisChainIdToAdapterChainId[glacisID] = lzID;
            adapterChainIdToGlacisChainId[lzID] = glacisID;

            unchecked {
                ++i;
            }
        }

        emit GlacisLayerZeroV2Adapter__SetGlacisChainIDs(chainIDs, lzIDs);
    }

    /// @notice Gets the corresponding LayerZero chain ID for the specified Glacis chain ID
    /// @param chainId Glacis chain ID
    /// @return The corresponding LayerZero chain Id as bytes32
    function adapterChainID(uint256 chainId) external view returns (uint32) {
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
        GlacisCommons.CrossChainGas memory gas,
        bytes memory payload
    ) internal override {
        bytes32 remoteCounterpart = remoteCounterpart[toChainId];
        uint32 _dstEid = glacisChainIdToAdapterChainId[toChainId];

        if (remoteCounterpart == bytes32(0))
            revert GlacisAbstractAdapter__NoRemoteAdapterForChainId(toChainId);
        if (_dstEid == 0)
            revert GlacisAbstractAdapter__ChainIsNotAvailable(toChainId);

        uint128 expectedGasLimit = gas.gasLimit == 0 ? DEFAULT_GAS_LIMIT : gas.gasLimit;

        // solhint-disable-next-line check-send-result
        endpoint.send{value: msg.value}(
            MessagingParams(
                _dstEid, 
                remoteCounterpart, 
                payload,
                OptionsBuilder.newOptions().addExecutorLzReceiveOption(expectedGasLimit, 0),
                false
            ),
            refundAddress
        );
    }

    /**
     * @dev Called when data is received from the protocol. It overrides the equivalent function in the parent contract.
     * Protocol messages are defined as packets, comprised of the following parameters.
     * @param _origin A struct containing information about where the packet came from.
     * @param payload Encoded message.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32, // guid
        bytes calldata payload,
        address, // Executor address as specified by the OApp.
        bytes calldata // Any extra data or options to trigger on receipt.
    )
        internal
        override
        onlyAuthorizedAdapter(
            adapterChainIdToGlacisChainId[_origin.srcEid],
            _origin.sender
        )
    {
        GLACIS_ROUTER.receiveMessage(
            adapterChainIdToGlacisChainId[_origin.srcEid],
            payload
        );
    }

    /**
     * @notice Checks if the path initialization is allowed based on the provided origin.
     * @param origin The origin information containing the source endpoint and sender address.
     * @return Whether the path has been initialized.
     *
     * @dev This indicates to the endpoint that the OApp has enabled msgs for this particular path to be received.
     * @dev This defaults to assuming if a peer has been set, its initialized.
     */
    function allowInitializePath(
        Origin calldata origin
    ) public view override returns (bool) {
        return
            remoteCounterpart[adapterChainIdToGlacisChainId[origin.srcEid]] ==
            origin.sender;
    }

    function peers(uint32 _eid) external view returns (bytes32 peer) {
        return remoteCounterpart[adapterChainIdToGlacisChainId[_eid]];
    }

    function setPeer(uint32, bytes32) external view onlyOwner {
        revert GlacisLayerZeroV2Adapter__PeersDisabledUseCounterpartInstead();
    }
}
