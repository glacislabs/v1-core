// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

contract GlacisDeployableMock {
    uint256 public value;

    constructor(uint256 _value) {
        value = _value;
    }

    function setValue(uint256 _value) external {
        value = _value;
    }
}
