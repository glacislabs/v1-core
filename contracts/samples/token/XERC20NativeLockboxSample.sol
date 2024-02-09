// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;
import {XERC20Lockbox} from "../../../../contracts/token/XERC20Lockbox.sol";

contract XERC20NativeLockboxSample is XERC20Lockbox {
    constructor(
        address _xerc20,
        address _erc20,
        bool _isNative,
        address owner_
    ) XERC20Lockbox(_xerc20, _erc20, true) {}
}
