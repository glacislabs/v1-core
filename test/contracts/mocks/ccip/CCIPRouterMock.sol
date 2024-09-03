// SPDX-License-Identifier: ApacheV2
pragma solidity ^0.8.18;
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";

contract CCIPRouterMock {
    uint256 public nonce;
    /// @notice Request a message to be sent to the destination chain
    /// @param message The cross-chain CCIP message including data and/or tokens
    /// @return messageId The message ID
    /// @dev Note if msg.value is larger than the required fee (from getFee) we accept
    /// the overpayment with no refund.
    /// @dev Reverts with appropriate reason upon invalid message.
    function ccipSend(
        uint64, // destinationChainSelector,
        Client.EVM2AnyMessage calldata message
    ) external payable returns (bytes32 messageId) {
        Client.EVMTokenAmount[] memory tokens = new Client.EVMTokenAmount[](0);
        nonce += 1;
        messageId = keccak256(abi.encode(message.data, nonce));
        IAny2EVMMessageReceiver(
            address(abi.decode(message.receiver, (address)))
        ).ccipReceive(
                Client.Any2EVMMessage(
                    messageId,
                    uint64(block.chainid),
                    abi.encode(msg.sender),
                    message.data,
                    tokens
                )
            );
    }

    function getFee(
        uint64,
        Client.EVM2AnyMessage calldata data
    ) external pure returns (uint256 fee) {
        bytes memory extraArgs = data.extraArgs;
        uint256 gasLimit;
        assembly {
            gasLimit := mload(add(extraArgs, 36))
        }
        return gasLimit * 1000 + 21000;
    }
}
