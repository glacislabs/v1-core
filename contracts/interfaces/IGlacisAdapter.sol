// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";

/// @title IGlacisAdapter
/// @notice An interface that defines the GMP modules (adapters) that the GlacisRouter interacts with.
interface IGlacisAdapter {
    /// Determines If a chain is available through this adapter
    /// @param chainId The Glacis chain ID
    /// @return True if the chain is available, false otherwise
    function chainIsAvailable(uint256 chainId) external view returns (bool);

    /// Sends a payload across chains to the destination router.
    /// @param chainId The Glacis chain ID
    /// @param refundAddress The address to refund excessive gas payment to
    /// @param payload The data packet to send across chains
    function sendMessage(
        uint256 chainId,
        address refundAddress,
        GlacisCommons.CrossChainGas calldata incentives,
        bytes calldata payload
    ) external payable;

    error IGlacisAdapter__ChainIsNotAvailable(uint256 toChainId);
}
