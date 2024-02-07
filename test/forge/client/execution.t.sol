// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroGMPMock, GlacisLayerZeroAdapter} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../../contracts/samples/GlacisClientSample.sol";
import {GlacisClientTextSample} from "../../contracts/samples/GlacisClientTextSample.sol";
import {AxelarOneWayGatewayMock} from "../../contracts/mocks/axelar/AxelarOneWayGatewayMock.sol";
import {AxelarSample} from "../../contracts/samples/control/AxelarSample.sol";
import {AxelarTextSample} from "../../contracts/samples/control/AxelarTextSample.sol";
import {LayerZeroSample} from "../../contracts/samples/control/LayerZeroSample.sol";
import {LayerZeroTextSample} from "../../contracts/samples/control/LayerZeroTextSample.sol";
import {LayerZeroOneWayMock} from "../../contracts/mocks/lz/LayerZeroOneWayMock.sol";
import {WormholeRelayerMock} from "../../contracts/mocks/wormhole/WormholeRelayerMock.sol";
import {GlacisWormholeAdapter} from "../../../contracts/adapters/Wormhole/GlacisWormholeAdapter.sol";
import {GlacisHyperlaneAdapter} from "../../../contracts/adapters/GlacisHyperlaneAdapter.sol";
import {HyperlaneMailboxMock} from "../../contracts/mocks/hyperlane/HyperlaneMailboxMock.sol";
import {GlacisCCIPAdapter} from "../../../contracts/adapters/GlacisCCIPAdapter.sol";
import {CCIPRouterMock} from "../../contracts/mocks/ccip/CCIPRouterMock.sol";

/* solhint-disable contract-name-camelcase */
contract ExecutionTests__Axelar is LocalTestSetup {
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
        clientSample = deployGlacisClientSample(glacisRouter);
    }

    function test__Execution_Axelar(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample),
            AXELAR_GMP_ID,
            abi.encode(val)
        );
        assertEq(clientSample.value(), val);
    }

    function test__RefundAddress_Axelar() external {
        address randomRefundAddress = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        assertEq(randomRefundAddress.balance, 0);

        uint8[] memory gmps = new uint8[](1);
        gmps[0] = AXELAR_GMP_ID;
        clientSample.setRemoteValue{value: 1 ether}(
            block.chainid,
            address(clientSample),
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

contract ExecutionTests__LayerZero is LocalTestSetup {
    LayerZeroGMPMock internal lzGatewayMock;
    GlacisLayerZeroAdapter internal lzAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (lzGatewayMock) = deployLayerZeroFixture();
        lzAdapter = deployLayerZeroAdapters(glacisRouter, lzGatewayMock);
        clientSample = deployGlacisClientSample(glacisRouter);
    }

    function test__Execution_LayerZero(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample),
            LAYERZERO_GMP_ID,
            abi.encode(val)
        );

        assertEq(clientSample.value(), val);
    }

    function test__RefundAddress_LayerZero() external {
        address randomRefundAddress = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        assertEq(randomRefundAddress.balance, 0);

        uint8[] memory gmps = new uint8[](1);
        gmps[0] = LAYERZERO_GMP_ID;
        clientSample.setRemoteValue{value: 1 ether}(
            block.chainid,
            address(clientSample),
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

contract ExecutionTests__Wormhole is LocalTestSetup {
    WormholeRelayerMock internal wormholeRelayerMock;
    GlacisWormholeAdapter internal wormholeAdapter;

    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (wormholeRelayerMock) = deployWormholeFixture();
        wormholeAdapter = deployWormholeAdapter(
            glacisRouter,
            wormholeRelayerMock
        );
        clientSample = deployGlacisClientSample(glacisRouter);
        wormholeRelayerMock.setGlacisAdapter(address(wormholeAdapter));
    }

    function test__Execution_Wormhole(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample),
            WORMHOLE_GMP_ID,
            abi.encode(val)
        );

        assertEq(clientSample.value(), val);
    }

    function test__RefundAddress_Wormhole() external {
        address randomRefundAddress = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        assertEq(randomRefundAddress.balance, 0);

        uint8[] memory gmps = new uint8[](1);
        gmps[0] = WORMHOLE_GMP_ID;
        clientSample.setRemoteValue{value: 1 ether}(
            block.chainid,
            address(clientSample),
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

contract ExecutionTests__Hyperlane is LocalTestSetup {
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
        clientSample = deployGlacisClientSample(glacisRouter);
    }

    function test__Execution_Hyperlane(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample),
            HYPERLANE_GMP_ID,
            abi.encode(val)
        );

        hyperlaneMailboxMock.execute();
        assertEq(clientSample.value(), val);
    }

    function test__RefundAddress_Wormhole() external {
        address randomRefundAddress = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        assertEq(randomRefundAddress.balance, 0);

        uint8[] memory gmps = new uint8[](1);
        gmps[0] = HYPERLANE_GMP_ID;
        clientSample.setRemoteValue{value: 1 ether}(
            block.chainid,
            address(clientSample),
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

contract ExecutionTests__CCIP is LocalTestSetup {
    CCIPRouterMock internal ccipMock;
    GlacisCCIPAdapter internal ccipAdapter;

    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (ccipMock) = deployCCIPFixture();
        ccipAdapter = deployCCIPAdapter(glacisRouter, ccipMock);
        clientSample = deployGlacisClientSample(glacisRouter);
    }

    function test__Execution_CCIP(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample),
            CCIP_GMP_ID,
            abi.encode(val)
        );

        assertEq(clientSample.value(), val);
    }

    function test__RefundAddress_CCIP() external {
        address randomRefundAddress = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
        assertEq(randomRefundAddress.balance, 0);

        uint8[] memory gmps = new uint8[](1);
        gmps[0] = CCIP_GMP_ID;
        clientSample.setRemoteValue{value: 1 ether}(
            block.chainid,
            address(clientSample),
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

contract ExecutionTests__GasBenchmark is LocalTestSetup {
    AxelarOneWayGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;
    GlacisClientTextSample internal glacisTextSample;
    AxelarSample internal axelarSample;
    AxelarTextSample internal axelarTextSample;

    LayerZeroOneWayMock internal lzEndpointMock;
    GlacisLayerZeroAdapter internal lzAdapter;
    LayerZeroSample internal lzSample;
    LayerZeroTextSample internal lzTextSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();

        // Uses one-way gateway mock to only find the gas on the send side & isolate gas
        axelarGatewayMock = new AxelarOneWayGatewayMock();
        axelarGasServiceMock = new AxelarGasServiceMock();
        axelarAdapter = deployAxelarAdapters(
            glacisRouter,
            AxelarGatewayMock(address(axelarGatewayMock)),
            axelarGasServiceMock
        );
        clientSample = deployGlacisClientSample(glacisRouter);
        glacisTextSample = deployGlacisClientTextSample(glacisRouter);
        axelarSample = new AxelarSample(
            address(axelarGatewayMock),
            address(axelarGasServiceMock)
        );
        axelarTextSample = new AxelarTextSample(
            address(axelarGatewayMock),
            address(axelarGasServiceMock)
        );

        // Uses lz one-way mock
        lzEndpointMock = new LayerZeroOneWayMock();
        lzAdapter = deployLayerZeroAdapters(
            glacisRouter,
            LayerZeroGMPMock(address(lzEndpointMock))
        );
        lzSample = new LayerZeroSample(address(lzEndpointMock));
        lzTextSample = new LayerZeroTextSample(address(lzEndpointMock));
        lzSample.setTrustedRemote(1, abi.encode(lzSample));
        lzTextSample.setTrustedRemote(1, abi.encode(lzTextSample));
    }

    // =============== Sending portion of Execution ================
    function test_gas__ExecuteSend_GlacAx(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample),
            AXELAR_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__ExecuteSend_Axelar(uint256 val) external {
        axelarSample.setRemoteValue{value: 0.1 ether}(
            "Anvil",
            address(axelarSample),
            abi.encode(val)
        );
    }

    function test_gas__ExecuteSend_GlacLZ(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample),
            LAYERZERO_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__ExecuteSend_LZ(uint256 val) external {
        lzSample.setRemoteValue{value: 0.1 ether}(1, val);
    }

    // ======= Sending portion of Execution with Long String ========
    function test_gas__ExecTxtSend_GlacAx(uint256) external {
        glacisTextSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample),
            AXELAR_GMP_ID,
            abi.encode(
                "hellohellohellohellohellohellohellohellohellohellohellohellohel"
            )
        );
    }

    function test_gas__ExecTxtSend_Axelar(uint256) external {
        axelarTextSample.setRemoteValue{value: 0.1 ether}(
            "Anvil",
            address(axelarSample),
            abi.encode(
                "hellohellohellohellohellohellohellohellohellohellohellohellohel"
            )
        );
    }

    function test_gas__ExecTxtSend_GlacLZ(uint256) external {
        glacisTextSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample),
            LAYERZERO_GMP_ID,
            abi.encode(
                "hellohellohellohellohellohellohellohellohellohellohellohellohel"
            )
        );
    }

    function test_gas__ExecTxtSend_LZ(uint256) external {
        lzTextSample.setRemoteValue(
            1,
            "hellohellohellohellohellohellohellohellohellohellohellohellohel"
        );
    }

    receive() external payable {}
}

contract ExecutionTests__FullGasBenchmark is LocalTestSetup {
    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;
    GlacisClientTextSample internal glacisTextSample;
    AxelarSample internal axelarSample;
    AxelarTextSample internal axelarTextSample;

    LayerZeroGMPMock internal lzEndpointMock;
    GlacisLayerZeroAdapter internal lzAdapter;
    LayerZeroSample internal lzSample;
    LayerZeroTextSample internal lzTextSample;

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
        clientSample = deployGlacisClientSample(glacisRouter);

        // Uses lz one-way mock
        (lzEndpointMock) = deployLayerZeroFixture();
        lzAdapter = deployLayerZeroAdapters(glacisRouter, lzEndpointMock);
        lzSample = new LayerZeroSample(address(lzEndpointMock));
        lzSample.setTrustedRemoteAddress(1, abi.encodePacked(lzSample));
    }

    // ============== Receiving portion of Execution ===============
    function test_gas__ExecReceive_GlacAx(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample),
            AXELAR_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__ExecReceive_Axelar(uint256 val) external {
        axelarSample.setRemoteValue{value: 0.1 ether}(
            "Anvil",
            address(axelarSample),
            abi.encode(bytes32(0), bytes32(0), val)
        );
    }

    function test_gas__ExecReceive_GlacLZ(uint256 val) external {
        clientSample.setRemoteValue__execute{value: 0.1 ether}(
            block.chainid,
            address(clientSample),
            LAYERZERO_GMP_ID,
            abi.encode(val)
        );
    }

    function test_gas__ExecReceive_LZ(uint256 val) external {
        lzSample.setRemoteValue{value: 0.1 ether}(1, val);
    }

    receive() external payable {}
}
