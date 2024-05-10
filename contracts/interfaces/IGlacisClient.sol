// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {IGlacisAccessControlClient} from "../interfaces/IGlacisAccessControlClient.sol";

/// @title IGlacisClient
/// @notice An interface that defines the GMP modules (adapters) that the GlacisRouter interacts with.
abstract contract IGlacisClient is IGlacisAccessControlClient {
    uint256 private immutable DEFAULT_QUORUM;
    mapping(address => bool) public customAdapters;

    /// @param _defaultQuorum The default quorum that you would like. If you implement dynamic quorum, this value can be ignored 
    /// and set to 0  
    constructor(uint256 _defaultQuorum) {
        DEFAULT_QUORUM = _defaultQuorum;
    }

    /// @notice Receives message from GMP(s) through GlacisRouter
    /// @param fromAdapters Used adapters that sent this message (that reached quorum requirements)
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param fromAddress Source address on source chain
    /// @param payload Routed payload
    function receiveMessage(
        address[] calldata fromAdapters,
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

    function _addCustomAdapter(address adapter) internal virtual {
        customAdapters[adapter] = true;
    }

    function _removeCustomAdapter(address adapter) internal virtual {
        customAdapters[adapter] = false;
    }
}
