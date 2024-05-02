// SPDX-License-Identifier: ApacheV2
pragma solidity 0.8.18;

import {Versioned} from "@hyperlane-xyz/core/contracts/upgrade/Versioned.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {Message} from "@hyperlane-xyz/core/contracts/libs/Message.sol";
import {IMessageRecipient} from "@hyperlane-xyz/core/contracts/interfaces/IMessageRecipient.sol";
import {IInterchainSecurityModule, ISpecifiesInterchainSecurityModule} from "@hyperlane-xyz/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {Mailbox} from "@hyperlane-xyz/core/contracts/Mailbox.sol";
import {IPostDispatchHook} from "@hyperlane-xyz/core/contracts/interfaces/hooks/IPostDispatchHook.sol";

import {TestIsm} from "@hyperlane-xyz/core/contracts/test/TestIsm.sol";
import {TestPostDispatchHook} from "@hyperlane-xyz/core/contracts/test/TestPostDispatchHook.sol";

contract HyperlaneMailboxMock is Mailbox {
    using Message for bytes;

    uint32 public inboundUnprocessedNonce = 0;
    uint32 public inboundProcessedNonce = 0;

    mapping(uint32 => HyperlaneMailboxMock) public remoteMailboxes;
    mapping(uint256 => bytes) public inboundMessages;

    constructor() Mailbox(31337) {
        TestIsm ism = new TestIsm();
        defaultIsm = ism;

        TestPostDispatchHook hook = new TestPostDispatchHook();
        defaultHook = hook;
        requiredHook = hook;
        addRemoteMailbox(31337, this);
        _transferOwnership(msg.sender);
        _disableInitializers();
    }

    function addRemoteMailbox(
        uint32 _domain,
        HyperlaneMailboxMock _mailbox
    ) internal {
        remoteMailboxes[_domain] = _mailbox;
    }

    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody,
        bytes calldata metadata,
        IPostDispatchHook hook
    ) public payable override returns (bytes32) {
        bytes memory message = _buildMessage(
            destinationDomain,
            recipientAddress,
            messageBody
        );
        bytes32 id = super.dispatch(
            destinationDomain,
            recipientAddress,
            messageBody,
            metadata,
            hook
        );

        HyperlaneMailboxMock _destinationMailbox = remoteMailboxes[
            destinationDomain
        ];
        require(
            address(_destinationMailbox) != address(0),
            "Missing remote mailbox"
        );
        _destinationMailbox.addInboundMessage(message);
        processNextInboundMessage();

        return id;
    }

    function addInboundMessage(bytes calldata message) external {
        inboundMessages[inboundUnprocessedNonce] = message;
        inboundUnprocessedNonce++;
    }

    function processNextInboundMessage() public {
        bytes memory _message = inboundMessages[inboundProcessedNonce];
        Mailbox(address(this)).process("", _message);
        inboundProcessedNonce++;
    }
}