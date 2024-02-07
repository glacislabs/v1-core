// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

interface IMessageExecutor {
    /// MessageIdExecuted must be emitted once a message or message batch has been executed.
    event MessageIdExecuted(
        uint256 indexed fromChainId,
        bytes32 indexed messageId
    );

    /// MessageExecutors must revert if a messageId has already been executed and should emit a
    /// MessageIdAlreadyExecuted custom error.
    error MessageIdAlreadyExecuted(bytes32 messageId);

    /// MessageExecutors must revert if an individual message fails and should emit a MessageFailure custom error.
    error MessageFailure(bytes32 messageId, bytes errorData);

    // This note from EIP-5164 seems repetitive as Axelar and the other chains already do this
    // MessageExecutors MUST append the ABI-packed (messageId, fromChainId, from) to the calldata for each message
    /// being executed. This allows the receiver of the message to verify the cross-chain sender and the chain that the
    /// message is coming from.
}
