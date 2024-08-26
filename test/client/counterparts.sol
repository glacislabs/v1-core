// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroV2Mock, GlacisLayerZeroV2Adapter, WormholeRelayerMock, GlacisWormholeAdapter, CCIPRouterMock, GlacisCCIPAdapter, HyperlaneMailboxMock, GlacisHyperlaneAdapter} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {GlacisRemoteCounterpartManager__CounterpartsAndChainIDsMustHaveSameLength, GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero} from "../../contracts/managers/GlacisRemoteCounterpartManager.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";

/* solhint-disable contract-name-camelcase */
contract CounterpartManagerTests is LocalTestSetup {
    using AddressBytes32 for address;
    using AddressBytes32 for bytes32;
    LayerZeroV2Mock internal lzGatewayMock;
    GlacisLayerZeroV2Adapter internal adapter;
    GlacisRouter internal glacisRouter;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (lzGatewayMock) = deployLayerZeroFixture();
        adapter = deployLayerZeroAdapters(glacisRouter, lzGatewayMock);
    }

    function test__RemoteCounterparts_ArraysMustBeSameLength() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = block.chainid;
        bytes32[] memory adapterCounterparts = new bytes32[](2);
        adapterCounterparts[0] = address(adapter).toBytes32();
        vm.expectRevert(
            GlacisRemoteCounterpartManager__CounterpartsAndChainIDsMustHaveSameLength
                .selector
        );
        adapter.addRemoteCounterparts(glacisChainIds, adapterCounterparts);
    }

    function test__RemoteCounterparts_RemoteCounterpartCannotHaveChainIdZero_Add()
        external
    {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 0;
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        vm.expectRevert(
            GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero
                .selector
        );
        adapter.addRemoteCounterparts(glacisChainIds, adapterCounterparts);
    }

    function test__RemoteCounterparts_RemoteCounterpartCannotHaveChainIdZero_Remove()
        external
    {
        vm.expectRevert(
            GlacisRemoteCounterpartManager__RemoteCounterpartCannotHaveChainIdZero
                .selector
        );
        adapter.removeRemoteCounterpart(0);
    }

    function test__RemoteCounterparts_Get() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisChainIds, adapterCounterparts);
        adapter.getRemoteCounterpart(glacisChainIds[0]);
        assertEq(
            adapter.getRemoteCounterpart(glacisChainIds[0]),
            address(adapter).toBytes32()
        );
    }
}
