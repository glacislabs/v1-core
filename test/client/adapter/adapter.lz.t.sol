// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisRouter, LayerZeroV2Mock, GlacisLayerZeroV2Adapter, GlacisCommons} from "../../LocalTestSetup.sol";
import {GlacisClientSample} from "../../contracts/samples/GlacisClientSample.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {GlacisAbstractAdapter__OnlyAdapterAllowed, GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__NoRemoteAdapterForChainId, GlacisAbstractAdapter__OnlyGlacisRouterAllowed, GlacisAbstractAdapter__SourceChainNotRegistered, GlacisAbstractAdapter__ChainIsNotAvailable} from "../../../contracts/adapters/GlacisAbstractAdapter.sol";
import {GlacisLayerZeroV2Adapter__PeersDisabledUseCounterpartInstead} from "../../../contracts/adapters/LayerZero/GlacisLayerZeroV2Adapter.sol";
import {IGlacisAdapter} from "../../../contracts/interfaces/IGlacisAdapter.sol";
import {SimpleNonblockingLzAppEvents} from "../../../contracts/adapters/LayerZero/SimpleNonblockingLzApp.sol";
import {AddressBytes32} from "../../../contracts/libraries/AddressBytes32.sol";
import {MessagingParams} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppReceiver.sol";
import "forge-std/console.sol";

// solhint-disable-next-line
contract AdapterTests__LZ is LocalTestSetup, SimpleNonblockingLzAppEvents {
    using AddressBytes32 for address;

    LayerZeroV2Mock internal lzGatewayMock;
    GlacisLayerZeroV2Adapter internal lzAdapter;
    GlacisLayerZeroV2AdapterHarness internal lzAdapterHarness;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (lzGatewayMock) = deployLayerZeroFixture();
        lzAdapter = deployLayerZeroAdapters(glacisRouter, lzGatewayMock);
        lzAdapterHarness = new GlacisLayerZeroV2AdapterHarness(
            address(glacisRouter),
            address(lzGatewayMock),
            address(this)
        );
    }

    function test__onlyAuthorizedAdapterShouldRevert_LayerZero(
        uint256 chainId,
        address origin
    ) external {
        vm.assume(origin != address(lzAdapterHarness));
        vm.expectRevert(GlacisAbstractAdapter__OnlyAdapterAllowed.selector);
        lzAdapterHarness.harness_onlyAuthorizedAdapter(
            chainId,
            origin.toBytes32()
        );
    }

    function test__Adapter_onlyAuthorizedAdapterFailure_LayerZero() external {
        // 1. Expect error
        vm.expectRevert(GlacisAbstractAdapter__OnlyAdapterAllowed.selector);

        // 2. Send fake message to GlacisAxelarAdapter through AxelarGatewayMock
        lzGatewayMock.send(
            MessagingParams(
                1,
                address(lzAdapter).toBytes32(),
                abi.encode(
                    keccak256("random message ID"),
                    // This address injection is the attack that we are trying to avoid
                    address(lzAdapter),
                    address(lzAdapter),
                    1,
                    false,
                    "my text"
                ),
                "",
                false
            ),
            msg.sender
        );
    }

    function test__setGlacisChainIds_LayerZero(
        uint256 chain,
        uint16 lzId
    ) external {
        vm.assume(chain != 0);
        vm.assume(lzId > 0);

        uint256[] memory chains = new uint256[](1);
        chains[0] = chain;
        uint32[] memory lzIDs = new uint32[](1);
        lzIDs[0] = lzId;

        lzAdapter.setGlacisChainIds(chains, lzIDs);

        assertEq(lzAdapter.adapterChainID(chain), lzId);
        assertEq(lzAdapter.adapterChainIdToGlacisChainId(lzId), chain);
        assertTrue(lzAdapter.chainIsAvailable(chain));
    }

    function test__sendMessageChecksAvailability_LayerZero(
        uint256 chainId
    ) external {
        vm.assume(chainId != 0);

        // Test no remote adapter
        vm.startPrank(address(glacisRouter));
        vm.expectRevert(
            abi.encodeWithSelector(
                GlacisAbstractAdapter__NoRemoteAdapterForChainId.selector,
                chainId
            )
        );
        lzAdapterHarness.sendMessagePublic(
            chainId,
            address(this),
            CrossChainGas(100, 100),
            abi.encode(0)
        );

        // Add remote adapter to get past
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = chainId;
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(0x123).toBytes32();
        vm.stopPrank();
        lzAdapterHarness.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        // Test no Axelar chain label
        vm.startPrank(address(glacisRouter));
        vm.expectRevert(
            abi.encodeWithSelector(
                GlacisAbstractAdapter__ChainIsNotAvailable.selector,
                chainId
            )
        );
        lzAdapterHarness.sendMessagePublic(
            chainId,
            address(this),
            CrossChainGas(100, 100),
            abi.encode(0)
        );
    }

    function test__setGlacisChainIdsErrors_LayerZero(
        uint256 chain,
        uint16 lzId
    ) external {
        vm.assume(chain != 0);
        vm.assume(lzId > 0);

        uint256[] memory chains = new uint256[](1);
        chains[0] = chain;
        uint32[] memory lzIDs = new uint32[](2);
        lzIDs[0] = lzId;
        lzIDs[0] = lzId;

        vm.expectRevert(
            GlacisAbstractAdapter__IDArraysMustBeSameLength.selector
        );
        lzAdapter.setGlacisChainIds(chains, lzIDs);

        lzIDs = new uint32[](1);
        lzIDs[0] = lzId;
        chains[0] = 0;

        vm.expectRevert(
            GlacisAbstractAdapter__DestinationChainIdNotValid.selector
        );
        lzAdapter.setGlacisChainIds(chains, lzIDs);
    }

    function test__chainIsNotAvailable_LayerZero(uint256 chainId) external {
        vm.assume(chainId != block.chainid);
        assertFalse(lzAdapter.chainIsAvailable(chainId));
    }

    function test__Adapter_AllowInitializationPath_LayerZero() external {
        Origin memory origin = Origin({
            srcEid: 31337,
            sender: bytes32("0x123"),
            nonce: 1
        });

        uint32 lzChainId = 31337;
        uint256[] memory chains = new uint256[](1);
        chains[0] = origin.srcEid;
        uint32[] memory lzChainIDs = new uint32[](1);
        lzChainIDs[0] = lzChainId;

        GlacisLayerZeroV2Adapter(lzAdapterHarness).setGlacisChainIds(
            chains,
            lzChainIDs
        );

        // Add remote adapter to get past
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = lzChainId;
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = origin.sender;
        lzAdapterHarness.addRemoteCounterparts(glacisIDs, adapterCounterparts);
        assertTrue(lzAdapterHarness.allowInitializePath(origin));
        assertEq(lzAdapterHarness.peers(lzChainId), origin.sender);
        vm.expectRevert(
            GlacisLayerZeroV2Adapter__PeersDisabledUseCounterpartInstead
                .selector
        );
        lzAdapterHarness.setPeer(lzChainId, origin.sender);
    }
}

contract GlacisLayerZeroV2AdapterHarness is
    GlacisLayerZeroV2Adapter,
    GlacisCommons
{
    constructor(
        address glacisRouter_,
        address lzEndpoint_,
        address owner
    ) GlacisLayerZeroV2Adapter(glacisRouter_, lzEndpoint_, owner) {}

    function harness_onlyAuthorizedAdapter(
        uint256 chainId,
        bytes32 sourceAddress
    ) external onlyAuthorizedAdapter(chainId, sourceAddress) {}

    function sendMessagePublic(
        uint256 toChainId,
        address refundAddress,
        CrossChainGas calldata gas,
        bytes memory payload
    ) external {
        return _sendMessage(toChainId, refundAddress, gas, payload);
    }
}
