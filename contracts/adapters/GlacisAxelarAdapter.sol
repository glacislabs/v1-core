// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__NoRemoteAdapterForChainId, GlacisAbstractAdapter__ChainIsNotAvailable} from "./GlacisAbstractAdapter.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {AddressString} from "../libraries/AddressString.sol";
import {GlacisAbstractAdapter} from "./GlacisAbstractAdapter.sol";
import {IGlacisRouter} from "../routers/GlacisRouter.sol";
import {AddressBytes32} from "../libraries/AddressBytes32.sol";
import {GlacisCommons} from "../commons/GlacisCommons.sol";

/// @title Glacis Adapter for Axelar
/// @notice A Glacis Adapter for the Axelar network. Sends messages through the Axelar Gateway's callContract() and
/// receives Axelar requests through _execute()
contract GlacisAxelarAdapter is GlacisAbstractAdapter, AxelarExecutable {
    using Strings for address;
    using AddressString for string;
    using AddressBytes32 for bytes32;
    using AddressBytes32 for address;
    IAxelarGasService public immutable GAS_SERVICE;

    mapping(uint256 => string) public glacisChainIdToAdapterChainId;
    mapping(string => uint256) public adapterChainIdToGlacisChainId;

    event GlacisAxelarAdapter__SetGlacisChainIDs(uint256[] chainIDs, string[] chainLabels);

    /// @param _glacisRouter This chain's glacis router
    /// @param _axelarGateway This chain's axelar gateway
    /// @param _axelarGasReceiver This chain's axelar gas receiver
    /// @param _owner This adapter's owner
    constructor(
        address _glacisRouter,
        address _axelarGateway,
        address _axelarGasReceiver,
        address _owner
    )
        AxelarExecutable(_axelarGateway)
        GlacisAbstractAdapter(IGlacisRouter(_glacisRouter), _owner)
    {
        GAS_SERVICE = IAxelarGasService(_axelarGasReceiver);
    }

    /// @notice Sets the corresponding Axelar chain label for the specified Glacis chain ID
    /// @param chainIDs Glacis chain IDs
    /// @param chainLabels Axelar corresponding chain labels
    function setGlacisChainIds(
        uint256[] memory chainIDs,
        string[] memory chainLabels
    ) external onlyOwner {
        uint256 chainIdLen = chainIDs.length;
        if (chainIdLen != chainLabels.length)
            revert GlacisAbstractAdapter__IDArraysMustBeSameLength();

        for (uint256 i; i < chainIdLen; ) {
            uint256 chainId = chainIDs[i];
            string memory chainLabel = chainLabels[i];

            if (chainId == 0)
                revert GlacisAbstractAdapter__DestinationChainIdNotValid();

            glacisChainIdToAdapterChainId[chainId] = chainLabel;
            adapterChainIdToGlacisChainId[chainLabel] = chainId;

            unchecked {
                ++i;
            }
        }

        emit GlacisAxelarAdapter__SetGlacisChainIDs(chainIDs, chainLabels);
    }

    /// @notice Gets the corresponding Axelar chain label for the specified Glacis chain ID
    /// @param chainId Glacis chain ID
    /// @return The corresponding Axelar label
    function adapterChainID(
        uint256 chainId
    ) external view returns (string memory) {
        return glacisChainIdToAdapterChainId[chainId];
    }

    /// @notice Queries if the specified Glacis chain ID is supported by this adapter
    /// @param chainId Glacis chain ID
    /// @return True if chain is supported, false otherwise
    function chainIsAvailable(
        uint256 chainId
    ) public view virtual returns (bool) {
        return bytes(glacisChainIdToAdapterChainId[chainId]).length > 0;
    }

    /// @notice Dispatches payload to specified Glacis chain ID and address through Axelar GMP
    /// @param toChainId Destination chain (Glacis ID)
    /// @param refundAddress The address to refund native asset surplus
    /// @param payload Payload to send
    function _sendMessage(
        uint256 toChainId,
        address refundAddress,
        GlacisCommons.CrossChainGas memory,
        bytes memory payload
    ) internal override onlyGlacisRouter {
        string memory destinationChain = glacisChainIdToAdapterChainId[
            toChainId
        ];
        if (remoteCounterpart[toChainId] == bytes32(0))
            revert GlacisAbstractAdapter__NoRemoteAdapterForChainId(toChainId);
        string memory destinationAddress = remoteCounterpart[toChainId]
            .toAddress()
            .toHexString();
        if (bytes(destinationChain).length == 0)
            revert GlacisAbstractAdapter__ChainIsNotAvailable(toChainId);

        if (msg.value > 0) {
            GAS_SERVICE.payNativeGasForContractCall{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                refundAddress
            );
        }
        gateway.callContract(destinationChain, destinationAddress, payload);
    }

    /// @notice Receives route request from Axelar and routes it to GlacisRouter
    /// @param sourceChain Source chain (Axelar chain label)
    /// @param sourceAddress Source address on remote chain
    /// @param payload Payload to route
    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    )
        internal
        override
        onlyAuthorizedAdapter(
            adapterChainIdToGlacisChainId[sourceChain],
            _toLowerCase(string(sourceAddress[2:42])).toAddress().toBytes32()
        )
    {
        GLACIS_ROUTER.receiveMessage(adapterChainIdToGlacisChainId[sourceChain], payload);
    }

    /// @notice Converts a string to lowercase
    /// @param str The string to convert to lowercase
    function _toLowerCase(
        string memory str
    ) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        uint256 bStrLen = bStr.length;
        for (uint256 i; i < bStrLen; ) {
            unchecked {
                // Uppercase character...
                if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                    // So we add 32 to make it lowercase
                    bLower[i] = bytes1(uint8(bStr[i]) + 32);
                } else {
                    bLower[i] = bStr[i];
                }
                ++i;
            }
        }
        return string(bLower);
    }
}
