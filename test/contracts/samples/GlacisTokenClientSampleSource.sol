// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;
import {GlacisTokenClientOwnable} from "../../../contracts/client/GlacisTokenClientOwnable.sol";
import {GlacisCommons} from "../../../contracts/commons/GlacisCommons.sol";
import {XERC20} from "../../../contracts/token/XERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GlacisTokenClientSampleSource is GlacisTokenClientOwnable {
    uint256 public value;

    receive() external payable {}

    constructor(
        address XERC20Sample_,
        address ERC20Sample_,
        address XERC20LockboxSample_,
        address glacisTokenMediator_,
        address glacisRouter_,
        address owner_
    ) GlacisTokenClientOwnable(glacisTokenMediator_, glacisRouter_, 0, owner_) {
        XERC20(XERC20Sample_).approve(glacisTokenMediator_, 10e18);
        ERC20(ERC20Sample_).approve(XERC20LockboxSample_, 10e18);
    }

    function sendMessageAndTokens__abstract(
        uint256 toChainId,
        bytes32 to,
        uint8 gmp,
        bytes memory payload,
        address token,
        uint256 amount
    ) external payable returns (bytes32) {
        return
            _routeWithTokensSingle(
                toChainId,
                to,
                payload,
                gmp,
                msg.sender,
                token,
                amount,
                msg.value
            );
    }

    function sendMessageAndTokens__redundant(
        uint256 toChainId,
        bytes32 to,
        uint8[] memory gmps,
        uint256[] memory fees,
        bytes memory payload,
        address token,
        uint256 amount
    ) external payable returns (bytes32) {
        return
            _routeWithTokensRedundant(
                toChainId,
                to,
                payload,
                gmps,
                fees,
                msg.sender,
                token,
                amount,
                msg.value
            );
    }

    function sendMessageAndTokens__retriable(
        uint256 chainId,
        address to,
        uint8[] memory gmps,
        uint256[] memory fees,
        bytes memory payload,
        address token,
        uint256 amount
    ) external payable returns (bytes32) {
        return
            _routeWithTokens(
                chainId,
                to,
                payload,
                gmps,
                fees,
                msg.sender,
                token,
                amount,
                msg.value
            );
    }

    function retrySendWithTokens(
        uint256 chainId,
        bytes32 to,
        uint8[] calldata gmps,
        uint256[] calldata fees,
        bytes calldata payload,
        address token,
        uint256 amount,
        bytes32 messageId,
        uint256 nonce
    ) external payable returns (bytes32) {
        return
            _retryRouteWithTokens(
                chainId,
                to,
                payload,
                gmps,
                fees,
                msg.sender,
                messageId,
                nonce,
                token,
                amount,
                msg.value
            );
    }

    event ValueChanged(uint256 indexed value);

    function _receiveMessageWithTokens(
        uint8[] memory, // fromGmpId,
        uint256, // fromChainId,
        bytes32, // fromAddress,
        bytes memory payload,
        address, // token,
        uint256 // amount
    ) internal override {
        if (payload.length > 0) (value) += abi.decode(payload, (uint256));
        emit ValueChanged(value);
    }

    // Setup of custom quorum (for testing purposes)

    uint256 internal customQuorum = 1;

    function setQuorum(uint256 q) external onlyOwner {
        customQuorum = q;
    }

    function getQuorum(
        GlacisCommons.GlacisData memory,
        bytes memory
    ) public view override returns (uint256) {
        return customQuorum;
    }
}
