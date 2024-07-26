// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisRouter, LayerZeroGMPMock, GlacisLayerZeroAdapter, GlacisCommons} from "../../LocalTestSetup.sol";
import {GlacisClientSample} from "../../contracts/samples/GlacisClientSample.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {GlacisAbstractAdapter__OnlyAdapterAllowed, GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__NoRemoteAdapterForChainId, GlacisAbstractAdapter__OnlyGlacisRouterAllowed, GlacisAbstractAdapter__SourceChainNotRegistered, GlacisAbstractAdapter__ChainIsNotAvailable} from "../../../contracts/adapters/GlacisAbstractAdapter.sol";
import {IGlacisAdapter} from "../../../contracts/interfaces/IGlacisAdapter.sol";
import {SimpleNonblockingLzAppEvents} from "../../../contracts/adapters/LayerZero/SimpleNonblockingLzApp.sol";
import {AddressBytes32} from "../../../contracts/libraries/AddressBytes32.sol";

// | contracts/adapters/LayerZero/GlacisLayerZeroAdapter.sol       | 90.00% (18/20)    | 90.91% (20/22)    | 75.00% (6/8)     | 83.33% (5/6)     |

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

    function test__onlyAuthorizedAdapterFailure_LayerZero() external {
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

    function test__setGlacisChainIds_LayerZero(
        uint256 chain,
        uint16 lzId
    ) external {
        vm.assume(chain != 0);
        vm.assume(lzId > 0);

        uint256[] memory chains = new uint256[](1);
        chains[0] = chain;
        uint16[] memory lzIDs = new uint16[](1);
        lzIDs[0] = lzId;

        lzAdapter.setGlacisChainIds(chains, lzIDs);

        assertEq(lzAdapter.adapterChainID(chain), lzId);
        assertEq(lzAdapter.adapterChainIdToGlacisChainId(lzId), chain);
        assertTrue(lzAdapter.chainIsAvailable(chain));
    }

    function test__sendMessageChecksAvailability_LayerZero(uint256 chainId) external {
        vm.assume(chainId != 0);

        // Test no remote adapter
        vm.startPrank(address(glacisRouter));
        vm.expectRevert(abi.encodeWithSelector(GlacisAbstractAdapter__NoRemoteAdapterForChainId.selector, chainId));
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
        vm.expectRevert(abi.encodeWithSelector(GlacisAbstractAdapter__ChainIsNotAvailable.selector, chainId));
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
        uint16[] memory lzIDs = new uint16[](2);
        lzIDs[0] = lzId;
        lzIDs[0] = lzId;
        
        vm.expectRevert(GlacisAbstractAdapter__IDArraysMustBeSameLength.selector);
        lzAdapter.setGlacisChainIds(chains, lzIDs);

        lzIDs = new uint16[](1);
        lzIDs[0] = lzId;
        chains[0] = 0;
        
        vm.expectRevert(GlacisAbstractAdapter__DestinationChainIdNotValid.selector);
        lzAdapter.setGlacisChainIds(chains, lzIDs);
    }

    function test__chainIsNotAvailable_LayerZero(uint256 chainId) external {
        vm.assume(chainId != block.chainid);
        assertFalse(lzAdapter.chainIsAvailable(chainId));
    }
}

contract GlacisLayerZeroAdapterHarness is GlacisLayerZeroAdapter, GlacisCommons {
    constructor(
        address lzEndpoint_,
        address glacisRouter_,
        address owner
    ) GlacisLayerZeroAdapter(lzEndpoint_, glacisRouter_, owner) {}

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