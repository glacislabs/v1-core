// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

/// An interface as described by EIP-5164. In Glacis' current implementation, messages are not dispatched with the
/// dispatchMessage function, hence its removal. The only adherence now is to the event, which the GlacisRouter will
/// use.
interface IMessageDispatcher {
    /// The MessageDispatched event must be emitted by the MessageDispatcher when an individual message is dispatched.
    event MessageDispatched(
        bytes32 indexed messageId,
        address indexed from,
        uint256 indexed toChainId,
        address to,
        bytes data
    );
}
