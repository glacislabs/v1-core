// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

/// @title IGlacisTokenMediator
/// @notice An interface of a mediator that sends XERC20s with a payload across chains  
interface IGlacisTokenMediator {
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
        bytes32 to,
        bytes memory payload,
        uint8[] memory gmps,
        address[] memory customAdapters,
        uint256[] memory fees,
        address refundAddress,
        address token,
        uint256 tokenAmount
    ) external payable returns (bytes32, uint256);

    function routeRetry(
        uint256 chainId,
        bytes32 to,
        bytes memory payload,
        uint8[] memory gmp,
        address[] memory customAdapters,
        uint256[] memory fees,
        address refundAddress,
        bytes32 messageId,
        uint256 nonce,
        address token,
        uint256 tokenAmount
    ) external payable returns (bytes32);
}
