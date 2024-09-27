// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import {GlacisRouter} from "../contracts/routers/GlacisRouter.sol";
import {GlacisTokenMediator} from "../contracts/mediators/GlacisTokenMediator.sol";
import {GlacisCommons} from "../contracts/commons/GlacisCommons.sol";
import {AddressBytes32} from "../contracts/libraries/AddressBytes32.sol";
import {AxelarGatewayMock} from "./contracts/mocks/axelar/AxelarGatewayMock.sol";
import {AxelarGasServiceMock} from "./contracts/mocks/axelar/AxelarGasServiceMock.sol";
import {LayerZeroV2Mock} from "./contracts/mocks/lz/LayerZeroV2Mock.sol";
import {WormholeRelayerMock} from "./contracts/mocks/wormhole/WormholeRelayerMock.sol";
import {CCIPRouterMock} from "./contracts/mocks/ccip/CCIPRouterMock.sol";
import {HyperlaneMailboxMock} from "./contracts/mocks/hyperlane/HyperlaneMailboxMock.sol";
import {GlacisAxelarAdapter} from "../contracts/adapters/GlacisAxelarAdapter.sol";
import {GlacisLayerZeroV2Adapter} from "../contracts/adapters/LayerZero/GlacisLayerZeroV2Adapter.sol";
import {GlacisWormholeAdapter} from "../contracts/adapters/Wormhole/GlacisWormholeAdapter.sol";
import {GlacisHyperlaneAdapter} from "../contracts/adapters/GlacisHyperlaneAdapter.sol";
import {GlacisCCIPAdapter} from "../contracts/adapters/GlacisCCIPAdapter.sol";

// TODO: give all mocks a failure feature that allows to check for retries

contract GlacisMockSetup is GlacisCommons {
    using AddressBytes32 for address;
    using AddressBytes32 for bytes32;

    address public constant AXELAR_GMP_ID = address(1);
    address public constant LAYERZERO_GMP_ID = address(2);
    address public constant WORMHOLE_GMP_ID = address(3);
    address public constant CCIP_GMP_ID = address(4);
    address public constant HYPERLANE_GMP_ID = address(5);

    // glacisRouter
    GlacisRouter public glacisRouter;

    // Mediators
    // GlacisTokenMediator public glacisTokenMediator;

    // Mocks
    AxelarGatewayMock public axelarGatewayMock;
    AxelarGasServiceMock public axelarGasServiceMock;
    LayerZeroV2Mock public layerZeroMock;
    WormholeRelayerMock public wormholeRelayerMock;
    CCIPRouterMock public ccipMock;
    HyperlaneMailboxMock public hyperlaneMock;

    // Adapters
    GlacisAxelarAdapter public glacisAxelarAdapter;
    GlacisLayerZeroV2Adapter public glacisLayerZeroV2Adapter;
    GlacisWormholeAdapter public glacisWormholeAdapter;
    GlacisCCIPAdapter public glacisCCIPAdapter;
    GlacisHyperlaneAdapter public glacisHyperlaneAdapter;

    constructor() {
        glacisRouter = new GlacisRouter(address(this));
        // glacisTokenMediator = new GlacisTokenMediator();
    }

    /// Deploys and sets up a new adapter for Axelar
    function setupAxelar() external returns (GlacisAxelarAdapter adapter) {
        axelarGatewayMock = new AxelarGatewayMock();
        axelarGasServiceMock = new AxelarGasServiceMock();

        // Deploy adapter
        adapter = new GlacisAxelarAdapter(
            address(glacisRouter),
            address(axelarGatewayMock),
            address(axelarGasServiceMock),
            address(this)
        );
        glacisAxelarAdapter = adapter;

        // Add adapter to the glacisRouter
        glacisRouter.registerAdapter(uint8(uint160(AXELAR_GMP_ID)), address(adapter));

        // Adds a glacisId => axelar chain string configuration to the adapter
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        string[] memory axelarLabels = new string[](1);
        axelarLabels[0] = "Anvil";

        adapter.setGlacisChainIds(glacisIDs, axelarLabels);
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);
    }

    /// Deploys and sets up a new adapter for LayerZero
    function setupLayerZero() external returns (GlacisLayerZeroV2Adapter adapter) {
        layerZeroMock = new LayerZeroV2Mock();

        adapter = new GlacisLayerZeroV2Adapter(
            address(glacisRouter),
            address(layerZeroMock),
            address(this)
        );
        glacisLayerZeroV2Adapter = adapter;

        // Register lzID <-> glacisID
        uint32[] memory lzIDs = new uint32[](1);
        lzIDs[0] = layerZeroMock.getChainId();
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = uint32(block.chainid);
        adapter.setGlacisChainIds(glacisIDs, lzIDs);

        // Add self as a remote counterpart
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        // Register adapter in GlacisRouter
        glacisRouter.registerAdapter(uint8(uint160(LAYERZERO_GMP_ID)), address(adapter));
    }

    /// Deploys and sets up adapters for Wormhole
    function setupWormhole() external returns (GlacisWormholeAdapter adapter) {
        wormholeRelayerMock = new WormholeRelayerMock();

        adapter = new GlacisWormholeAdapter(
            glacisRouter,
            address(wormholeRelayerMock),
            uint16(block.chainid),
            address(this)
        );
        glacisWormholeAdapter = adapter;

        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        uint16[] memory wormholeIDs = new uint16[](1);
        wormholeIDs[0] = 1;

        adapter.setGlacisChainIds(glacisIDs, wormholeIDs);

        glacisRouter.registerAdapter(uint8(uint160(WORMHOLE_GMP_ID)), address(adapter));
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        return adapter;
    }

    /// Deploys and sets up adapters for Hyperlane
    function setupCCIP() external returns (GlacisCCIPAdapter adapter) {
        ccipMock = new CCIPRouterMock();

        adapter = new GlacisCCIPAdapter(
            address(glacisRouter),
            address(ccipMock),
            address(this)
        );
        glacisCCIPAdapter = adapter;

        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        uint64[] memory chainSelectors = new uint64[](1);
        chainSelectors[0] = uint64(block.chainid);

        adapter.setGlacisChainIds(glacisIDs, chainSelectors);
        glacisRouter.registerAdapter(uint8(uint160(CCIP_GMP_ID)), address(adapter));
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        return adapter;
    }

    /// Deploys and sets up adapters for Hyperlane
    function setupHyperlane() external returns (GlacisHyperlaneAdapter adapter) {
        hyperlaneMock = new HyperlaneMailboxMock();

        adapter = new GlacisHyperlaneAdapter(
            address(glacisRouter),
            address(hyperlaneMock),
            address(this)
        );
        glacisHyperlaneAdapter = adapter;

        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        uint32[] memory hyperlaneDomains = new uint32[](1);
        hyperlaneDomains[0] = uint32(block.chainid);

        adapter.setGlacisChainIds(glacisIDs, hyperlaneDomains);

        glacisRouter.registerAdapter(uint8(uint160(HYPERLANE_GMP_ID)), address(adapter));
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        return adapter;
    }
}
