// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

contract AxelarGasServiceMock {
    error AxelarGasServiceMock__RefundAddressDoesNotReceiveRefund();

    // This is called on the source chain before calling the gateway to execute a remote contract.
    function payNativeGasForContractCall(
        address, // sender,
        string calldata, // destinationChain,
        string calldata, // destinationAddress,
        bytes calldata, // payload,
        address refundAddress
    ) external payable {
        // Refund doesn't actually send in the same transaction, so it won't actually revert.
        // But it's good to test it out, since the gas service just banks the cash otherwise.
        // https://github.com/axelarnetwork/axelar-cgp-solidity/blob/0fb933430103c863e9804b790de5caa917f61fb1/contracts/gas-service/AxelarGasService.sol#L122C1-L130C6
        (bool success, ) = payable(refundAddress).call{value: msg.value}("");
        if (!success) {
            revert AxelarGasServiceMock__RefundAddressDoesNotReceiveRefund();
        }
    }
}
