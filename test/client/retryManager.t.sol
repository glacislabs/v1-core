// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;
import {LocalTestSetup, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, GlacisAxelarAdapter, LayerZeroV2Mock, GlacisLayerZeroV2Adapter, GlacisCommons} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {IGlacisRouterEvents} from "../../contracts/interfaces/IGlacisRouter.sol";
import {GlacisRouter__MessageAlreadyReceivedFromGMP} from "../../contracts/routers/GlacisRouter.sol";
import {AxelarRetryGatewayMock} from "../contracts/mocks/axelar/AxelarRetryGatewayMock.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";
import {CustomAdapterSample} from "../contracts/samples/CustomAdapterSample.sol";
import {GlacisTokenMediator, GlacisTokenClientSampleSource, GlacisTokenClientSampleDestination, XERC20Sample, ERC20Sample, XERC20LockboxSample, XERC20NativeLockboxSample} from "../LocalTestSetup.sol";

contract RetryTests is LocalTestSetup, IGlacisRouterEvents {
    using AddressBytes32 for address;

    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;

    LayerZeroV2Mock internal lzGatewayMock;
    GlacisLayerZeroV2Adapter internal lzAdapter;

    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;
    GlacisTokenClientSampleSource internal glacisTokenClientSampleSource;
    GlacisTokenClientSampleDestination
        internal glacisTokenClientSampleDestination;
    XERC20Sample internal xERC20Sample;
    AxelarRetryGatewayMock internal retryGMPMock;
    GlacisAxelarAdapter internal retryAdapterMock;

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
        (
            ,
            xERC20Sample,
            ,
            ,
            ,
            glacisTokenClientSampleSource,
            glacisTokenClientSampleDestination
        ) = deployGlacisTokenFixture(glacisRouter);

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
        glacisRouter.registerAdapter(
            uint8(uint160(AXELAR_GMP_ID)),
            address(adapter)
        );

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

        (bytes32 id1, ) = clientSample.setRemoteValue__retryable(
            block.chainid,
            address(clientSample).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            abi.encode(1000)
        );
        (bytes32 id2, ) = clientSample.setRemoteValue__retryable(
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
        clientSample.setRemoteValue__retryable(
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
            clientSample.setRemoteValue__retryable(
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

        (bytes32 messageId, uint256 nonce) = clientSample
            .setRemoteValue__retryable(
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
            nonce
        );
    }

    function test__Retry__() external {
        setUpRetryMock();

        // Send initial message
        uint256 initialValue = clientSample.value();
        address[] memory gmps = new address[](1);
        gmps[0] = AXELAR_GMP_ID;
        (bytes32 messageId, uint256 nonce) = clientSample
            .setRemoteValue__retryable(
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
            nonce
        );
        assertEq(1000, clientSample.value());
    }

    function test__Retry_Quorum2() external {
        setUpRetryMock();
        clientSample.setQuorum(2);

        // Send initial message
        uint256 initialValue = clientSample.value();
        address[] memory adapters = new address[](2);
        adapters[0] = AXELAR_GMP_ID;
        adapters[1] = LAYERZERO_GMP_ID;
        (bytes32 messageId, uint256 nonce) = clientSample
            .setRemoteValue__retryable(
                block.chainid,
                address(clientSample).toBytes32(),
                adapters,
                createFees(0, adapters.length),
                abi.encode(1000)
            );

        // Expect no changes
        assertEq(initialValue, clientSample.value());

        // Send retry
        address[] memory adaptersOnlyAxelar = new address[](1);
        adaptersOnlyAxelar[0] = AXELAR_GMP_ID;
        clientSample.setRemoteValue__retry(
            block.chainid,
            address(clientSample).toBytes32(),
            adaptersOnlyAxelar,
            createFees(0, adaptersOnlyAxelar.length),
            abi.encode(1000),
            messageId,
            nonce
        );
        assertEq(1000, clientSample.value());
    }

    function test__Retry_QuorumButFirstSucceeded() external {
        clientSample.setQuorum(2);

        // Send message
        address[] memory adapters = new address[](2);
        adapters[0] = AXELAR_GMP_ID;
        adapters[1] = LAYERZERO_GMP_ID;
        (bytes32 messageId, uint256 nonce) = clientSample
            .setRemoteValue__retryable(
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
            nonce
        );
    }

    function test__Retry_SwitchFromAxelarToLZ() external {
        setUpRetryMock();

        // Send initial message
        uint256 initialValue = clientSample.value();
        address[] memory gmps = new address[](1);
        gmps[0] = AXELAR_GMP_ID;
        (bytes32 messageId, uint256 nonce) = clientSample
            .setRemoteValue__retryable(
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
            nonce
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
        uint256 initialValue = clientSample.value();
        address[] memory gmps = new address[](1);
        gmps[0] = AXELAR_GMP_ID;
        (bytes32 messageId, uint256 nonce) = clientSample
            .setRemoteValue__retryable(
                block.chainid,
                address(clientSample).toBytes32(),
                gmps,
                createFees(0, gmps.length),
                abi.encode(1000)
            );

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
        address[] memory adapters = new address[](1);
        adapters[0] = customAdapter;

        clientSample.setRemoteValue__retry(
            block.chainid,
            address(clientSample).toBytes32(),
            adapters,
            createFees(0, adapters.length),
            abi.encode(1000),
            messageId,
            nonce
        );
        assertEq(1000, clientSample.value());
    }

    function test__Retry_SendWithTokens(uint256 amount) external {
        vm.assume(amount < 10e15);
        setUpRetryMock();
        xERC20Sample.transfer(address(glacisTokenClientSampleSource), amount);
        uint256 preSourceBalance = xERC20Sample.balanceOf(
            address(glacisTokenClientSampleSource)
        );
        uint256 preDestinationBalance = xERC20Sample.balanceOf(
            address(glacisTokenClientSampleDestination)
        );
        uint256 preDestinationValue = glacisTokenClientSampleDestination
            .value();
        // Send initial message
        uint256 initialValue = glacisTokenClientSampleDestination.value();
        address[] memory gmps = new address[](1);
        gmps[0] = AXELAR_GMP_ID;
        (bytes32 messageId, uint256 nonce) = glacisTokenClientSampleSource
            .sendMessageAndTokens__abstract{value: 0.1 ether}(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            AXELAR_GMP_ID,
            "", // no message only tokens
            address(xERC20Sample),
            amount
        );
        // Expect no changes
        assertEq(initialValue, glacisTokenClientSampleDestination.value());

        glacisTokenClientSampleSource.createRetryWithTokenPackage(
            address(xERC20Sample),
            amount,
            messageId,
            nonce
        );
        // Send retry
        glacisTokenClientSampleSource.retrySendWithTokens(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            gmps,
            createFees(0, gmps.length),
            "",
            glacisTokenClientSampleSource.getRetryWithTokenPackage()
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preSourceBalance - amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            preDestinationBalance + amount
        );
        assertEq(
            glacisTokenClientSampleDestination.value(),
            preDestinationValue
        );
    }

    receive() external payable {}
}
