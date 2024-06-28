// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisAbstractAdapter} from "../../../contracts/adapters/GlacisAbstractAdapter.sol";
import {IGlacisRouter} from "../../../contracts/routers/GlacisRouter.sol";
import {GlacisCommons} from "../../../contracts/commons/GlacisCommons.sol";

contract CustomAdapterSample is GlacisAbstractAdapter {
    constructor(
        address glacisRouter_,
        address owner_
    ) GlacisAbstractAdapter(IGlacisRouter(glacisRouter_), owner_) {}


    function chainIsAvailable(uint256) public view virtual returns (bool) {
        return true;
    }

    function _sendMessage(
        uint256 toChainId,
        address,
        GlacisCommons.CrossChainGas memory,
        bytes memory payload
    ) internal override onlyGlacisRouter {
        GLACIS_ROUTER.receiveMessage(toChainId, payload);
    }
}
