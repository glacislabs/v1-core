// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// @dev Import the 'MessagingFee' and 'MessagingReceipt' so it's exposed to OApp implementers
// solhint-disable-next-line no-unused-import

// @dev Import the 'Origin' so it's exposed to OApp implementers
// solhint-disable-next-line no-unused-import
import { OAppReceiverNoPeer, Origin } from "./OAppReceiverNoPeer.sol";
import { OAppCoreNoPeer } from "./OAppCoreNoPeer.sol";

/**
 * @title OAppNoPeer
 * @dev Abstract contract serving as the base for OApp implementation, combining OAppSender and OAppReceiver functionality.
 */
abstract contract OAppNoPeer is OAppReceiverNoPeer {
    /**
     * @dev Constructor to initialize the OApp with the provided endpoint and owner.
     * @param _endpoint The address of the LOCAL LayerZero endpoint.
     * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
     */
    constructor(address _endpoint, address _delegate) OAppCoreNoPeer(_endpoint, _delegate) {}

    /**
     * @notice Retrieves the OApp version information.
     * @return senderVersion The version of the OAppSender.sol implementation.
     * @return receiverVersion The version of the OAppReceiver.sol implementation.
     */
    function oAppVersion()
        public
        pure
        virtual
        override(OAppReceiverNoPeer)
        returns (uint64 senderVersion, uint64 receiverVersion)
    {
        return (0, RECEIVER_VERSION);
    }
}
