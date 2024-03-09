
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {XERC20} from "./XERC20.sol";
import {GlacisRemoteCounterpartManager} from "../managers/GlacisRemoteCounterpartManager.sol";

contract GlacisCrossChainToken is XERC20, GlacisRemoteCounterpartManager {
    /**
     * @notice Constructs the initial config of the XERC20
     *
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param _factory The factory which deployed this contract
     */

    constructor(
        string memory _name,
        string memory _symbol,
        address _factory
    ) XERC20(_name, _symbol, _factory) {}

}
