// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {IMessageDispatcher} from "../interfaces/IMessageDispatcher.sol";
import {IMessageExecutor} from "../interfaces/IMessageExecutor.sol";

interface IGlacisTokenMediator is IMessageDispatcher, IMessageExecutor {
    event GlacisTokenMediator__TokensBurnt(
        address from,
        address token,
        uint256 amount
    );
    event GlacisTokenMediator__TokensMinted(
        address to,
        address token,
        uint256 amount
    );

    function route(
        uint256 chainId,
        address to,
        bytes memory payload,
        uint8[] memory gmps,
        uint256[] memory fees,
        address refundAddress,
        bool retry,
        address token,
        uint256 tokenAmount
    ) external payable returns (bytes32);

    function routeRetry(
        uint256 chainId,
        address to,
        bytes memory payload,
        uint8[] memory gmp,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce,
        address token,
        uint256 tokenAmount
    ) external payable returns (bytes32);
}
