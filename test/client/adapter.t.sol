// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroGMPMock, GlacisLayerZeroAdapter, WormholeRelayerMock, GlacisWormholeAdapter, CCIPRouterMock, GlacisCCIPAdapter, HyperlaneMailboxMock, GlacisHyperlaneAdapter} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {GlacisAbstractAdapter__OnlyAdapterAllowed, GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__ChainIsNotAvailable} from "../../contracts/adapters/GlacisAbstractAdapter.sol";
import {SimpleNonblockingLzAppEvents} from "../../contracts/adapters/LayerZero/SimpleNonblockingLzApp.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IPostDispatchHook} from "@hyperlane-xyz/core/contracts/interfaces/hooks/IPostDispatchHook.sol";
import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";

/* solhint-disable contract-name-camelcase */
contract AdapterTests__Axelar is LocalTestSetup {
    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    using Strings for address;

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

    function test__onlyAdapterAllowedFailure_Axelar() external {
        // 1. Expect error
        vm.expectRevert(GlacisAbstractAdapter__OnlyAdapterAllowed.selector);

        // 2. Send fake message to GlacisAxelarAdapter through AxelarGatewayMock
        axelarGatewayMock.callContract(
            "Anvil",
            address(axelarAdapter).toHexString(),
            abi.encode(
                keccak256("random message ID"),
                // This address injection is the attack that we are trying to avoid
                address(axelarAdapter),
                address(axelarAdapter),
                1,
                false,
                "my text"
            )
        );
    }
}

// solhint-disable-next-line
contract AdapterTests__LZ is LocalTestSetup, SimpleNonblockingLzAppEvents {
    using AddressBytes32 for address;

    LayerZeroGMPMock internal lzGatewayMock;
    GlacisLayerZeroAdapter internal lzAdapter;
    GlacisLayerZeroAdapterHarness internal lzAdapterHarness;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (lzGatewayMock) = deployLayerZeroFixture();
        lzAdapter = deployLayerZeroAdapters(glacisRouter, lzGatewayMock);
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
        lzAdapterHarness = new GlacisLayerZeroAdapterHarness(
            address(lzGatewayMock),
            address(glacisRouter),
            address(this)
        );
    }

    function test__onlyAuthorizedAdapterShouldRevert_LayerZero(
        uint256 chainId,
        address origin
    ) external {
        vm.expectRevert(GlacisAbstractAdapter__OnlyAdapterAllowed.selector);
        lzAdapterHarness.harness_onlyAuthorizedAdapter(
            chainId,
            origin.toBytes32()
        );
    }

    function test__Adapter_onlyAuthorizedAdapterFailure_LayerZero() external {
        // 1. Expect error
        vm.expectEmit(false, false, false, false);
        emit SimpleNonblockingLzAppEvents.MessageFailed(
            0,
            bytes(""),
            0,
            bytes(""),
            bytes("")
        );

        // 2. Send fake message to GlacisAxelarAdapter through AxelarGatewayMock
        lzGatewayMock.send(
            1,
            // This address injection is also the attack that we are trying to avoid
            abi.encodePacked(address(lzAdapter), address(lzAdapter)),
            abi.encode(
                keccak256("random message ID"),
                // This address injection is the attack that we are trying to avoid
                address(lzAdapter),
                address(lzAdapter),
                1,
                false,
                "my text"
            ),
            msg.sender,
            msg.sender,
            bytes("")
        );
    }

    // TODO: cannot reach LZChainIdNotAccepted revert
    /*    function test__Adapter_ChainIdNotAccepted_LayerZero() external {
         vm.expectRevert(GlacisLayerZeroAdapter__LZChainIdNotAccepted.selector);
         uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint16[] memory adapterIds = new uint16[](1);
        adapterIds[0] = 1;

        lzAdapter.setGlacisChainIds(glacisChainIds, adapterIds);

        // Add self as a remote counterpart
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(lzAdapter).toBytes32();
        lzAdapter.addRemoteCounterparts(glacisChainIds, adapterCounterparts);

        lzGatewayMock.lzReceive(
            address(lzAdapter),
            adapterIds[0],
            abi.encodePacked(address(lzAdapter), address(lzAdapter)),
            0,
            "0x111111"
        );
    }
*/

    function test__Adapter_ArraysMustBeSameLength_LayerZero() external {
        vm.expectRevert(
            GlacisAbstractAdapter__IDArraysMustBeSameLength.selector
        );
        uint256[] memory glacisChainIds = new uint256[](1);
        uint16[] memory adapterLabels = new uint16[](2);

        lzAdapter.setGlacisChainIds(glacisChainIds, adapterLabels);
    }

    function test__Adapter_DestinationChainIdNotValid_LayerZero() external {
        vm.expectRevert(
            GlacisAbstractAdapter__DestinationChainIdNotValid.selector
        );
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 0;
        uint16[] memory adapterIds = new uint16[](1);

        lzAdapter.setGlacisChainIds(glacisChainIds, adapterIds);
    }

    function test__Adapter_ChainIdToAdapterChainId_LayerZero() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint16[] memory adapterIds = new uint16[](1);
        adapterIds[0] = 1;

        lzAdapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertEq(
            lzAdapter.glacisChainIdToAdapterChainId(glacisChainIds[0]),
            adapterIds[0]
        );
    }

    function test__Adapter_AdapterChainId_LayerZero() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint16[] memory adapterIds = new uint16[](1);
        adapterIds[0] = 1;

        lzAdapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertEq(lzAdapter.adapterChainID(glacisChainIds[0]), adapterIds[0]);
    }

    function test__Adapter_ChainIsAvailable_LayerZero() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint16[] memory adapterIds = new uint16[](1);
        adapterIds[0] = 1;

        lzAdapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertTrue(lzAdapter.chainIsAvailable(glacisChainIds[0]));
    }

    function test__Adapter_ChainIsNotAvailable_LayerZero() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = block.chainid;
        uint16[] memory adapterIds = new uint16[](1);
        adapterIds[0] = 0;

        lzAdapter.setGlacisChainIds(glacisChainIds, adapterIds);

        vm.expectRevert(
            abi.encodeWithSelector(
                GlacisAbstractAdapter__ChainIsNotAvailable.selector,
                block.chainid
            )
        );
        clientSample.setRemoteValue__execute(
            block.chainid,
            bytes32(0),
            LAYERZERO_GMP_ID,
            ""
        );
    }
}

contract GlacisLayerZeroAdapterHarness is GlacisLayerZeroAdapter {
    constructor(
        address lzEndpoint_,
        address glacisRouter_,
        address owner
    ) GlacisLayerZeroAdapter(lzEndpoint_, glacisRouter_, owner) {}

    function harness_onlyAuthorizedAdapter(
        uint256 chainId,
        bytes32 sourceAddress
    ) external onlyAuthorizedAdapter(chainId, sourceAddress) {}
}

contract AdapterTests__Wormhole is LocalTestSetup {
    using AddressBytes32 for address;

    WormholeRelayerMock internal wormholeGMPMock;
    GlacisWormholeAdapter internal wormholeAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;
    GlacisWormholeAdapterHarness internal wormholeAdapterHarness;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (wormholeGMPMock) = deployWormholeFixture();
        wormholeAdapter = deployWormholeAdapter(
            glacisRouter,
            wormholeGMPMock,
            uint16(block.chainid)
        );
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
        wormholeAdapterHarness = new GlacisWormholeAdapterHarness(
            address(wormholeGMPMock),
            address(glacisRouter),
            uint16(block.chainid),
            address(this)
        );
    }

    function test__onlyAuthorizedAdapterShouldRevert_Wormhole(
        uint16 chainId,
        address origin
    ) external {
        vm.expectRevert(GlacisAbstractAdapter__OnlyAdapterAllowed.selector);
        wormholeAdapterHarness.harness_onlyAuthorizedAdapter(
            chainId,
            origin.toBytes32()
        );
    }

    // TODO: enable this test after fixing the issue
    /*     function test__Adapter_onlyAuthorizedAdapterFailure_Wormhole() external {

        // 2. Send fake message to GlacisAxelarAdapter through AxelarGatewayMock
        wormholeGMPMock.send(
            1,
            // This address injection is also the attack that we are trying to avoid
            abi.encodePacked(
                address(wormholeAdapter),
                address(wormholeAdapter)
            ),
            abi.encode(
                keccak256("random message ID"),
                // This address injection is the attack that we are trying to avoid
                address(wormholeAdapter),
                address(wormholeAdapter),
                1,
                false,
                "my text"
            ),
            msg.sender,
            msg.sender,
            bytes("")
        );
    } */

    function test__Adapter_ArraysMustBeSameLength_Wormhole() external {
        vm.expectRevert(
            GlacisAbstractAdapter__IDArraysMustBeSameLength.selector
        );
        uint256[] memory glacisChainIds = new uint256[](1);
        uint16[] memory adapterLabels = new uint16[](2);

        wormholeAdapter.setGlacisChainIds(glacisChainIds, adapterLabels);
    }

    function test__Adapter_DestinationChainIdNotValid_Wormhole() external {
        vm.expectRevert(
            GlacisAbstractAdapter__DestinationChainIdNotValid.selector
        );
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 0;
        uint16[] memory adapterIds = new uint16[](1);

        wormholeAdapter.setGlacisChainIds(glacisChainIds, adapterIds);
    }

    function test__Adapter_ChainIdToAdapterChainId_Wormhole() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint16[] memory adapterIds = new uint16[](1);
        adapterIds[0] = 1;

        wormholeAdapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertEq(
            wormholeAdapter.glacisChainIdToAdapterChainId(glacisChainIds[0]),
            adapterIds[0]
        );
    }

    function test__Adapter_AdapterChainId_Wormhole() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint16[] memory adapterIds = new uint16[](1);
        adapterIds[0] = 1;

        wormholeAdapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertEq(
            wormholeAdapter.adapterChainID(glacisChainIds[0]),
            adapterIds[0]
        );
    }

    function test__Adapter_ChainIsAvailable_Wormhole() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint16[] memory adapterIds = new uint16[](1);
        adapterIds[0] = 1;

        wormholeAdapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertTrue(wormholeAdapter.chainIsAvailable(glacisChainIds[0]));
    }

    function test__Adapter_ChainIsNotAvailable_Wormhole() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = block.chainid;
        uint16[] memory adapterIds = new uint16[](1);
        adapterIds[0] = 0;

        wormholeAdapter.setGlacisChainIds(glacisChainIds, adapterIds);

        vm.expectRevert(
            abi.encodeWithSelector(
                GlacisAbstractAdapter__ChainIsNotAvailable.selector,
                block.chainid
            )
        );
        clientSample.setRemoteValue__execute(
            block.chainid,
            bytes32(0),
            WORMHOLE_GMP_ID,
            ""
        );
    }
}

contract GlacisWormholeAdapterHarness is GlacisWormholeAdapter {
    constructor(
        address gmpMock,
        address glacisRouter,
        uint16 chainId,
        address owner
    )
        GlacisWormholeAdapter(
            GlacisRouter(glacisRouter),
            gmpMock,
            chainId,
            owner
        )
    {}

    function harness_onlyAuthorizedAdapter(
        uint256 chainId,
        bytes32 sourceAddress
    ) external onlyAuthorizedAdapter(chainId, sourceAddress) {}
}

contract AdapterTests__CCIP is LocalTestSetup {
    using AddressBytes32 for address;

    CCIPRouterMock internal gmp;
    GlacisCCIPAdapter internal adapter;
    GlacisCCIPAdapterHarness internal adapterHarness;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (gmp) = deployCCIPFixture();
        adapter = deployCCIPAdapter(glacisRouter, gmp);
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
        adapterHarness = new GlacisCCIPAdapterHarness(
            address(glacisRouter),
            address(gmp),
            address(this)
        );
    }

    function test__onlyAuthorizedAdapterShouldRevert_CCIP(
        uint256 chainId,
        address origin
    ) external {
        vm.expectRevert(GlacisAbstractAdapter__OnlyAdapterAllowed.selector);
        adapterHarness.harness_onlyAuthorizedAdapter(
            chainId,
            origin.toBytes32()
        );
    }

    function test__Adapter_onlyAuthorizedAdapterFailure_CCIP() external {
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(address(adapter)),
            data: "",
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 1_000_000})
            ),
            feeToken: address(0)
        });

        // Get the fee required to send the CCIP message
        uint256 fees = gmp.getFee(uint64(block.chainid), evm2AnyMessage);

        vm.expectRevert(GlacisAbstractAdapter__OnlyAdapterAllowed.selector);

        // Send the CCIP message through the router and store the returned CCIP message ID
        gmp.ccipSend{value: fees}(uint64(block.chainid), evm2AnyMessage);
    }

    function test__Adapter_ArraysMustBeSameLength_CCIP() external {
        vm.expectRevert(
            GlacisAbstractAdapter__IDArraysMustBeSameLength.selector
        );
        uint256[] memory glacisChainIds = new uint256[](1);
        uint64[] memory adapterLabels = new uint64[](2);

        adapter.setGlacisChainIds(glacisChainIds, adapterLabels);
    }

    function test__Adapter_DestinationChainIdNotValid_CCIP() external {
        vm.expectRevert(
            GlacisAbstractAdapter__DestinationChainIdNotValid.selector
        );
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 0;
        uint64[] memory adapterIds = new uint64[](1);

        adapter.setGlacisChainIds(glacisChainIds, adapterIds);
    }

    function test__Adapter_ChainIdToAdapterChainId_CCIP() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint64[] memory adapterIds = new uint64[](1);
        adapterIds[0] = 1;

        adapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertEq(
            adapter.glacisChainIdToAdapterChainId(glacisChainIds[0]),
            adapterIds[0]
        );
    }

    function test__Adapter_AdapterChainId_CCIP() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint64[] memory adapterIds = new uint64[](1);
        adapterIds[0] = 1;

        adapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertEq(adapter.adapterChainID(glacisChainIds[0]), adapterIds[0]);
    }

    function test__Adapter_ChainIsAvailable_CCIP() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint64[] memory adapterIds = new uint64[](1);
        adapterIds[0] = 1;

        adapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertTrue(adapter.chainIsAvailable(glacisChainIds[0]));
    }

    function test__Adapter_ChainIsNotAvailable_CCIP() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = block.chainid;
        uint64[] memory adapterIds = new uint64[](1);
        adapterIds[0] = 0;

        adapter.setGlacisChainIds(glacisChainIds, adapterIds);

        vm.expectRevert(
            abi.encodeWithSelector(
                GlacisAbstractAdapter__ChainIsNotAvailable.selector,
                block.chainid
            )
        );
        clientSample.setRemoteValue__execute(
            block.chainid,
            bytes32(0),
            CCIP_GMP_ID,
            ""
        );
    }
}

contract GlacisCCIPAdapterHarness is GlacisCCIPAdapter {
    constructor(
        address glacisRouter_,
        address CCIPEndpoint_,
        address owner
    ) GlacisCCIPAdapter(glacisRouter_, CCIPEndpoint_, owner) {}

    function harness_onlyAuthorizedAdapter(
        uint256 chainId,
        bytes32 sourceAddress
    ) external onlyAuthorizedAdapter(chainId, sourceAddress) {}
}

contract AdapterTests__Hyperlane is LocalTestSetup {
    using AddressBytes32 for address;

    HyperlaneMailboxMock internal gmp;
    GlacisHyperlaneAdapter internal adapter;
    GlacisHyperlaneAdapterHarness internal adapterHarness;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        gmp = deployHyperlaneFixture();
        adapter = deployHyperlaneAdapter(glacisRouter, gmp);
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
        adapterHarness = new GlacisHyperlaneAdapterHarness(
            address(glacisRouter),
            address(gmp),
            address(this)
        );
    }

    function test__onlyAuthorizedAdapterShouldRevert_Hyperlane(
        uint256 chainId,
        address origin
    ) external {
        vm.expectRevert(GlacisAbstractAdapter__OnlyAdapterAllowed.selector);
        adapterHarness.harness_onlyAuthorizedAdapter(
            chainId,
            origin.toBytes32()
        );
    }

    function test__Adapter_onlyAuthorizedAdapterFailure_Hyperlane() external {
        vm.expectRevert(GlacisAbstractAdapter__OnlyAdapterAllowed.selector);
        IMailbox(address(gmp)).dispatch{value: 1}(
            uint32(block.chainid),
            bytes32(uint256(uint160(address(adapter)))),
            ""
        );
    }

    function test__Adapter_ArraysMustBeSameLength_Hyperlane() external {
        vm.expectRevert(
            GlacisAbstractAdapter__IDArraysMustBeSameLength.selector
        );
        uint256[] memory glacisChainIds = new uint256[](1);
        uint32[] memory adapterLabels = new uint32[](2);

        adapter.setGlacisChainIds(glacisChainIds, adapterLabels);
    }

    function test__Adapter_DestinationChainIdNotValid_Hyperlane() external {
        vm.expectRevert(
            GlacisAbstractAdapter__DestinationChainIdNotValid.selector
        );
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 0;
        uint32[] memory adapterIds = new uint32[](1);

        adapter.setGlacisChainIds(glacisChainIds, adapterIds);
    }

    function test__Adapter_ChainIdToAdapterChainId_Hyperlane() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint32[] memory adapterIds = new uint32[](1);
        adapterIds[0] = 1;

        adapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertEq(
            adapter.glacisChainIdToAdapterChainId(glacisChainIds[0]),
            adapterIds[0]
        );
    }

    function test__Adapter_AdapterChainId_Hyperlane() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint32[] memory adapterIds = new uint32[](1);
        adapterIds[0] = 1;

        adapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertEq(adapter.adapterChainID(glacisChainIds[0]), adapterIds[0]);
    }

    function test__Adapter_ChainIsAvailable_Hyperlane() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = 1;
        uint32[] memory adapterIds = new uint32[](1);
        adapterIds[0] = 1;

        adapter.setGlacisChainIds(glacisChainIds, adapterIds);
        assertTrue(adapter.chainIsAvailable(glacisChainIds[0]));
    }

    function test__Adapter_ChainIsNotAvailable_Hyperlane() external {
        uint256[] memory glacisChainIds = new uint256[](1);
        glacisChainIds[0] = block.chainid;
        uint32[] memory adapterIds = new uint32[](1);
        adapterIds[0] = 0;

        adapter.setGlacisChainIds(glacisChainIds, adapterIds);

        vm.expectRevert(
            abi.encodeWithSelector(
                GlacisAbstractAdapter__ChainIsNotAvailable.selector,
                block.chainid
            )
        );
        clientSample.setRemoteValue__execute(
            block.chainid,
            bytes32(0),
            HYPERLANE_GMP_ID,
            ""
        );
    }
}

contract GlacisHyperlaneAdapterHarness is GlacisHyperlaneAdapter {
    constructor(
        address glacisRouter_,
        address HyperlaneEndpoint_,
        address owner
    ) GlacisHyperlaneAdapter(glacisRouter_, HyperlaneEndpoint_, owner) {}

    function harness_onlyAuthorizedAdapter(
        uint256 chainId,
        bytes32 sourceAddress
    ) external onlyAuthorizedAdapter(chainId, sourceAddress) {}
}
