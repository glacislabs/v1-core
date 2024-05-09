// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

import {SimpleNonblockingLzApp} from "contracts/adapters/LayerZero/SimpleNonblockingLzApp.sol";

contract LayerZeroTextSample is SimpleNonblockingLzApp {
    string public value;

    constructor(address _lzEndpoint) SimpleNonblockingLzApp(_lzEndpoint) {}

    function setRemoteValue(
        uint16 destChainId,
        address destChainAddress,
        bytes memory payload
    ) external payable {
        _lzSend({
            _dstChainId: destChainId,
            _dstChainAddress: destChainAddress,
            _payload: payload,
            _refundAddress: payable(msg.sender),
            _zroPaymentAddress: address(0x0),
            _adapterParams: bytes(""),
            _nativeFee: msg.value
        });
    }

    function _nonblockingLzReceive(
        uint16,
        bytes memory,
        uint64,
        bytes memory _payload
    ) internal override {
        value = abi.decode(_payload, (string));
    }
}
