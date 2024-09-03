// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;
import {IWormholeRelayer} from "../../../../contracts/adapters/Wormhole/IWormholeRelayer.sol";
import {IWormholeReceiver} from "../../../../contracts/adapters/Wormhole/IWormholeReceiver.sol";

contract WormholeSample is IWormholeReceiver {
    uint256 public value;

    IWormholeRelayer public immutable WORMHOLE_RELAYER;
    uint16 internal immutable WORMHOLE_CHAIN_ID;
    uint256 internal constant GAS_LIMIT = 900000;
    uint256 internal constant RECEIVER_VALUE = 0;

    constructor(address _wormholeRelayer, uint16 wormholeChainId) {
        WORMHOLE_RELAYER = IWormholeRelayer(_wormholeRelayer);
        WORMHOLE_CHAIN_ID = wormholeChainId;
    }

    function setRemoteValue(
        uint16 destinationChainId,
        address destinationAddress,
        bytes memory payload
    ) external payable {
        (uint256 nativePriceQuote, ) = WORMHOLE_RELAYER.quoteEVMDeliveryPrice(
            destinationChainId,
            RECEIVER_VALUE,
            GAS_LIMIT
        );
        WORMHOLE_RELAYER.sendPayloadToEvm{value: nativePriceQuote}(
            destinationChainId,
            destinationAddress,
            payload,
            RECEIVER_VALUE,
            GAS_LIMIT,
            WORMHOLE_CHAIN_ID,
            msg.sender
        );
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory,
        bytes32, // sourceAddress,
        uint16, // sourceChain,
        bytes32 // deliveryHash
    ) public payable {
        if (payload.length > 0) (value) += abi.decode(payload, (uint256));
    }
}
