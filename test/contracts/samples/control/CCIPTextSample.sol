// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CCIPTextSample is CCIPReceiver {
    string public value;

    constructor(address ccipRouter_) CCIPReceiver(ccipRouter_) {}

    function setRemoteValue(
        uint64 destinationChainId,
        address destinationAddress,
        bytes memory payload
    ) external payable {
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(destinationAddress),
            data: payload,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 1_000_000}) 
            ),
            feeToken: address(0)
        });

        IRouterClient router = IRouterClient(this.getRouter());

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(destinationChainId, evm2AnyMessage);

        // Send the CCIP message through the router and store the returned CCIP message ID
        router.ccipSend{value: fees}(destinationChainId, evm2AnyMessage);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        value = abi.decode(any2EvmMessage.data, (string));
    }
}
