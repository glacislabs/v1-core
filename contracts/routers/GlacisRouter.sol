// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisAbstractRouter} from "./GlacisAbstractRouter.sol";
import {IGlacisClient} from "../interfaces/IGlacisClient.sol";
import {IGlacisAdapter} from "../interfaces/IGlacisAdapter.sol";
import {IGlacisRouter} from "../interfaces/IGlacisRouter.sol";
import {AddressBytes32} from "../libraries/AddressBytes32.sol";

error GlacisRouter__GMPNotSupported(); //0xed2e8008
error GlacisRouter__RouteDoesNotExist(); //0xeb470cd2
error GlacisRouter__OnlyAdaptersAllowed(); //0xb519c5ed
error GlacisRouter__ClientDeniedRoute();
error GlacisRouter__NotOwnerOfMessageToRetry();
error GlacisRouter__MessageInputNotIdenticalForRetry();
error GlacisRouter__ImpossibleGMPId(uint8 gmpId);
error GlacisRouter__MessageAlreadyReceivedFromGMP();
error GlacisRouter__MessageIdNotValid();
error GlacisRouter__FeeArrayMustEqualGMPArray();
error GlacisRouter__GMPCountMustBeAtLeastOne();
error GlacisRouter__FeeSumMustBeEqualToValue();

/// @title Glacis Router
/// @notice A central router to send and receive cross-chain messages
contract GlacisRouter is GlacisAbstractRouter, IGlacisRouter {
    using AddressBytes32 for address;
    using AddressBytes32 for bytes32;

    mapping(bytes32 => MessageData) private messageReceipts;
    mapping(bytes32 => address) public messageSenders;
    mapping(bytes32 => mapping(address => bool))
        private receivedCustomAdapterMessages;

    struct MessageData {
        uint8 uniqueMessagesReceived;
        bool executed;
        uint8 receivedGMPIdsBitmap;
    }

    /// @param _owner The owner of this contract
    constructor(address _owner) GlacisAbstractRouter(block.chainid) {
        _transferOwnership(_owner);
    }

    /// @notice Routes the payload to the specific address on the destination chain
    /// using specified GMPs with quorum and retribale feature
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapters An array of adapters to be used for the routing
    /// @param fees Array of fees to be sent to each GMP & custom adapter for routing (must be same length as gmps)
    /// @param refundAddress An (ideally EOA) address for native currency to be sent to that are greater than fees charged
    /// @param retriable True if this message could be retried
    function route(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        uint256[] memory fees,
        address refundAddress,
        bool retriable
    ) public payable virtual returns (bytes32 messageId, uint256 nonce) {
        // Validate input
        validateFeesInput(adapters.length, fees);

        bytes32 from = msg.sender.toBytes32();
        (messageId, nonce) = _createGlacisMessageId(
            chainId,
            to,
            payload
        );
        
        _processRouting(
            chainId,
            // @notice This follows GlacisData stored within GlacisCommons
            abi.encode(messageId, nonce, from, to, payload),
            adapters,
            fees,
            refundAddress
        );
        if (retriable) {
            messageSenders[messageId] = msg.sender;
        }

        // Emit both Glacis event and the EIP-5164 event
        emit GlacisRouter__MessageDispatched(
            messageId,
            from,
            chainId,
            to,
            payload,
            adapters,
            fees,
            refundAddress,
            retriable
        );

        return (messageId, nonce);
    }

    /// @notice Retries routing the payload to the specific address on destination chain
    /// using specified GMPs and quorum
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param adapters An array of custom adapters to be used for the routing
    /// @param fees Array of fees to be sent to each GMP for routing (must be same length as gmps)
    /// @param refundAddress An (ideally EOA) address for native currency to be sent to that are greater than fees charged
    /// @param messageId The messageId to retry
    /// @param nonce Unique value for this message routing
    function routeRetry(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce
    ) public payable virtual returns (bytes32) {
        // Validate input
        validateFeesInput(adapters.length, fees);

        address ownerOfMessageToRetry = messageSenders[messageId];
        if (ownerOfMessageToRetry != msg.sender)
            revert GlacisRouter__NotOwnerOfMessageToRetry();
        if (
            !validateGlacisMessageId(
                messageId,
                chainId,
                GLACIS_CHAIN_ID,
                to,
                nonce,
                payload
            )
        ) revert GlacisRouter__MessageInputNotIdenticalForRetry();

        bytes32 from = msg.sender.toBytes32();
        bytes memory glacisPackedPayload = abi.encode(
            messageId,
            nonce,
            from,
            to,
            payload
        );
        _processRouting(
            chainId,
            glacisPackedPayload,
            adapters,
            fees,
            refundAddress
        );

        // Emit both Glacis event and the EIP-5164 event
        emit GlacisRouter__MessageRetried(
            messageId,
            from,
            chainId,
            to,
            payload,
            adapters,
            fees,
            refundAddress
        );

        // There is no need to check that this has been retried before. Retry as many times as desired.
        return messageId;
    }

    /// @notice Performs actual message dispatching to all the required adapters
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param glacisPackedPayload Payload with embedded glacis data to be routed
    /// @param adapters An array of custom adapters to be used for the routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    function _processRouting(
        uint256 chainId,
        bytes memory glacisPackedPayload,
        address[] memory adapters,
        uint256[] memory fees,
        address refundAddress
    ) internal {
        uint256 adaptersLength = adapters.length;

        for (uint8 adapterIndex; adapterIndex < adaptersLength; ) {
            address adapter = adapters[adapterIndex];

            // If adapter address is less than 255, we override it with a Glacis default adapter
            if (uint160(adapter) <= 255) {
                adapter = glacisGMPIdToAdapter[uint8(uint160(adapter))];
                revert GlacisRouter__GMPNotSupported();
            }
            if (adapter == address(0)) revert GlacisRouter__RouteDoesNotExist();

            IGlacisAdapter(adapter).sendMessage{value: fees[adapterIndex]}(
                chainId,
                refundAddress,
                glacisPackedPayload
            );

            // This is acceptable, as there is no "continue" within the for loop
            unchecked {
                ++adapterIndex;
            }
        }
    }

    /// @notice Receives a cross chain message from an IGlacisAdapter.
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param glacisPayload Received payload with embedded GlacisData
    function receiveMessage(
        uint256 fromChainId,
        bytes memory glacisPayload
    ) public {
        // Decode sent data
        uint8 gmpId = adapterToGlacisGMPId[msg.sender];
        (GlacisData memory glacisData, bytes memory payload) = abi.decode(
            glacisPayload,
            (GlacisData, bytes)
        );

        // Get the client
        IGlacisClient client = IGlacisClient(glacisData.originalTo.toAddress());

        // TODO: replace isCustomAdapter with modified isAllowedRoute (that includes address instead of gmp)
        // TODO: 1. ask if the adapter address is accepted. 2. if not, ask if the gmp number is accepted (if it is a gmp)
        
        // Verifies that the sender is an adapter or custom adapter & is an allowed route
        bool isCustomAdapter = client.isCustomAdapter(
            msg.sender,
            glacisData,
            payload
        );
        if (gmpId == 0) {
            if (!isCustomAdapter) revert GlacisRouter__OnlyAdaptersAllowed();

            bool routeAllowed = client.isAllowedRoute(
                fromChainId,
                glacisData.originalFrom,
                uint160(msg.sender),
                payload
            );
            if (!routeAllowed) revert GlacisRouter__ClientDeniedRoute();
        } else {
            bool routeAllowed = client.isAllowedRoute(
                fromChainId,
                glacisData.originalFrom,
                gmpId,
                payload
            );
            if (!routeAllowed) revert GlacisRouter__ClientDeniedRoute();
        }

        // Get the quorum requirements
        uint256 quorum = client.getQuorum(glacisData, payload);

        // Check if the message per GMP is unique
        MessageData memory currentReceipt = messageReceipts[
            glacisData.messageId
        ];

        if (gmpId > 8) revert GlacisRouter__ImpossibleGMPId(gmpId);

        // Ensures that the message hasn't come from the same adapter again
        if (isCustomAdapter) {
            if (receivedCustomAdapterMessages[glacisData.messageId][msg.sender])
                revert GlacisRouter__MessageAlreadyReceivedFromGMP();

            receivedCustomAdapterMessages[glacisData.messageId][
                msg.sender
            ] = true;
        } else {
            uint8 adjustedGmpId = gmpId - 1;

            if (_isBitSet(currentReceipt.receivedGMPIdsBitmap, adjustedGmpId))
                revert GlacisRouter__MessageAlreadyReceivedFromGMP();
            currentReceipt.receivedGMPIdsBitmap = _setBit(
                currentReceipt.receivedGMPIdsBitmap,
                adjustedGmpId
            );
        }
        currentReceipt.uniqueMessagesReceived += 1;

        emit GlacisRouter__ReceivedMessage(
            glacisData.messageId,
            glacisData.originalFrom,
            fromChainId,
            glacisData.originalTo
        );

        // Verify that the messageID can be calculated from the data provided,
        if (
            !_validateGlacisMessageId(
                glacisData.messageId,
                GLACIS_CHAIN_ID,
                fromChainId,
                glacisData.originalTo,
                glacisData.originalFrom,
                glacisData.nonce,
                payload
            )
        ) revert GlacisRouter__MessageIdNotValid();

        if (
            currentReceipt.uniqueMessagesReceived == quorum &&
            !currentReceipt.executed
        ) {
            currentReceipt.executed = true;
            messageReceipts[glacisData.messageId] = currentReceipt;

            client.receiveMessage(
                _uint8ToUint8Array(currentReceipt.receivedGMPIdsBitmap),
                fromChainId,
                glacisData.originalFrom,
                payload
            );
        } else {
            messageReceipts[glacisData.messageId] = currentReceipt;
        }
    }

    /// @notice Validates that all the fees sum up to the total payment
    /// @param adaptersLength The length of the gmps array + custom adapters array
    /// @param fees The fees array
    function validateFeesInput(
        uint256 adaptersLength,
        uint256[] memory fees
    ) internal {
        if (adaptersLength == 0)
            revert GlacisRouter__GMPCountMustBeAtLeastOne();
        if (adaptersLength != fees.length)
            revert GlacisRouter__FeeArrayMustEqualGMPArray();

        uint256 feeSum;
        for (uint8 i; i < adaptersLength; ) {
            feeSum += fees[i];
            unchecked {
                ++i;
            }
        }
        if (feeSum != msg.value)
            revert GlacisRouter__FeeSumMustBeEqualToValue();
    }
}
