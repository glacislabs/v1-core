// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;
import {GlacisAxelarAdapter} from "../../../../contracts/adapters/GlacisAxelarAdapter.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract AxelarOneWayGatewayMock {
    using Strings for address;

    /// A function that is meant to do nothing, helping tests figure out how
    /// much gas contract interactions take on the destination chain.
    function callContract(
        string calldata,
        string calldata,
        bytes calldata
    ) external {}

    /// Returns true to always validate the contract call (nearly 0 gas).
    function validateContractCall(
        bytes32,
        string memory,
        string memory,
        bytes32
    ) external pure returns (bool) {
        return true;
    }

    function callContractMock(
        address destination,
        bytes calldata payload
    ) external {
        GlacisAxelarAdapter(destination).execute(
            0,
            "Anvil",
            destination.toHexString(),
            payload
        );
    }
}
