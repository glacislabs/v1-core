// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {IXReceiver} from "@connext/interfaces/core/IXReceiver.sol";

contract ConnextMock {
    function xcall(
        uint32, // _destination
        address _to,
        address, // _asset
        address, // _delegate
        uint256, // _amount
        uint256, // _slippage
        bytes calldata _callData
    ) external payable returns(bytes32 id) {
        id = keccak256(abi.encode(_to, msg.sender, block.number));
        IXReceiver(_to).xReceive(
            id, 
            0, 
            address(0), 
            msg.sender, 
            uint32(block.chainid), 
            _callData
        );
    }
}
