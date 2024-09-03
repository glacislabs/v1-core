// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;
import {GlacisLayerZeroAdapter} from "../../../../contracts/adapters/LayerZero/GlacisLayerZeroAdapter.sol";

contract LayerZeroOneWayMock {
    function send(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address, // _refundAddress
        address, // _zroAddressPaymet
        bytes calldata // _adapaterParams
    ) external payable {}

    function getChainId() external pure returns (uint16) {
        return 1;
    }

    function send_mock(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address, // _refundAddress
        address, // _zroAddressPaymet
        bytes calldata // _adapaterParams
    ) external payable {
        GlacisLayerZeroAdapter(msg.sender).lzReceive(
            _dstChainId,
            _destination,
            0,
            _payload
        );
    }
}
