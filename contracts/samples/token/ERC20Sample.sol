// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20Sample is ERC20, Ownable {
    constructor(address owner_) ERC20("Legacy Sample Token", "LEGACY_SAMPLE") {
        transferOwnership(owner_);
        _mint(owner_, 10e18);
    }
}
