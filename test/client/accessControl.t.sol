// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroV2Mock, GlacisLayerZeroV2Adapter, WormholeRelayerMock, GlacisWormholeAdapter} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";
import "forge-std/console.sol";

/* solhint-disable contract-name-camelcase */
contract AccessControlTests is LocalTestSetup {
    using AddressBytes32 for address;

     GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
    }

    function test__AccessControl_AddAllowedRoute(GlacisRoute calldata route_) external {
        vm.assume(route_.fromAdapter != address(0));
        vm.assume(route_.fromAddress != bytes32(0));
        vm.assume(route_.fromChainId != 0);
        clientSample.addAllowedRoute(route_);
        assertTrue(clientSample.isAllowedRoute(route_, ""));
    }

}
