// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisCommons} from "../commons/GlacisCommons.sol";

abstract contract IGlacisRouterEvents is GlacisCommons
{
    event GlacisAbstractRouter__MessageIdCreated(
        bytes32 indexed messageId,
        bytes32 indexed sender,
        uint256 nonce
    );
    event GlacisRouter__ReceivedMessage(
        bytes32 indexed messageId,
        bytes32 indexed from,
        uint256 indexed fromChainId,
        bytes32 to
    );
    event GlacisRouter__MessageDispatched(
        bytes32 indexed messageId,
        bytes32 indexed from,
        uint256 indexed toChainId,
        bytes32 to,
        bytes data,
        uint8[] gmps,
        uint256[] fees,
        address refundAddress,
        bool retriable
    );
    event GlacisRouter__MessageRetried(
        bytes32 indexed messageId,
        bytes32 indexed from,
        uint256 indexed toChainId,
        bytes32 to,
        bytes data,
        uint8[] gmps,
        uint256[] fees,
        address refundAddress
    );
}

interface IGlacisRouter {
    function route(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        uint8[] memory gmps,
        uint256[] memory fees,
        address refundAddress,
        bool retry
    ) external payable returns (bytes32);

    function routeRetry(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        uint8[] memory gmp,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce
    ) external payable returns (bytes32);

    function receiveMessage(
        uint256 fromChainId,
        bytes memory glacisPayload
    ) external;
}
