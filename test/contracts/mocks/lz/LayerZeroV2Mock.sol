// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;
import {GlacisLayerZeroV2Adapter} from "../../../../contracts/adapters/LayerZero/GlacisLayerZeroV2Adapter.sol";
import {AddressBytes32} from "../../../../contracts/libraries/AddressBytes32.sol";
import {MessagingParams, MessagingReceipt, Origin, MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract LayerZeroV2Mock {
    using AddressBytes32 for address;
    using AddressBytes32 for bytes32;

    error LayerZeroV2GMPMock__RefundAddressDoesNotReceiveRefund();
    
    uint64 private nonce = 0;
    mapping(address => address) delegates;

    function send(
        MessagingParams calldata _params,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory) {
        bytes32 messageId = keccak256(abi.encode(_params, nonce));

        GlacisLayerZeroV2Adapter(_params.receiver.toAddress()).lzReceive(
            Origin(getChainId(), msg.sender.toBytes32(), nonce),
            keccak256(abi.encode(_params, nonce)),
            _params.message,
            msg.sender,
            ""
        );

        nonce += 1;

        (bool success, ) = payable(_refundAddress).call{value: msg.value}("");
        if (!success) {
            revert LayerZeroV2GMPMock__RefundAddressDoesNotReceiveRefund();
        }

        return MessagingReceipt(messageId, nonce - 1, MessagingFee(msg.value, 0));
    }

    function getChainId() public pure returns (uint32) {
        return 31337;
    }

    function setDelegate(address delegate) external {
        delegates[msg.sender] = delegate;
    }
}
