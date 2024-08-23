// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;
import {XERC20} from "../../../../contracts/token/XERC20.sol";

contract XERC20Sample is XERC20 {
    constructor(address owner_) XERC20("Glacis xERC20 Sample Token", "GLACIS xERC20 SAMPLE", owner_) {
        _mint(owner_, 10 ** 18);
    }
}
