// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { OApp } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";


contract MyOApp is OApp {
    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) Ownable2Step(_owner) {}

    // ... rest of OApp interface functions
}