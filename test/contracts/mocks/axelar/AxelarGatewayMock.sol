// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;
import {GlacisAxelarAdapter} from "../../../../contracts/adapters/GlacisAxelarAdapter.sol";
import {AddressString} from "../../../../contracts/libraries/AddressString.sol";
import {CheckSum} from "../../libraries/CheckSum.sol";

contract AxelarGatewayMock {
    using AddressString for string;
    using CheckSum for address;

    /// A function that mocks IAxelarGateway, calling the msg.sender on the same chain
    /// much gas contract interactions take on the destination chain.
    function callContract(
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload
    ) external {
        // Get the contract address
        string memory destAddrStr = destinationAddress[2:42]; // remove 0x
        address contractAddr = destAddrStr.toAddress();

        // For better GMP simulation, we use the checksummed address just like Axelar does.
        string memory fromAddr = msg.sender.toChecksumString();

        execute(contractAddr, destinationChain, fromAddr, payload);
    }

    function execute(
        address contractAddr,
        string calldata sourceChain,
        string memory sourceAddress,
        bytes calldata payload
    ) public {
        bytes32 commandId = 0;
        GlacisAxelarAdapter(contractAddr).execute(
            commandId,
            sourceChain,
            sourceAddress,
            payload
        );
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
