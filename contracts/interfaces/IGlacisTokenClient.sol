// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";
import {IGlacisAccessControlClient} from "./IGlacisAccessControlClient.sol";

/// @title IGlacisTokenClient
/// @notice An interface that defines the GMP modules (adapters) that the GlacisRouter interacts with.
/// @notice Should be paired with the IGlacisClient abstract smart contract.
interface IGlacisTokenClient is IGlacisAccessControlClient {
    /// @notice Receives message from GMP(s) through GlacisRouter
    /// @param fromAdapters Addresses of the adapters that sent this message (that reached quorum requirements)
    /// @param fromChainId Source chain (Glacis chain ID)
    /// @param fromAddress Source address on source chain
    /// @param payload Routed payload
    function receiveMessageWithTokens(
        address[] memory fromAdapters,
        uint256 fromChainId,
        bytes32 fromAddress,
        bytes calldata payload,
        address token,
        uint256 amount
    ) external;

    /// @notice The quorum of messages that the contract expects with a specific message from the
    ///         token router
    function getQuorum(
        GlacisCommons.GlacisData memory,
        bytes memory,
        address,
        uint256
    ) external view returns (uint256);
}
