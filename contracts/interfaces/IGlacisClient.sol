// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {IGlacisAccessControlClient} from "../interfaces/IGlacisAccessControlClient.sol";

/// An interface that defines the GMP modules (adapters) that the GlacisRouter interacts with.
abstract contract IGlacisClient is IGlacisAccessControlClient {
    uint256 private immutable DEFAULT_QUORUM;

    constructor(uint256 _defaultQuorum) {
        DEFAULT_QUORUM = _defaultQuorum;
    }

    /// @notice Receives message from GMP(s) through GlacisRouter
    /// @param fromGmpIds IDs of the GMPs that sent this message (that reached quorum requirements)
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param fromAddress Source address on source chain
    /// @param payload Routed payload
    function receiveMessage(
        uint8[] calldata fromGmpIds,
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes calldata payload
    ) external virtual;

    /// @notice The quorum of messages that the contract expects with a specific message
    function getQuorum(
        GlacisCommons.GlacisData memory,
        bytes memory
    ) public view virtual returns (uint256) {
        return DEFAULT_QUORUM;
    }

    /// @notice Returns true if this contract recognizes the input adapter as a custom adapter.
    function isCustomAdapter(address adapter) external virtual returns(bool);
}
