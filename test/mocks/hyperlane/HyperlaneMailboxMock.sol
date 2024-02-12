// SPDX-License-Identifier: ApacheV2
pragma solidity 0.8.18;
import {MockMailbox} from "@hyperlane-xyz/core/contracts/mock/MockMailbox.sol";

contract HyperlaneMailboxMock is MockMailbox {
    constructor() MockMailbox(uint32(block.chainid)) {
        remoteMailboxes[uint32(block.chainid)] = MockMailbox(address(this));
    }

    function execute() public {
        remoteMailboxes[uint32(block.chainid)].processNextInboundMessage();
    }
}
