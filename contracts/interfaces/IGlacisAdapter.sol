// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

/// An interface that defines the GMP modules (adapters) that the GlacisRouter interacts with.
interface IGlacisAdapter {
    /// Determines if a chain is available through this adapter
    /// @param chainId the Glacis chain ID
    /// @return true if the chain is available, false otherwise
    function chainIsAvailable(uint256 chainId) external view returns (bool);

    /// Sends a payload across chains to the destination router.
    /// @param chainId the Glacis chain ID
    /// @param payload the data packet to send across chains
    function sendMessage(
        uint256 chainId,
        address refundAddress,
        bytes calldata payload
    ) external payable;

    error IGlacisAdapter__ChainIsNotAvailable(uint256 toChainId);
}
