// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

import {IWormholeReceiver} from "../../../../contracts/adapters/Wormhole/IWormholeReceiver.sol";
import {IWormholeRelayer, VaaKey} from "../../../../contracts/adapters/Wormhole/IWormholeRelayer.sol";

import {GlacisWormholeAdapter} from "../../../../contracts/adapters/Wormhole/GlacisWormholeAdapter.sol";

contract WormholeRelayerMock is IWormholeRelayer, IWormholeReceiver {
    address public glacisWormholeAdapter;

    function setGlacisAdapter(address glacisWormholeAdapter_) public {
        glacisWormholeAdapter = glacisWormholeAdapter_;
    }

    function sendPayloadToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 gasLimit
    ) public payable returns (uint64) {
        // Execute on the same chain
        IWormholeReceiver(this).receiveWormholeMessages(
            payload,
            new bytes[](0),
            bytes32(bytes20(msg.sender)) >> 96,
            targetChain,
            // Mock a hash
            keccak256(
                abi.encode(
                    targetChain,
                    targetAddress,
                    payload,
                    receiverValue,
                    gasLimit,
                    block.timestamp
                )
            )
        );
        return 0;
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalVaas,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) public payable override {
        GlacisWormholeAdapter(glacisWormholeAdapter).receiveWormholeMessages(
            payload,
            additionalVaas,
            sourceAddress,
            sourceChain,
            deliveryHash
        );
    }

    function sendPayloadToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 gasLimit,
        uint16,
        address
    ) external payable returns (uint64) {
        return
            sendPayloadToEvm(
                targetChain,
                targetAddress,
                payload,
                receiverValue,
                gasLimit
            );
    }

    function deliver(
        bytes[] memory encodedVMs,
        bytes memory encodedDeliveryVAA,
        address payable relayerRefundAddress,
        bytes memory deliveryOverrides
    ) external payable {}

    function getDefaultDeliveryProvider()
        external
        view
        returns (address deliveryProvider)
    {}

    function quoteDeliveryPrice(
        uint16 targetChain,
        uint256 receiverValue,
        bytes memory encodedExecutionParameters,
        address deliveryProviderAddress
    )
        external
        view
        returns (uint256 nativePriceQuote, bytes memory encodedExecutionInfo)
    {}

    function quoteEVMDeliveryPrice(
        uint16 targetChain,
        uint256 receiverValue,
        uint256 gasLimit,
        address deliveryProviderAddress
    )
        external
        view
        returns (
            uint256 nativePriceQuote,
            uint256 targetChainRefundPerGasUnused
        )
    {}

    function quoteNativeForChain(
        uint16 targetChain,
        uint256 currentChainAmount,
        address deliveryProviderAddress
    ) external view returns (uint256 targetChainAmount) {}

    function getRegisteredWormholeRelayerContract(
        uint16 chainId
    ) external view returns (bytes32) {}

    function quoteEVMDeliveryPrice(
        uint16 targetChain,
        uint256 receiverValue,
        uint256 gasLimit
    )
        external
        view
        returns (
            uint256 nativePriceQuote,
            uint256 targetChainRefundPerGasUnused
        )
    {}

    function resend(
        VaaKey memory deliveryVaaKey,
        uint16 targetChain,
        uint256 newReceiverValue,
        bytes memory newEncodedExecutionParameters,
        address newDeliveryProviderAddress
    ) external payable returns (uint64 sequence) {}

    function sendVaasToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 gasLimit,
        VaaKey[] memory vaaKeys,
        uint16 refundChain,
        address refundAddress
    ) external payable returns (uint64 sequence) {}

    function sendVaasToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 gasLimit,
        VaaKey[] memory vaaKeys
    ) external payable returns (uint64 sequence) {}

    function send(
        uint16 targetChain,
        bytes32 targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 paymentForExtraReceiverValue,
        bytes memory encodedExecutionParameters,
        uint16 refundChain,
        bytes32 refundAddress,
        address deliveryProviderAddress,
        VaaKey[] memory vaaKeys,
        uint8 consistencyLevel
    ) external payable returns (uint64 sequence) {}

    function resendToEvm(
        VaaKey memory deliveryVaaKey,
        uint16 targetChain,
        uint256 newReceiverValue,
        uint256 newGasLimit,
        address newDeliveryProviderAddress
    ) external payable returns (uint64 sequence) {}

    function sendToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 paymentForExtraReceiverValue,
        uint256 gasLimit,
        uint16 refundChain,
        address refundAddress,
        address deliveryProviderAddress,
        VaaKey[] memory vaaKeys,
        uint8 consistencyLevel
    ) external payable returns (uint64 sequence) {}
}
