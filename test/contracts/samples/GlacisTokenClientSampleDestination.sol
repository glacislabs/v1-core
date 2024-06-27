// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;
import {GlacisTokenClientOwnable} from "../../../contracts/client/GlacisTokenClientOwnable.sol";
import {GlacisCommons} from "../../../contracts/commons/GlacisCommons.sol";
import {XERC20} from "../../../contracts/token/XERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GlacisTokenClientSampleDestination is GlacisTokenClientOwnable {
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

    event ValueChanged(uint256 indexed value);

    function _receiveMessageWithTokens(
        address[] memory, // fromAdapters,
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
        bytes memory,
        uint256
    ) public view override returns (uint256) {
        return customQuorum;
    }
}
