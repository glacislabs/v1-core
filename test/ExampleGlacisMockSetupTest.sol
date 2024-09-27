// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {GlacisMockSetup} from "./GlacisMockSetup.sol";
import {GlacisClientSample} from "./contracts/samples/GlacisClientSample.sol";
import {GlacisCommons} from "../contracts/commons/GlacisCommons.sol";
import {AddressBytes32} from "../contracts/libraries/AddressBytes32.sol";

contract ExampleGlacisMockSetupTest is Test, GlacisCommons {
    using AddressBytes32 for address;

    GlacisMockSetup mocks;
    address glacisRouter;

    GlacisClientSample sample;
    GlacisClientSample sample2;

    function setUp() public {
        // Create mock
        mocks = new GlacisMockSetup();
        glacisRouter = address(mocks.glacisRouter());

        // Create your client
        sample = new GlacisClientSample(glacisRouter, address(this));
        sample.addAllowedRoute(GlacisRoute(WILDCARD, bytes32(uint256(WILDCARD)), address(WILDCARD)));
        sample2 = new GlacisClientSample(glacisRouter, address(this));
        sample2.addAllowedRoute(GlacisRoute(WILDCARD, bytes32(uint256(WILDCARD)), address(WILDCARD)));
    }

    function test__MockSetupAxelar(uint256 payload) public {
        mocks.setupAxelar();

        sample.setRemoteValue__execute{ value: 1 ether }(
            block.chainid, 
            address(sample2).toBytes32(), 
            address(0x01), 
            abi.encode(payload)
        );
        assertEq(sample2.value(), payload);
    }

    function test__MockSetupLZ(uint256 payload) public {
        mocks.setupLayerZero();

        sample.setRemoteValue__execute{ value: 1 ether }(
            block.chainid, 
            address(sample2).toBytes32(), 
            address(0x02), 
            abi.encode(payload)
        );
        assertEq(sample2.value(), payload);
    }

    function test__MockSetupWormhole(uint256 payload) public {
        mocks.setupWormhole();

        sample.setRemoteValue__execute{ value: 1 ether }(
            block.chainid, 
            address(sample2).toBytes32(), 
            address(0x03), 
            abi.encode(payload)
        );
        assertEq(sample2.value(), payload);
    }

    // Fails
    function test__MockSetupCCIP(uint256 payload) public {
        mocks.setupCCIP();

        sample.setRemoteValue__execute{ value: 1 ether }(
            block.chainid, 
            address(sample2).toBytes32(), 
            address(0x04), 
            abi.encode(payload)
        );
        assertEq(sample2.value(), payload);
    }

    function test__MockSetupHyperlane(uint256 payload) public {
        mocks.setupHyperlane();

        sample.setRemoteValue__execute{ value: 1 ether }(
            block.chainid, 
            address(sample2).toBytes32(), 
            address(0x05), 
            abi.encode(payload)
        );
        assertEq(sample2.value(), payload);
    }

    receive() external payable {}
}
