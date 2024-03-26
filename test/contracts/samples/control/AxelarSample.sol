// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract AxelarSample is AxelarExecutable {
    uint256 public value;

    IAxelarGasService public immutable GAS_SERVICE;

    // event Sent(string, string, string);
    // event Received(string, string, bytes);

    // Using this library because it is abnormal to use strings and will likely
    // be used by other developers.
    using Strings for address;

    constructor(
        address gateway_,
        address gasReceiver_
    ) AxelarExecutable(gateway_) {
        GAS_SERVICE = IAxelarGasService(gasReceiver_);
    }

    // Call this function to update the value of this contract along with all its siblings'.
    function setRemoteValue(
        string calldata destinationChain,
        address destinationAddress,
        bytes memory payload
    ) external payable {
        string memory addr = destinationAddress.toHexString();

        GAS_SERVICE.payNativeGasForContractCall{value: msg.value}(
            address(this),
            destinationChain,
            addr,
            payload,
            msg.sender
        );

        gateway.callContract(destinationChain, addr, payload);
        // emit Sent(destinationAddress, destinationChain, value_);
    }

    // Handles calls created by setAndSend. Updates this contract's value
    function _execute(
        string calldata,
        string calldata,
        bytes calldata payload_
    ) internal override {
        value = abi.decode(payload_, (uint256));
    }
}
