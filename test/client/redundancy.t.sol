// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroGMPMock, GlacisLayerZeroAdapter, WormholeRelayerMock, GlacisWormholeAdapter} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {GlacisCommons} from "../../contracts/commons/GlacisCommons.sol";
import {GlacisClient} from "../../contracts/client/GlacisClient.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";

contract RedundancyTests is LocalTestSetup {
    using AddressBytes32 for address;

    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;

    LayerZeroGMPMock internal lzGatewayMock;
    GlacisLayerZeroAdapter internal lzAdapter;

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
        (lzGatewayMock) = deployLayerZeroFixture();
        lzAdapter = deployLayerZeroAdapters(glacisRouter, lzGatewayMock);
        (clientSample,) = deployGlacisClientSample(glacisRouter);
    }

    function test__Redundancy_Quorum1_AxelarLayerZero(uint256 val) external {
        uint8[] memory gmps = new uint8[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;

        clientSample.setRemoteValue__redundancy{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0.1 ether / gmps.length, gmps.length),
            abi.encode(val)
        );

        assertEq(clientSample.value(), val);
    }

    function test__Redundancy_Quorum2_AxelarLayerZero(uint256 val) external {
        uint8[] memory gmps = new uint8[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;
        clientSample.setQuorum(2);

        clientSample.setRemoteValue__redundancy{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0.1 ether / gmps.length, gmps.length),
            abi.encode(val)
        );

        // Should still equal 0, since quorum was never reached
        assertEq(clientSample.value(), val);
    }

    function test__Redundancy_ImpossibleQuorum_AxelarLayerZero(
        uint8 quorum
    ) external {
        vm.assume(quorum >= 3);
        clientSample.setQuorum(quorum);

        uint8[] memory gmps = new uint8[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;

        clientSample.setRemoteValue__redundancy{value: 0.1 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0.1 ether / gmps.length, gmps.length),
            abi.encode(1000)
        );

        // Should still equal 0, since quorum was never reached
        assertEq(clientSample.value(), 0);
    }

    receive() external payable {}
}

contract RedundancyReceivingDataTests is LocalTestSetup {
    using AddressBytes32 for address;

    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;

    LayerZeroGMPMock internal lzGatewayMock;
    GlacisLayerZeroAdapter internal lzAdapter;

    WormholeRelayerMock internal whMock;
    GlacisWormholeAdapter internal whAdapter;

    GlacisRouter internal glacisRouter;
    RedundancyReceivingDataTestHarness internal harness;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (axelarGatewayMock, axelarGasServiceMock) = deployAxelarFixture();
        axelarAdapter = deployAxelarAdapters(
            glacisRouter,
            axelarGatewayMock,
            axelarGasServiceMock
        );
        (lzGatewayMock) = deployLayerZeroFixture();
        lzAdapter = deployLayerZeroAdapters(glacisRouter, lzGatewayMock);
        whMock = deployWormholeFixture();
        whAdapter = deployWormholeAdapter(glacisRouter, whMock);
        harness = new RedundancyReceivingDataTestHarness(address(glacisRouter));
    }

    function test_Redundancy_ReceivingGMPData() public {
        uint8[] memory gmps = new uint8[](3);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;
        gmps[2] = WORMHOLE_GMP_ID;
        uint256[] memory fees = createFees(
            0.3 ether / gmps.length,
            gmps.length
        );

        assert(
            harness.isAllowedRoute(
                block.chainid,
                address(harness).toBytes32(),
                AXELAR_GMP_ID,
                ""
            )
        );

        harness.route{value: 1 ether}(
            block.chainid,
            address(harness).toBytes32(),
            abi.encode("Hello"),
            gmps,
            fees,
            0.3 ether
        );

        uint8[] memory gmps_received = new uint8[](3);
        gmps_received[0] = harness.fromGmpIds(0);
        gmps_received[1] = harness.fromGmpIds(1);
        gmps_received[2] = harness.fromGmpIds(2);

        assert(uint8Contains(gmps_received, AXELAR_GMP_ID));
        assert(uint8Contains(gmps_received, LAYERZERO_GMP_ID));
        assert(uint8Contains(gmps_received, WORMHOLE_GMP_ID));
    }

    function uint8Contains(
        uint8[] memory gmps_received,
        uint8 key
    ) internal pure returns (bool) {
        for (uint256 i; i < gmps_received.length; ++i) {
            if (gmps_received[i] == key) return true;
        }
        return false;
    }
}

contract RedundancyReceivingDataTestHarness is GlacisClient {
    constructor(address glacisRouter) GlacisClient(glacisRouter, 3) {
        _addAllowedRoute(GlacisCommons.GlacisRoute(0, bytes32(0), 0));
    }

    uint8[] public fromGmpIds;
    uint256 public fromChainId;
    bytes32 public fromAddress;
    bytes public payload;

    function _receiveMessage(
        address[] memory _fromGmpIds,
        uint256 _fromChainId,
        bytes32 _fromAddress,
        bytes memory _payload
    ) internal override {
        fromGmpIds = _fromGmpIds;
        fromChainId = _fromChainId;
        fromAddress = _fromAddress;
        payload = _payload;
    }

    function route(
        uint256 chainId,
        bytes32 to,
        bytes memory _payload,
        uint8[] memory gmps,
        uint256[] memory fees,
        uint256 gasPayment
    ) external payable {
        _routeRedundant(
            chainId,
            to,
            _payload,
            gmps,
            fees,
            tx.origin,
            gasPayment
        );
    }
}
