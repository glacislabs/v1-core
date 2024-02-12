// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;
import {GlacisAxelarAdapter} from "../../../contracts/adapters/GlacisAxelarAdapter.sol";
import {AddressString} from "../../../contracts/libraries/AddressString.sol";
import {CheckSum} from "../../../contracts/libraries/CheckSum.sol";

contract AxelarRetryGatewayMock {
    mapping(bytes32 => bool) public calledInstances;
    using AddressString for string;
    using CheckSum for address;

    /// A function that mocks IAxelarGateway, calling the msg.sender on the same chain
    /// much gas contract interactions take on the destination chain.
    /// Will fail the first time to simulate the possibility of a message being sent.
    function callContract(
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload
    ) external {
        bytes32 internalID = keccak256(
            abi.encode(destinationChain, destinationAddress, payload)
        );
        if (calledInstances[internalID]) {
            bytes32 commandId = 0;

            // Get the contract address
            string memory contractAddrStr = destinationAddress[2:42]; // remove 0x
            address contractAddr = contractAddrStr.toAddress();

            // For better GMP simulation, we use the checksummed address just like Axelar does.
            string memory fromAddr = string(
                abi.encodePacked("0x", msg.sender.getChecksum())
            );

            GlacisAxelarAdapter(contractAddr).execute(
                commandId,
                destinationChain,
                fromAddr,
                payload
            );
        } else {
            calledInstances[internalID] = true;
        }
    }

    /// Returns true to always validate the contract call (nearly 0 gas).
    function validateContractCall(
        bytes32,
        string memory,
        string memory,
        bytes32
    ) external pure returns (bool) {
        return true;
    }
}
