// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroV2Mock, GlacisLayerZeroV2Adapter, WormholeRelayerMock, GlacisWormholeAdapter} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {GlacisClientTextSample} from "../contracts/samples/GlacisClientTextSample.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";
import {CustomAdapterSample} from "../contracts/samples/CustomAdapterSample.sol";
import "forge-std/console.sol";

/* solhint-disable contract-name-camelcase */
contract OwnableTests is LocalTestSetup {
    using AddressBytes32 for address;

    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
    }

    function test__Ownable(address newOwner) external {
        vm.assume(newOwner != address(0));
        clientSample.transferOwnership(newOwner);
        assertEq(clientSample.owner(), newOwner);
    }

    function test__Ownable_ZeroAddress() external {
        vm.expectRevert("Ownable: new owner is the zero address");
        clientSample.transferOwnership(address(0));
    }
}
