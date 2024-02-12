// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

/* solhint-disable no-console  */
// solhint-disable-next-line no-global-import
import "forge-std/console.sol";

import {Test} from "forge-std/Test.sol";
import {GlacisRouter} from "../contracts/routers/GlacisRouter.sol";
import {AxelarGatewayMock} from "./mocks/axelar/AxelarGatewayMock.sol";
import {AxelarRetryGatewayMock} from "./mocks/axelar/AxelarRetryGatewayMock.sol";
import {AxelarGasServiceMock} from "./mocks/axelar/AxelarGasServiceMock.sol";
import {LayerZeroGMPMock} from "./mocks/lz/LayerZeroMock.sol";
import {GlacisAxelarAdapter} from "../contracts/adapters/GlacisAxelarAdapter.sol";
import {GlacisLayerZeroAdapter} from "../contracts/adapters/LayerZero/GlacisLayerZeroAdapter.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {GlacisClientTextSample} from "../contracts/samples/GlacisClientTextSample.sol";
import {GlacisDAOSample} from "../contracts/samples/GlacisDAOSample.sol";
import {WormholeRelayerMock} from "./mocks/wormhole/WormholeRelayerMock.sol";
import {GlacisWormholeAdapter} from "../contracts/adapters/Wormhole/GlacisWormholeAdapter.sol";
import {GlacisCommons} from "../contracts/commons/GlacisCommons.sol";
import {GlacisTokenMediator} from "../contracts/mediators/GlacisTokenMediator.sol";
import {XERC20Sample} from "../contracts/samples/token/XERC20Sample.sol";
import {ERC20Sample} from "../contracts/samples/token/ERC20Sample.sol";
import {XERC20LockboxSample} from "../contracts/samples/token/XERC20LockboxSample.sol";
import {XERC20NativeLockboxSample} from "../contracts/samples/token/XERC20NativeLockboxSample.sol";
import {GlacisTokenClientSampleSource} from "../contracts/samples/GlacisTokenClientSampleSource.sol";
import {GlacisTokenClientSampleDestination} from "../contracts/samples/GlacisTokenClientSampleDestination.sol";
import {GlacisHyperlaneAdapter} from "../contracts/adapters/GlacisHyperlaneAdapter.sol";
import {HyperlaneMailboxMock} from "./mocks/hyperlane/HyperlaneMailboxMock.sol";
import {GlacisCCIPAdapter} from "../contracts/adapters/GlacisCCIPAdapter.sol";
import {CCIPRouterMock} from "./mocks/ccip/CCIPRouterMock.sol";

contract LocalTestSetup is Test {
    uint8 internal constant AXELAR_GMP_ID = 1;
    uint8 internal constant LAYERZERO_GMP_ID = 2;
    uint8 internal constant WORMHOLE_GMP_ID = 3;
    uint8 internal constant CCIP_GMP_ID = 4;
    uint8 internal constant HYPERLANE_GMP_ID = 5;

    constructor() {}

    function createFees(
        uint256 amount,
        uint256 size
    ) internal pure returns (uint256[] memory) {
        uint256[] memory fees = new uint256[](size);
        for (uint256 i; i < size; ++i) {
            fees[i] = amount;
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
        returns (LayerZeroGMPMock layerZeroGMP)
    {
        layerZeroGMP = new LayerZeroGMPMock();
    }

    /// Deploys a mock Wormhole endpoint
    function deployWormholeFixture()
        internal
        returns (WormholeRelayerMock mock)
    {
        mock = new WormholeRelayerMock();
    }

    /// Deploys a mock Hyperlane endpoint
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
        router.registerAdapter(AXELAR_GMP_ID, address(adapter));

        // Adds a glacisId => axelar chain string configuration to the adapter
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        string[] memory axelarLabels = new string[](1);
        axelarLabels[0] = "Anvil";
        adapter.setGlacisChainIds(glacisIDs, axelarLabels);

        adapter.addRemoteAdapter(block.chainid, address(adapter));

        return adapter;
    }

    /// Deploys and sets up a new adapter for LayerZero
    function deployLayerZeroAdapters(
        GlacisRouter router,
        LayerZeroGMPMock lzEndpoint
    ) internal returns (GlacisLayerZeroAdapter adapter) {
        adapter = new GlacisLayerZeroAdapter(
            address(lzEndpoint),
            address(router),
            address(this)
        );

        uint16[] memory lzIDs = new uint16[](1);
        lzIDs[0] = 1;
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = uint16(block.chainid);
        adapter.setGlacisChainIds(glacisIDs, lzIDs);

        router.registerAdapter(LAYERZERO_GMP_ID, address(adapter));
        adapter.addRemoteAdapter(block.chainid, address(adapter));

        return adapter;
    }

    /// Deploys and sets up adapters for Wormhole
    function deployWormholeAdapter(
        GlacisRouter router,
        WormholeRelayerMock wormholeRelayer
    ) internal returns (GlacisWormholeAdapter adapter) {
        adapter = new GlacisWormholeAdapter(
            router,
            address(wormholeRelayer),
            1,
            address(this)
        );

        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        uint16[] memory wormholeIDs = new uint16[](1);
        wormholeIDs[0] = 1;

        adapter.setGlacisChainIds(glacisIDs, wormholeIDs);

        router.registerAdapter(WORMHOLE_GMP_ID, address(adapter));
        adapter.addRemoteAdapter(block.chainid, address(adapter));

        wormholeRelayer.setGlacisAdapter(address(adapter));

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

        adapter.setAdapterChains(glacisIDs, chainSelectors);
        router.registerAdapter(CCIP_GMP_ID, address(adapter));
        adapter.addRemoteAdapter(block.chainid, address(adapter));

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

        router.registerAdapter(HYPERLANE_GMP_ID, address(adapter));
        adapter.addRemoteAdapter(block.chainid, address(adapter));

        return adapter;
    }

    // endregion

    // region: Samples

    function deployGlacisClientSample(
        GlacisRouter router
    ) internal returns (GlacisClientSample clientSample) {
        clientSample = new GlacisClientSample(address(router), address(this));
        GlacisClientSample(clientSample).addAllowedRoute(
            GlacisCommons.GlacisRoute(
                block.chainid, // fromChainId
                address(clientSample), // from
                0 // fromGmpId
            )
        );
    }

    function deployGlacisClientTextSample(
        GlacisRouter router
    ) internal returns (GlacisClientTextSample clientTextSample) {
        clientTextSample = new GlacisClientTextSample(
            address(router),
            address(this)
        );
        GlacisClientTextSample(clientTextSample).addAllowedRoute(
            GlacisCommons.GlacisRoute(
                block.chainid, // fromChainId
                address(clientTextSample), // from
                0 // fromGmpId
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
                address(clientSample), // from
                0 // fromGmpId
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
                address(glacisTokenClientSampleSource), // from
                0 // fromGmpId
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
        address[] memory mediatorArr = new address[](1);
        mediatorArr[0] = address(glacisTokenMediator);
        glacisTokenMediator.addRemoteMediators(chainIdArr, mediatorArr);
    }

    // endregion
}
