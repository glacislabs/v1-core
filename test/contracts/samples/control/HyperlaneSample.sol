// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import {StandardHookMetadata} from "@hyperlane-xyz/core/contracts/hooks/libs/StandardHookMetadata.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {IInterchainSecurityModule} from "@hyperlane-xyz/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {IPostDispatchHook} from "@hyperlane-xyz/core/contracts/interfaces/hooks/IPostDispatchHook.sol";

contract HyperlaneSample {
    uint256 public value;
    
    IInterchainSecurityModule public interchainSecurityModule;
    IMailbox public immutable MAIL_BOX;
    uint32 public immutable LOCAL_DOMAIN;
    
    constructor(
        address hyperlaneMailbox_
    ) {
        MAIL_BOX = IMailbox(hyperlaneMailbox_);
        LOCAL_DOMAIN = MAIL_BOX.localDomain();
    }

    function setRemoteValue(
        uint16 destinationChainId,
        address destinationAddress,
        bytes calldata payload
    ) external payable {
        // Send message across chains
        MAIL_BOX.dispatch{value: 1}(
            destinationChainId,
            bytes32(uint256(uint160(destinationAddress))),
            payload
        );
    }

    function handle(
        uint32, //_origin
        bytes32, // _sender
        bytes calldata _message
    )
        external
        payable
    {
        if (_message.length > 0) (value) += abi.decode(_message, (uint256));
    }

}
