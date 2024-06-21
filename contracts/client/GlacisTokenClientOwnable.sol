// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisTokenClient} from "./GlacisTokenClient.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {GlacisCommons} from "../commons/GlacisCommons.sol";

/// @title Glacis Ownable Token Client
/// @dev This contract encapsulates Glacis Token PAssing client logic, contracts inheriting this will have access to all
/// Glacis Token Passing and Message Passing features
/// @notice This contract is Ownable
abstract contract GlacisTokenClientOwnable is GlacisTokenClient, Ownable {
    constructor(
        address glacisTokenMediator_,
        address glacisRouter_,
        uint256 quorum,
        address owner_
    ) GlacisTokenClient(glacisTokenMediator_, glacisRouter_, quorum) {
        _transferOwnership(owner_);
    }

    /// @notice Add an allowed route for this client
    /// @param allowedRoute Route to be added
    function addAllowedRoute(
        GlacisCommons.GlacisRoute memory allowedRoute
    ) external onlyOwner {
        _addAllowedRoute(allowedRoute);
    }

    /// @notice Removes an allowed route for this client
    /// @param route Allowed route to be removed
    function removeAllowedRoute(
        GlacisCommons.GlacisRoute calldata route
    ) external onlyOwner {
        _removeAllowedRoute(route);
    }
}
