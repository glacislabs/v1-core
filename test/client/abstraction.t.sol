// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroV2Mock, GlacisLayerZeroV2Adapter, WormholeRelayerMock, GlacisWormholeAdapter} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {GlacisClientTextSample} from "../contracts/samples/GlacisClientTextSample.sol";
import {AxelarOneWayGatewayMock} from "../contracts/mocks/axelar/AxelarOneWayGatewayMock.sol";
import {AxelarSample} from "../contracts/samples/control/AxelarSample.sol";
import {AxelarTextSample} from "../contracts/samples/control/AxelarTextSample.sol";
import {LayerZeroSample} from "../contracts/samples/control/LayerZeroSample.sol";
import {LayerZeroTextSample} from "../contracts/samples/control/LayerZeroTextSample.sol";
import {LayerZeroOneWayMock} from "../contracts/mocks/lz/LayerZeroOneWayMock.sol";
import {WormholeRelayerMock} from "../contracts/mocks/wormhole/WormholeRelayerMock.sol";
import {WormholeRelayerMock} from "../contracts/mocks/wormhole/WormholeRelayerMock.sol";
import {WormholeSample} from "../contracts/samples/control/WormholeSample.sol";
import {WormholeTextSample} from "../contracts/samples/control/WormholeTextSample.sol";
import {GlacisHyperlaneAdapter} from "../../contracts/adapters/GlacisHyperlaneAdapter.sol";
import {HyperlaneMailboxMock} from "../contracts/mocks/hyperlane/HyperlaneMailboxMock.sol";
import {GlacisCCIPAdapter} from "../../contracts/adapters/GlacisCCIPAdapter.sol";
import {CCIPRouterMock} from "../contracts/mocks/ccip/CCIPRouterMock.sol";
import {CCIPSample} from "../contracts/samples/control/CCIPSample.sol";
import {CCIPTextSample} from "../contracts/samples/control/CCIPTextSample.sol";
import {HyperlaneSample} from "../contracts/samples/control/HyperlaneSample.sol";
import {HyperlaneTextSample} from "../contracts/samples/control/HyperlaneTextSample.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";
import {CustomAdapterSample} from "../contracts/samples/CustomAdapterSample.sol";
import "forge-std/console.sol";

/* solhint-disable contract-name-camelcase */
contract AbstractionTests__Axelar is LocalTestSetup {
    using AddressBytes32 for address;

    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (axelarGatewayMock, axelarGasServiceMock) = deployAxelarFixture();
        axelarAdapter = deployAxelarAdapters(
            glacisRouter,
            axelarGatewayMock,
            axelarGasServiceMock
        );
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
    }

    function test__Abstraction_Axelar(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            AXELAR_GMP_ID,
            abi.encode(val)
        );
        assertEq(clientSample.value(), val);
    }

    function test__RefundAddress_Axelar() external {
        address randomRefundAddress = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        assertEq(randomRefundAddress.balance, 0);

        address[] memory gmps = new address[](1);
        gmps[0] = AXELAR_GMP_ID;
        clientSample.setRemoteValue{value: 1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(0),
            gmps,
            createFees(1 ether, 1),
            randomRefundAddress,
            false,
            1 ether
        );

        assertEq(randomRefundAddress.balance, 1 ether);
    }

    receive() external payable {}
}

contract AbstractionTests__LayerZero is LocalTestSetup {
    using AddressBytes32 for address;

    LayerZeroV2Mock internal lzGatewayMock;
    GlacisLayerZeroV2Adapter internal lzAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (lzGatewayMock) = deployLayerZeroFixture();
        lzAdapter = deployLayerZeroAdapters(glacisRouter, lzGatewayMock);
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
    }

    function test__Abstraction_LayerZero(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            LAYERZERO_GMP_ID,
            abi.encode(val)
        );

        assertEq(clientSample.value(), val);
    }

    function test__RefundAddress_LayerZero() external {
        address randomRefundAddress = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        assertEq(randomRefundAddress.balance, 0);

        address[] memory gmps = new address[](1);
        gmps[0] = LAYERZERO_GMP_ID;
        clientSample.setRemoteValue{value: 1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(0),
            gmps,
            createFees(1 ether, 1),
            randomRefundAddress,
            false,
            1 ether
        );

        assertEq(randomRefundAddress.balance, 1 ether);
    }

    receive() external payable {}
}

contract AbstractionTests__Wormhole is LocalTestSetup {
    using AddressBytes32 for address;

    WormholeRelayerMock internal wormholeRelayerMock;
    GlacisWormholeAdapter internal wormholeAdapter;

    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (wormholeRelayerMock) = deployWormholeFixture();
        wormholeAdapter = deployWormholeAdapter(
            glacisRouter,
            wormholeRelayerMock, block.chainid
        );
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
    }

    function test__Abstraction_Wormhole(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            WORMHOLE_GMP_ID,
            abi.encode(val)
        );

        assertEq(clientSample.value(), val);
    }

    function test__RefundAddress_Wormhole() external {
        address randomRefundAddress = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        assertEq(randomRefundAddress.balance, 0);

        address[] memory gmps = new address[](1);
        gmps[0] = WORMHOLE_GMP_ID;
        clientSample.setRemoteValue{value: 1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(0),
            gmps,
            createFees(1 ether, 1),
            randomRefundAddress,
            false,
            1 ether
        );

        assertEq(randomRefundAddress.balance, 1 ether);
    }

    receive() external payable {}
}

contract AbstractionTests__Hyperlane is LocalTestSetup {
    using AddressBytes32 for address;

    HyperlaneMailboxMock internal hyperlaneMailboxMock;
    GlacisHyperlaneAdapter internal hyperlaneAdapter;

    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (hyperlaneMailboxMock) = deployHyperlaneFixture();
        hyperlaneAdapter = deployHyperlaneAdapter(
            glacisRouter,
            hyperlaneMailboxMock
        );
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
    }

    function test__Abstraction_Hyperlane(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            HYPERLANE_GMP_ID,
            abi.encode(val)
        );

        assertEq(clientSample.value(), val);
    }

    function test__RefundAddress_Wormhole() external {
        address randomRefundAddress = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        assertEq(randomRefundAddress.balance, 0);

        address[] memory gmps = new address[](1);
        gmps[0] = HYPERLANE_GMP_ID;
        clientSample.setRemoteValue{value: 1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(0),
            gmps,
            createFees(1 ether, 1),
            randomRefundAddress,
            false,
            1 ether
        );

        assertEq(randomRefundAddress.balance, 1 ether);
    }

    receive() external payable {}
}

contract AbstractionTests__CCIP is LocalTestSetup {
    using AddressBytes32 for address;

    CCIPRouterMock internal ccipMock;
    GlacisCCIPAdapter internal ccipAdapter;

    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (ccipMock) = deployCCIPFixture();
        ccipAdapter = deployCCIPAdapter(glacisRouter, ccipMock);
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
    }

    function test__Abstraction_CCIP(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            CCIP_GMP_ID,
            abi.encode(val)
        );

        assertEq(clientSample.value(), val);
    }

    function test__RefundAddress_CCIP() external {
        address randomRefundAddress = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        assertEq(randomRefundAddress.balance, 0);

        address[] memory gmps = new address[](1);
        gmps[0] = CCIP_GMP_ID;
        clientSample.setRemoteValue{value: 1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(0),
            gmps,
            createFees(1 ether, 1),
            randomRefundAddress,
            false,
            1 ether
        );

        assertGt(randomRefundAddress.balance, 0);
    }

    receive() external payable {}
}

contract AbstractionTests__FullGasBenchmark is LocalTestSetup {
    using AddressBytes32 for address;

    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;
    GlacisClientTextSample internal clientTextSample;

    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;
    AxelarSample internal axelarSample;
    AxelarTextSample internal axelarTextSample;

    LayerZeroV2Mock internal lzEndpointMock;
    GlacisLayerZeroV2Adapter internal lzAdapter;
    LayerZeroSample internal lzSample;
    LayerZeroTextSample internal lzTextSample;

    WormholeRelayerMock internal wormholeRelayerMock;
    GlacisWormholeAdapter internal wormholeAdapter;
    WormholeSample internal wormholeSample;
    WormholeTextSample internal wormholeTextSample;

    CCIPRouterMock internal ccipRouterMock;
    GlacisCCIPAdapter internal ccipAdapter;
    CCIPSample internal ccipSample;
    CCIPTextSample internal ccipTextSample;

    HyperlaneMailboxMock internal hyperlaneMailboxMock;
    GlacisHyperlaneAdapter internal hyperlaneAdapter;
    HyperlaneSample internal hyperlaneSample;
    HyperlaneTextSample internal hyperlaneTextSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();

        // Uses one-way gateway mock to only find the gas on the send side & isolate gas
        (axelarGatewayMock, axelarGasServiceMock) = deployAxelarFixture();
        axelarAdapter = deployAxelarAdapters(
            glacisRouter,
            axelarGatewayMock,
            axelarGasServiceMock
        );
        axelarSample = new AxelarSample(
            address(axelarGatewayMock),
            address(axelarGasServiceMock)
        );
        axelarTextSample = new AxelarTextSample(
            address(axelarGatewayMock),
            address(axelarGasServiceMock)
        );
        (clientSample, clientTextSample) = deployGlacisClientSample(
            glacisRouter
        );

        (lzEndpointMock) = deployLayerZeroFixture();
        lzAdapter = deployLayerZeroAdapters(glacisRouter, lzEndpointMock);
        lzSample = new LayerZeroSample(address(lzEndpointMock));
        lzTextSample = new LayerZeroTextSample(address(lzEndpointMock));

        (wormholeRelayerMock) = deployWormholeFixture();
        wormholeAdapter = deployWormholeAdapter(
            glacisRouter,
            wormholeRelayerMock, block.chainid
        );
        wormholeSample = new WormholeSample(address(wormholeRelayerMock), 1);
        wormholeTextSample = new WormholeTextSample(
            address(wormholeRelayerMock),
            1
        );

        (ccipRouterMock) = deployCCIPFixture();
        ccipAdapter = deployCCIPAdapter(glacisRouter, ccipRouterMock);
        ccipSample = new CCIPSample(address(ccipRouterMock));
        ccipTextSample = new CCIPTextSample(address(ccipRouterMock));

        (hyperlaneMailboxMock) = deployHyperlaneFixture();
        hyperlaneAdapter = deployHyperlaneAdapter(
            glacisRouter,
            hyperlaneMailboxMock
        );
        hyperlaneSample = new HyperlaneSample(address(hyperlaneMailboxMock));
        hyperlaneTextSample = new HyperlaneTextSample(address(hyperlaneMailboxMock));
    }

    function test_gas__Axelar_Int_Glacis(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            AXELAR_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__Axelar_Str_Glacis(string memory val) external {
        clientTextSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientTextSample).toBytes32(),
            AXELAR_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__Axelar_Int_Control(bytes memory val) external {
        axelarSample.setRemoteValue{value: 0.1 ether}(
            "Anvil",
            address(axelarSample),
            abi.encode(val)
        );
    }

    function test_gas__Axelar_Str_Control(string memory val) external {
        axelarTextSample.setRemoteValue{value: 0.1 ether}(
            "Anvil",
            address(axelarTextSample),
            abi.encode(val)
        );
    }

    function test_gas__LayerZero_Int_Glacis(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            LAYERZERO_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__LayerZero_Str_Glacis(string memory val) external {
        clientTextSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientTextSample).toBytes32(),
            LAYERZERO_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__LayerZero_Int_Control(uint256 val) external {
        lzSample.setRemoteValue{value: 0.1 ether}(1, address(lzSample), abi.encode(val));
    }

    function test_gas__LayerZero_Str_Control(string memory val) external {
        lzTextSample.setRemoteValue{value: 0.1 ether}(1, address(lzSample),abi.encode(val));
    }

    function test_gas__Wormhole_Int_Glacis(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            WORMHOLE_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__Wormhole_Str_Glacis(string memory val) external {
        clientTextSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientTextSample).toBytes32(),
            WORMHOLE_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__Wormhole_Int_Control(uint256 val) external {
        wormholeSample.setRemoteValue{value: 0.1 ether}(
            uint16(block.chainid),
            address(wormholeSample),
            abi.encode(val)
        );
    }

    function test_gas__Wormhole_Str_Control(string memory val) external {
        wormholeTextSample.setRemoteValue{value: 0.1 ether}(
            uint16(block.chainid),
            address(wormholeSample),
            abi.encode(val)
        );
    }

    function test_gas__CCIP_Int_Control(uint256 val) external {
        ccipSample.setRemoteValue{value: 0.1 ether}(
            uint16(block.chainid),
            address(ccipSample),
            abi.encode(val)
        );
    }

    function test_gas__CCIP_Int_Glacis(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            CCIP_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__CCIP_Str_Control(string memory val) external {
        ccipTextSample.setRemoteValue{value: 0.1 ether}(
            uint16(block.chainid),
            address(ccipTextSample),
            abi.encode(val)
        );
    }

    function test_gas__CCIP_Str_Glacis(string memory val) external {
        clientTextSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientTextSample).toBytes32(),
            CCIP_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__Hyperlane_Int_Control(uint256 val) external {
        hyperlaneSample.setRemoteValue{value: 0.1 ether}(
            uint16(block.chainid),
            address(hyperlaneSample),
            abi.encode(val)
        );
    }

    function test_gas__Hyperlane_Int_Glacis(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            HYPERLANE_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__Hyperlane_Str_Control(string memory val) external {
        hyperlaneSample.setRemoteValue{value: 0.1 ether}(
            uint16(block.chainid),
            address(hyperlaneSample),
            abi.encode(val)
        );
    }

    function test_gas__Hyperlane_Str_Glacis(string memory val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            HYPERLANE_GMP_ID,
            abi.encode(val)
        );
    }

    receive() external payable {}
}
