// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, GlacisAxelarAdapter, LayerZeroGMPMock, GlacisLayerZeroAdapter, GlacisCommons} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {IGlacisRouterEvents} from "../../contracts/interfaces/IGlacisRouter.sol";
import {GlacisRouter__MessageAlreadyReceivedFromGMP} from "../../contracts/routers/GlacisRouter.sol";
import {AxelarRetryGatewayMock} from "../contracts/mocks/axelar/AxelarRetryGatewayMock.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";
import {CustomAdapterSample} from "../contracts/samples/CustomAdapterSample.sol";

contract RetryTests is LocalTestSetup, IGlacisRouterEvents {
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
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
        clientSample.setQuorum(1);
    }

    function setUpRetryMock() internal {
        // Set up retry mock by replacing the gateway & adapter
        AxelarRetryGatewayMock mock = deployAxelarRetryFixture();
        GlacisAxelarAdapter adapter = new GlacisAxelarAdapter(
            address(glacisRouter),
            address(mock),
            address(axelarGasServiceMock),
            address(this)
        );
        glacisRouter.registerAdapter(uint8(uint160(AXELAR_GMP_ID)), address(adapter));

        // Add chain IDs
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        string[] memory axelarLabels = new string[](1);
        axelarLabels[0] = "Anvil";
        adapter.setGlacisChainIds(glacisIDs, axelarLabels);
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(adapter).toBytes32();
        adapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);
        assertEq(
            glacisRouter.glacisGMPIdToAdapter(uint8(uint160(AXELAR_GMP_ID))),
            address(adapter)
        );
    }

    function test__Retry_MessageIdsAreNotEqualWithSameParameters() external {
        clientSample.setQuorum(2);
        address[] memory gmps = new address[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;

        bytes32 id1 = clientSample.setRemoteValue__retriable(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            abi.encode(1000)
        );
        bytes32 id2 = clientSample.setRemoteValue__retriable(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            abi.encode(1000)
        );

        assertNotEq(id1, id2);
    }

    function test__Retry_MessageIdEventsEmit() external {
        clientSample.setQuorum(2);
        address[] memory gmps = new address[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;

        // Testing:          sender        nonce emitter
        vm.expectEmit(false, false, false, true, address(glacisRouter));
        emit IGlacisRouterEvents.GlacisAbstractRouter__MessageIdCreated(
            bytes32(0),
            address(clientSample).toBytes32(),
            0
        );
        clientSample.setRemoteValue__retriable(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            abi.encode(1000)
        );
    }

    function test__Retry_IncrementingNonceForMessageId() external {
        clientSample.setQuorum(2);
        address[] memory gmps = new address[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;

        for (uint256 i; i < 10; ++i) {
            // Testing:          sender        nonce emitter
            vm.expectEmit(false, false, false, true, address(glacisRouter));
            emit IGlacisRouterEvents.GlacisAbstractRouter__MessageIdCreated(
                bytes32(0),
                address(clientSample).toBytes32(),
                i
            );
            clientSample.setRemoteValue__retriable(
                block.chainid,
                address(clientSample).toBytes32(),
                gmps,
                createFees(0, gmps.length),
                abi.encode(1000)
            );
        }
    }

    function test__Retry_ButFirstSucceeded() external {
        clientSample.setQuorum(2);
        address[] memory gmps = new address[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;

        bytes32 messageId = clientSample.setRemoteValue__retriable(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            abi.encode(1000)
        );

        // This should fail. Note that this failure is on the "destination" chain.
        address[] memory gmp = new address[](1);
        gmp[0] = AXELAR_GMP_ID;

        vm.expectRevert(GlacisRouter__MessageAlreadyReceivedFromGMP.selector);
        clientSample.setRemoteValue__retry(
            block.chainid,
            address(clientSample).toBytes32(),
            gmp,
            createFees(0, gmp.length),
            abi.encode(1000),
            messageId,
            0
        );
    }

    function test__Retry() external {
        setUpRetryMock();

        // Send initial message
        uint256 initialValue = clientSample.value();
        address[] memory gmps = new address[](1);
        gmps[0] = AXELAR_GMP_ID;
        bytes32 messageId = clientSample.setRemoteValue__retriable(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            abi.encode(1000)
        );

        // Expect no changes
        assertEq(initialValue, clientSample.value());

        // Send retry
        clientSample.setRemoteValue__retry(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            abi.encode(1000),
            messageId,
            0
        );
        assertEq(1000, clientSample.value());
    }

    function test__Retry_Quorum() external {
        setUpRetryMock();
        clientSample.setQuorum(2);

        // Send initial message
        uint256 initialValue = clientSample.value();
        address[] memory gmps = new address[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;
        bytes32 messageId = clientSample.setRemoteValue__retriable(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            abi.encode(1000)
        );

        // Expect no changes
        assertEq(initialValue, clientSample.value());

        // Send retry
        address[] memory gmpsOnlyAxelar = new address[](1);
        gmpsOnlyAxelar[0] = AXELAR_GMP_ID;
        clientSample.setRemoteValue__retry(
            block.chainid,
            address(clientSample).toBytes32(),
            gmpsOnlyAxelar,
            createFees(0, gmpsOnlyAxelar.length),
            abi.encode(1000),
            messageId,
            0
        );
        assertEq(1000, clientSample.value());
    }

    function test__Retry_QuorumButFirstSucceeded() external {
        clientSample.setQuorum(2);

        // Send message
        address[] memory adapters = new address[](2);
        adapters[0] = AXELAR_GMP_ID;
        adapters[1] = LAYERZERO_GMP_ID;
        bytes32 messageId = clientSample.setRemoteValue__retriable(
            block.chainid,
            address(clientSample).toBytes32(),
            adapters,
            createFees(0, adapters.length),
            abi.encode(1000)
        );

        // Expect change
        assertEq(1000, clientSample.value());

        // Send retry
        vm.expectRevert(GlacisRouter__MessageAlreadyReceivedFromGMP.selector);
        clientSample.setRemoteValue__retry(
            block.chainid,
            address(clientSample).toBytes32(),
            adapters,
            createFees(0, adapters.length),
            abi.encode(1000),
            messageId,
            0
        );
    }

    function test__Retry_SwitchFromAxelarToLZ() external {
        setUpRetryMock();

        // Send initial message
        uint256 initialValue = clientSample.value();
        address[] memory gmps = new address[](1);
        gmps[0] = AXELAR_GMP_ID;
        bytes32 messageId = clientSample.setRemoteValue__retriable(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            abi.encode(1000)
        );

        // Expect no changes
        assertEq(initialValue, clientSample.value());

        // Send retry
        gmps[0] = LAYERZERO_GMP_ID;
        clientSample.setRemoteValue__retry(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            abi.encode(1000),
            messageId,
            0
        );
        assertEq(1000, clientSample.value());

        // Retry second message with Axelar to test quorum+retry too
        gmps[0] = AXELAR_GMP_ID;
        clientSample.setRemoteValue__retry(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            abi.encode(1000),
            messageId,
            0
        );
        assertEq(1000, clientSample.value()); // Expect no change, would be 2000 otherwise
    }

    function test__Retry_CustomAdapter() external {
        setUpRetryMock();

        // Send initial message
        bytes32 messageId;
        uint256 initialValue = clientSample.value();
        {
            address[] memory gmps = new address[](1);
            gmps[0] = AXELAR_GMP_ID;
            messageId = clientSample.setRemoteValue__retriable(
                block.chainid,
                address(clientSample).toBytes32(),
                gmps,
                createFees(0, gmps.length),
                abi.encode(1000)
            );
        }

        // Expect no changes
        assertEq(initialValue, clientSample.value());

        // Add custom adapter
        address customAdapter = address(
            new CustomAdapterSample(address(glacisRouter), address(this))
        );
        clientSample.addAllowedRoute(
            GlacisCommons.GlacisRoute(
                block.chainid, // fromChainId
                address(clientSample).toBytes32(), // from
                customAdapter // custom adapter
            )
        );

        // Send retry
        {
            address[] memory adapters = new address[](1);
            adapters[0] = customAdapter;

            clientSample.setRemoteValue__retry(
                block.chainid,
                address(clientSample).toBytes32(),
                adapters,
                createFees(0, adapters.length),
                abi.encode(1000),
                messageId,
                0
            );
        }
        assertEq(1000, clientSample.value());
    }

    receive() external payable {}
}
