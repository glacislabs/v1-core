// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

/* solhint-disable no-console  */
// solhint-disable-next-line no-global-import
import "forge-std/console.sol";

import {Test} from "forge-std/Test.sol";
import {GlacisRouter} from "../contracts/routers/GlacisRouter.sol";
import {AxelarGatewayMock} from "./contracts/mocks/axelar/AxelarGatewayMock.sol";
import {AxelarRetryGatewayMock} from "./contracts/mocks/axelar/AxelarRetryGatewayMock.sol";
import {AxelarGasServiceMock} from "./contracts/mocks/axelar/AxelarGasServiceMock.sol";
import {LayerZeroGMPMock} from "./contracts/mocks/lz/LayerZeroMock.sol";
import {LayerZeroV2Mock} from "./contracts/mocks/lz/LayerZeroV2Mock.sol";
import {GlacisAxelarAdapter} from "../contracts/adapters/GlacisAxelarAdapter.sol";
import {GlacisLayerZeroAdapter} from "../contracts/adapters/LayerZero/GlacisLayerZeroAdapter.sol";
import {GlacisLayerZeroV2Adapter} from "../contracts/adapters/LayerZero/GlacisLayerZeroV2Adapter.sol";
import {GlacisClientSample} from "./contracts/samples/GlacisClientSample.sol";
import {GlacisClientTextSample} from "./contracts/samples/GlacisClientTextSample.sol";
import {GlacisDAOSample} from "./contracts/samples/GlacisDAOSample.sol";
import {WormholeRelayerMock} from "./contracts/mocks/wormhole/WormholeRelayerMock.sol";
import {GlacisWormholeAdapter} from "../contracts/adapters/Wormhole/GlacisWormholeAdapter.sol";
import {GlacisConnextAdapter} from "../contracts/adapters/GlacisConnextAdapter.sol";
import {ConnextMock} from "./contracts/mocks/connext/ConnextMock.sol";
import {GlacisCommons} from "../contracts/commons/GlacisCommons.sol";
import {GlacisTokenMediator} from "../contracts/mediators/GlacisTokenMediator.sol";
import {XERC20Sample} from "./contracts/samples/token/XERC20Sample.sol";
import {ERC20Sample} from "./contracts/samples/token/ERC20Sample.sol";
import {XERC20LockboxSample} from "./contracts/samples/token/XERC20LockboxSample.sol";
import {XERC20NativeLockboxSample} from "./contracts/samples/token/XERC20NativeLockboxSample.sol";
import {GlacisTokenClientSampleSource} from "./contracts/samples/GlacisTokenClientSampleSource.sol";
import {GlacisTokenClientSampleDestination} from "./contracts/samples/GlacisTokenClientSampleDestination.sol";
import {GlacisHyperlaneAdapter} from "../contracts/adapters/GlacisHyperlaneAdapter.sol";
import {HyperlaneMailboxMock} from "./contracts/mocks/hyperlane/HyperlaneMailboxMock.sol";
import {GlacisCCIPAdapter} from "../contracts/adapters/GlacisCCIPAdapter.sol";
import {CCIPRouterMock} from "./contracts/mocks/ccip/CCIPRouterMock.sol";
import {SimpleTokenMediator} from "../contracts/mediators/SimpleTokenMediator.sol";
import {AddressBytes32} from "../contracts/libraries/AddressBytes32.sol";

contract LocalTestSetup is Test, GlacisCommons {
    using AddressBytes32 for address;
    using AddressBytes32 for bytes32;

    address internal constant AXELAR_GMP_ID = address(1);
    address internal constant LAYERZERO_GMP_ID = address(2);
    address internal constant WORMHOLE_GMP_ID = address(3);
    address internal constant CCIP_GMP_ID = address(4);
    address internal constant HYPERLANE_GMP_ID = address(5);
    address internal constant CONNEXT_GMP_ID = address(6);

    constructor() {}

    function createFees(
        uint256 amount,
        uint256 size
    ) internal pure returns (CrossChainGas[] memory) {
        CrossChainGas[] memory fees = new CrossChainGas[](size);
        for (uint256 i; i < size; ++i) {
            fees[i] = CrossChainGas({ 
                gasLimit: 0,
                nativeCurrencyValue: uint128(amount)
            });
        }
        return fees;
    }

    /// Deploys a glacis router
    function deployGlacisRouter() internal returns (GlacisRouter glacisRouter) {
        glacisRouter = new GlacisRouter(address(this));
    }

    // region: Fixtures (Core Contracts)

    /// Deploys a mock Axelar gateway and gas service
    function deployAxelarFixture()
        internal
        returns (
            AxelarGatewayMock axelarGateway,
            AxelarGasServiceMock axelarGasService
        )
    {
        axelarGateway = new AxelarGatewayMock();
        axelarGasService = new AxelarGasServiceMock();
    }

    /// Deploys a mock Axelar gateway designed for testing retries
    function deployAxelarRetryFixture()
        internal
        returns (AxelarRetryGatewayMock mock)
    {
        return new AxelarRetryGatewayMock();
    }

    /// Deploys a mock LayerZero endpoint
    function deployLayerZeroFixture()
        internal
        returns (LayerZeroV2Mock layerZeroGMP)
    {
        layerZeroGMP = new LayerZeroV2Mock();
    }

    /// Deploys a mock Wormhole endpoint
    function deployWormholeFixture()
        internal
        returns (WormholeRelayerMock mock)
    {
        mock = new WormholeRelayerMock();
    }

    /// Deploys a mock CCIP endpoint
    function deployCCIPFixture() internal returns (CCIPRouterMock mock) {
        mock = new CCIPRouterMock();
    }

    /// Deploys a mock Hyperlane endpoint
    function deployHyperlaneFixture()
        internal
        returns (HyperlaneMailboxMock mock)
    {
        mock = new HyperlaneMailboxMock();
    }

    /// Deploys a mock Connext endpoint
    function deployConnextFixture() internal returns (ConnextMock mock) {
        mock = new ConnextMock();
    }

    // endregion

    // region: Adapters

    /// Deploys and sets up a new adapter for Axelar
    function deployAxelarAdapters(
        GlacisRouter router,
        AxelarGatewayMock gateway,
        AxelarGasServiceMock gasService
    ) internal returns (GlacisAxelarAdapter adapter) {
        // Deploy adapter
        adapter = new GlacisAxelarAdapter(
            address(router),
            address(gateway),
            address(gasService),
            address(this)
        );

        // Add adapter to the router
        router.registerAdapter(uint8(uint160(AXELAR_GMP_ID)), address(adapter));

        // Adds a glacisId => axelar chain string configuration to the adapter
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        string[] memory axelarLabels = new string[](1);
        axelarLabels[0] = "Anvil";

        adapter.setGlacisChainIds(glacisIDs, axelarLabels);
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        return adapter;
    }

    /// Deploys and sets up a new adapter for LayerZero
    function deployLayerZeroAdapters(
        GlacisRouter router,
        LayerZeroV2Mock lzEndpoint
    ) internal returns (GlacisLayerZeroV2Adapter adapter) {
        adapter = new GlacisLayerZeroV2Adapter(
            address(router),
            address(lzEndpoint),
            address(this)
        );

        // Register lzID <-> glacisID
        uint32[] memory lzIDs = new uint32[](1);
        lzIDs[0] = lzEndpoint.getChainId();
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = uint32(block.chainid);
        adapter.setGlacisChainIds(glacisIDs, lzIDs);

        // Add self as a remote counterpart
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        // Register adapter in GlacisRouter
        router.registerAdapter(uint8(uint160(LAYERZERO_GMP_ID)), address(adapter));
    }

    /// Deploys and sets up adapters for Wormhole
    function deployWormholeAdapter(
        GlacisRouter router,
        WormholeRelayerMock wormholeRelayer,
        uint256 wormholeChainId 
    ) internal returns (GlacisWormholeAdapter adapter) {
        adapter = new GlacisWormholeAdapter(
            router,
            address(wormholeRelayer),
            uint16(wormholeChainId),
            address(this)
        );

        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        uint16[] memory wormholeIDs = new uint16[](1);
        wormholeIDs[0] = 1;

        adapter.setGlacisChainIds(glacisIDs, wormholeIDs);

        router.registerAdapter(uint8(uint160(WORMHOLE_GMP_ID)), address(adapter));
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        return adapter;
    }

    /// Deploys and sets up adapters for Hyperlane
    function deployCCIPAdapter(
        GlacisRouter router,
        CCIPRouterMock mockCCIPRouter
    ) internal returns (GlacisCCIPAdapter adapter) {
        adapter = new GlacisCCIPAdapter(
            address(router),
            address(mockCCIPRouter),
            address(this)
        );

        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        uint64[] memory chainSelectors = new uint64[](1);
        chainSelectors[0] = uint64(block.chainid);

        adapter.setGlacisChainIds(glacisIDs, chainSelectors);
        router.registerAdapter(uint8(uint160(CCIP_GMP_ID)), address(adapter));
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        return adapter;
    }

    /// Deploys and sets up adapters for Hyperlane
    function deployHyperlaneAdapter(
        GlacisRouter router,
        HyperlaneMailboxMock mockMailbox
    ) internal returns (GlacisHyperlaneAdapter adapter) {
        adapter = new GlacisHyperlaneAdapter(
            address(router),
            address(mockMailbox),
            address(this)
        );

        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        uint32[] memory hyperlaneDomains = new uint32[](1);
        hyperlaneDomains[0] = uint32(block.chainid);

        adapter.setGlacisChainIds(glacisIDs, hyperlaneDomains);

        router.registerAdapter(uint8(uint160(HYPERLANE_GMP_ID)), address(adapter));
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        return adapter;
    }

    /// Deploys and sets up adapters for Connext
    function deployConnextAdapter(
        GlacisRouter router,
        ConnextMock mockConnext
    ) internal returns (GlacisConnextAdapter adapter) {
        adapter = new GlacisConnextAdapter(
            address(router),
            address(mockConnext),
            address(this)
        );

        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        uint32[] memory domains = new uint32[](1);
        domains[0] = uint32(block.chainid);

        adapter.setGlacisChainIds(glacisIDs, domains);

        router.registerAdapter(uint8(uint160(CONNEXT_GMP_ID)), address(adapter));
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        return adapter;
    }

    // endregion

    // region: Samples

    function deployGlacisClientSample(
        GlacisRouter router
    )
        internal
        returns (
            GlacisClientSample clientSample,
            GlacisClientTextSample clientTextSample
        )
    {
        clientSample = new GlacisClientSample(address(router), address(this));
        GlacisClientSample(clientSample).addAllowedRoute(
            GlacisRoute(
                block.chainid, // fromChainId
                address(clientSample).toBytes32(), // from
                address(WILDCARD) // fromGmpId
            )
        );
        clientTextSample = new GlacisClientTextSample(
            address(router),
            address(this)
        );
        GlacisClientTextSample(clientTextSample).addAllowedRoute(
            GlacisRoute(
                block.chainid, // fromChainId
                address(clientTextSample).toBytes32(), // from
                address(WILDCARD) // fromGmpId
            )
        );
    }


    function deployGlacisDAOSample(
        address[] memory members,
        GlacisRouter router,
        GlacisTokenMediator tokenRouter
    ) internal returns (GlacisDAOSample clientSample) {
        clientSample = new GlacisDAOSample(
            address[](members),
            address(tokenRouter),
            address(router),
            address(this)
        );
        GlacisDAOSample(clientSample).addAllowedRoute(
            GlacisCommons.GlacisRoute(
                block.chainid, // fromChainId
                address(clientSample).toBytes32(), // from
                address(WILDCARD) // fromGmpId
            )
        );
    }

    /// Deploys glacis token contracts
    function deployGlacisTokenFixture(
        GlacisRouter glacisRouter
    )
        internal
        returns (
            GlacisTokenMediator glacisTokenMediator,
            XERC20Sample xERC20Sample,
            ERC20Sample erc20Sample,
            XERC20LockboxSample xERC20LockboxSample,
            XERC20NativeLockboxSample xERC20NativeLockboxSample,
            GlacisTokenClientSampleSource glacisTokenClientSampleSource,
            GlacisTokenClientSampleDestination glacisTokenClientSampleDestination
        )
    {
        glacisTokenMediator = new GlacisTokenMediator(
            address(glacisRouter),
            1,
            address(this)
        );
        xERC20Sample = new XERC20Sample(address(this));
        erc20Sample = new ERC20Sample(address(this));
        xERC20LockboxSample = new XERC20LockboxSample(
            address(xERC20Sample),
            address(erc20Sample),
            false,
            address(this)
        );

        xERC20NativeLockboxSample = new XERC20NativeLockboxSample(
            address(xERC20Sample),
            address(erc20Sample),
            true,
            address(this)
        );

        glacisTokenClientSampleSource = new GlacisTokenClientSampleSource(
            address(xERC20Sample),
            address(erc20Sample),
            address(xERC20LockboxSample),
            address(glacisTokenMediator),
            address(glacisRouter),
            address(this)
        );
        glacisTokenClientSampleDestination = new GlacisTokenClientSampleDestination(
            address(xERC20Sample),
            address(erc20Sample),
            address(xERC20LockboxSample),
            address(glacisTokenMediator),
            address(glacisRouter),
            address(this)
        );
        glacisTokenClientSampleDestination.addAllowedRoute(
            GlacisCommons.GlacisRoute(
                block.chainid, // fromChainId
                address(glacisTokenClientSampleSource).toBytes32(), // from
                address(WILDCARD) // fromGmpId
            )
        );
        xERC20Sample.setLimits(address(glacisTokenMediator), 10e18, 10e18);
        xERC20Sample.setLimits(address(xERC20LockboxSample), 10e18, 10e18);
        xERC20Sample.setLimits(
            address(xERC20NativeLockboxSample),
            10e18,
            10e18
        );

        uint256[] memory chainIdArr = new uint256[](1);
        chainIdArr[0] = block.chainid;
        bytes32[] memory mediatorArr = new bytes32[](1);
        mediatorArr[0] = address(glacisTokenMediator).toBytes32();
        glacisTokenMediator.addRemoteCounterparts(chainIdArr, mediatorArr);
    }

    // endregion
}
