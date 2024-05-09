// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisClient} from "./GlacisClient.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {GlacisCommons} from "../commons/GlacisCommons.sol";

/// @title Glacis Ownable Client
/// @dev This contract encapsulates Glacis client side logic, contracts inheriting this will have access to all
/// Glacis features  
/// @notice This contract is ownable  
abstract contract GlacisClientOwnable is GlacisClient, Ownable {

    /// @param _glacisRouter This chain's deployment of the GlacisRouter  
    /// @param _quorum The default quorum that you would like. If you implement dynamic quorum, this value can be ignored and 
    /// set to 0  
    /// @param _owner The owner of this contract  
    constructor(
        address _glacisRouter,
        uint256 _quorum,
        address _owner
    ) GlacisClient(_glacisRouter, _quorum) {
        _transferOwnership(_owner);
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

    /// @notice Removes all allowed routes for this client
    function removeAllAllowedRoutes() external onlyOwner {
        _removeAllAllowedRoutes();
    }

    /// @notice Adds a custom adapter for this client
    function addCustomAdapter(address adapter) external onlyOwner {
        _addCustomAdapter(adapter);
    }

    /// @notice Removes a specific custom adapter for this client
    function removeCustomAdapter(address adapter) external onlyOwner {
        _removeCustomAdapter(adapter);
    }
}
