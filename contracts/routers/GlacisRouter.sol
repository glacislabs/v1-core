// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisAbstractRouter} from "./GlacisAbstractRouter.sol";
import {IGlacisClient} from "../interfaces/IGlacisClient.sol";
import {IGlacisAdapter} from "../interfaces/IGlacisAdapter.sol";
import {IGlacisRouter} from "../interfaces/IGlacisRouter.sol";

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

contract GlacisRouter is GlacisAbstractRouter, IGlacisRouter {
    mapping(bytes32 => MessageData) private messageReceipts;
    mapping(bytes32 => address) public messageSenders;

    struct MessageData {
        uint8 uniqueMessagesReceived;
        bool executed;
        uint8 receivedGMPIdsBitmap;
    }

    constructor(address owner_) GlacisAbstractRouter(block.chainid) {
        _transferOwnership(owner_);
    }

    /// @notice Routes the payload to the specific address on the destination chain
    /// using specified GMPs with quorum and retribale feature
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param gmps Array of GMPs to be used for the routing
    /// @param fees Array of fees to be sent to each GMP for routing (must be same length as gmps)
    /// @param refundAddress An (ideally EOA) address for native currency to be sent to that are greater than fees charged
    /// @param retriable True if this message could be retried
    function route(
        uint256 chainId,
        address to,
        bytes memory payload,
        uint8[] memory gmps,
        uint256[] memory fees,
        address refundAddress,
        bool retriable
    ) public payable virtual returns (bytes32) {
        // Validate input
        uint256 gmpsLength = gmps.length;
        validateInput(gmpsLength, fees);

        (bytes32 messageId, uint256 nonce) = _createGlacisMessageId(
            chainId,
            to,
            payload
        );
        // @notice This follows GlacisData stored within GlacisCommons
        bytes memory glacisPackedPayload = abi.encode(
            messageId,
            nonce,
            msg.sender,
            to,
            payload
        );
        _processRouting(
            chainId,
            glacisPackedPayload,
            gmps,
            fees,
            refundAddress
        );
        if (retriable) {
            messageSenders[messageId] = msg.sender;
        }

        // Emit both Glacis event and the EIP-5164 event
        emit MessageDispatched(messageId, msg.sender, chainId, to, payload);
        emit GlacisRouter__MessageDispatched(
            messageId,
            msg.sender,
            chainId,
            to,
            payload,
            gmps,
            fees,
            refundAddress,
            retriable
        );

        return messageId;
    }

    /// @notice Retries routing the payload to the specific address on destination chain
    /// using specified GMPs and quorum
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param to Destination address on remote chain
    /// @param payload Payload to be routed
    /// @param gmps Array of GMPs to be used for the routing
    /// @param fees Array of fees to be sent to each GMP for routing (must be same length as gmps)
    /// @param refundAddress An (ideally EOA) address for native currency to be sent to that are greater than fees charged
    /// @param messageId The messageId to retry
    /// @param nonce Unique value for this message routing
    function routeRetry(
        uint256 chainId,
        address to,
        bytes memory payload,
        uint8[] memory gmps,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce
    ) public payable virtual returns (bytes32) {
        // Validate input
        uint256 gmpLength = gmps.length;
        validateInput(gmpLength, fees);

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

        bytes memory glacisPackedPayload = abi.encode(
            messageId,
            nonce,
            msg.sender,
            to,
            payload
        );
        _processRouting(
            chainId,
            glacisPackedPayload,
            gmps,
            fees,
            refundAddress
        );

        // Emit both Glacis event and the EIP-5164 event
        emit MessageDispatched(messageId, msg.sender, chainId, to, payload);
        emit GlacisRouter__MessageRetried(
            messageId,
            msg.sender,
            chainId,
            to,
            payload,
            gmps,
            fees,
            refundAddress
        );

        // There is no need to check that this has been retried before. Retry as many times as desired.
        return messageId;
    }

    /// @notice Performs actual message dispatching to all the required adapters
    /// @param chainId Destination chain (Glacis chain ID)
    /// @param glacisPackedPayload Payload with embedded glacis data to be routed
    /// @param gmps Array of GMPs to be used for the routing
    /// @param fees Payment for each GMP to cover source and destination gas fees (excess will be refunded)
    /// @param refundAddress Address to refund excess gas payment
    function _processRouting(
        uint256 chainId,
        bytes memory glacisPackedPayload,
        uint8[] memory gmps,
        uint256[] memory fees,
        address refundAddress
    ) internal {
        uint256 gmpLength = gmps.length;

        for (uint8 gmp; gmp < gmpLength; ) {
            address adapter = glacisGMPIdToAdapter[gmps[gmp]];

            if (gmps[gmp] == 0) revert GlacisRouter__GMPNotSupported();
            if (adapter == address(0)) revert GlacisRouter__RouteDoesNotExist();

            IGlacisAdapter(adapter).sendMessage{value: fees[gmp]}(
                chainId,
                refundAddress,
                glacisPackedPayload
            );

            // This is acceptable, as there is no "continue" within the for loop
            unchecked {
                ++gmp;
            }
        }
    }

    /// @notice Receives a cross chain message from an IGlacisAdapter.
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param glacisPayload Received payload with embedded GlacisData
    function receiveMessage(
        uint256 fromChainId,
        bytes memory glacisPayload
    ) public onlyAdapter {
        uint8 gmpId = adapterToGlacisGMPId[msg.sender];
        (GlacisData memory glacisData, bytes memory payload) = abi.decode(
            glacisPayload,
            (GlacisData, bytes)
        );

        // Check if the route is allowed
        IGlacisClient client = IGlacisClient(glacisData.originalTo);

        bool routeAllowed = client.isAllowedRoute(
            fromChainId,
            glacisData.originalFrom,
            gmpId,
            payload
        );

        if (!routeAllowed) revert GlacisRouter__ClientDeniedRoute();

        // Get the quorum requirements
        uint256 quorum = client.getQuorum(glacisData, payload);

        // Check if the message per GMP is unique
        MessageData memory currentReceipt = messageReceipts[
            glacisData.messageId
        ];

        if (gmpId > 8) revert GlacisRouter__ImpossibleGMPId(gmpId);

        // Adjusts gmp ID for bitmap index
        uint8 adjustedGmpId = gmpId - 1;

        if (_isBitSet(currentReceipt.receivedGMPIdsBitmap, adjustedGmpId))
            revert GlacisRouter__MessageAlreadyReceivedFromGMP();
        currentReceipt.receivedGMPIdsBitmap = _setBit(
            currentReceipt.receivedGMPIdsBitmap,
            adjustedGmpId
        );
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

            emit MessageIdExecuted(fromChainId, glacisData.messageId);
        } else {
            messageReceipts[glacisData.messageId] = currentReceipt;
        }
    }

    /// @notice Validates that all the fees sum up to the total payment
    /// @param gmpsLength The length of the gmps array
    /// @param fees The fees array
    function validateInput(uint256 gmpsLength, uint256[] memory fees) internal {
        if (gmpsLength == 0) revert GlacisRouter__GMPCountMustBeAtLeastOne();
        if (gmpsLength != fees.length)
            revert GlacisRouter__FeeArrayMustEqualGMPArray();

        uint256 feeSum;
        for (uint8 i; i < gmpsLength; ) {
            feeSum += fees[i];
            unchecked {
                ++i;
            }
        }
        if (feeSum != msg.value)
            revert GlacisRouter__FeeSumMustBeEqualToValue();
    }
}
