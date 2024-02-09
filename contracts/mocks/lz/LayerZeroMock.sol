// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;
import {GlacisLayerZeroAdapter} from "../../../../contracts/adapters/LayerZero/GlacisLayerZeroAdapter.sol";

contract LayerZeroGMPMock {
    error LayerZeroGMPMock__RefundAddressDoesNotReceiveRefund();

    function send(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address _refundAddress,
        address, // _zroAddressPaymet
        bytes calldata // _adapaterParams
    ) external payable {
        // Destination = Source
        address destination = address(uint160(bytes20(_destination)));
        lzReceive(
            destination,
            _dstChainId,
            abi.encodePacked(msg.sender, destination), // This is sending the entire route 0xADDRESSADDRESS
            0,
            _payload
        );
        (bool success, ) = payable(_refundAddress).call{value: msg.value}("");
        if (!success) {
            revert LayerZeroGMPMock__RefundAddressDoesNotReceiveRefund();
        }
    }

    function lzReceive(
        address destination,
        uint16 srcChainId,
        bytes memory srcAddress, // srcAddress, will be the other adapter
        uint64 value,
        bytes memory payload
    ) public {
        GlacisLayerZeroAdapter(destination).lzReceive(
            srcChainId,
            srcAddress,
            value,
            payload
        );
    }

    function getChainId() external pure returns (uint16) {
        return 1;
    }
}
