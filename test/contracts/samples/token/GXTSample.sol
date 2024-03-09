// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;
import {XERC20} from "../../../../contracts/token/XERC20.sol";
import {GlacisCrossChainToken} from "../../../../contracts/token/GlacisCrossChainToken.sol";

contract GXTSample is GlacisCrossChainToken {
    constructor(address owner_) GlacisCrossChainToken("GXT Sample", "SAMPLE_GXT", owner_) {
        _mint(owner_, 10 ** 18);
    }
}
