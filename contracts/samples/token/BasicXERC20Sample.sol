// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;
import {XERC20Basic} from "../../token/XERC20.sol";

contract BasicXERC20Sample is XERC20Basic {
    constructor(address owner_) XERC20Basic("Sample Token", "SAMPLE", owner_) {
        _mint(owner_, 10 ** 18);
    }
}
