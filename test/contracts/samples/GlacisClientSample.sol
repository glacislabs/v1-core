// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;
import {GlacisClientOwnable} from "../../../contracts/client/GlacisClientOwnable.sol";
import {GlacisCommons} from "../../../contracts/commons/GlacisCommons.sol";

contract GlacisClientSample is GlacisClientOwnable {
    uint256 public value;

    constructor(
        address glacisRouter_,
        address owner_
    ) GlacisClientOwnable(glacisRouter_, 1, owner_) {}

    function setRemoteValue__execute(
        uint256 toChainId,
        bytes32 to,
        address adapter,
        bytes calldata payload
    ) external payable returns (bytes32) {
        return _routeSingle(toChainId, to, payload, adapter, msg.sender, msg.value);
    }

    function setRemoteValue__redundancy(
        uint256 toChainId,
        bytes32 to,
        address[] memory adapters,
        CrossChainGas[] memory fees,
        bytes calldata payload
    ) external payable returns (bytes32) {
        return
            _routeRedundant(
                toChainId,
                to,
                payload,
                adapters,
                fees,
                msg.sender,
                msg.value
            );
    }

    function setRemoteValue__retryable(
        uint256 chainId,
        bytes32 to,
        address[] memory adapters,
        CrossChainGas[] memory fees,
        bytes memory payload
    ) external payable returns (bytes32,uint256) {
        return
            _route(
                chainId,
                to,
                payload,
                adapters,
                fees,
                msg.sender,
                true,
                msg.value
            );
    }

    function setRemoteValue(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        address[] memory adapters,
        CrossChainGas[] memory fees,
        address refundAddress,
        bool retryable,
        uint256 gasPayment
    ) external payable returns (bytes32,uint256 ) {
        return
            _route(
                chainId,
                to,
                payload,
                adapters,
                fees,
                refundAddress,
                retryable,
                gasPayment
            );
    }

    function setRemoteValue__retry(
        uint256 chainId,
        bytes32 to,
        address[] memory adapters,
        CrossChainGas[] memory fees,
        bytes memory payload,
        bytes32 messageId,
        uint256 nonce
    ) external payable returns (bytes32) {
        return
            _retryRoute(
                chainId,
                to,
                payload,
                adapters,
                fees,
                msg.sender,
                messageId,
                nonce,
                msg.value
            );
    }

    event ValueChanged(uint256 indexed value);

    function _receiveMessage(
        address[] memory, // fromGmpId,
        uint256, // fromChainId,
        bytes32, // fromAddress,
        bytes memory payload
    ) internal override {
        // NOTE: changed += to test for redundant messages
        if (payload.length > 0) (value) += abi.decode(payload, (uint256));
    }

    // Setup of custom quorum (for testing purposes)

    uint256 internal customQuorum = 1;

    function setQuorum(uint256 q) external onlyOwner {
        customQuorum = q;
    }

    function getQuorum(
        GlacisCommons.GlacisData memory,
        bytes memory,
        uint256
    ) public view override returns (uint256) {
        return customQuorum;
    }
}
