// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, GlacisCommons, HyperlaneMailboxMock, GlacisHyperlaneAdapter} from "../../LocalTestSetup.sol";
import {GlacisClientSample} from "../../contracts/samples/GlacisClientSample.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {GlacisAbstractAdapter__OnlyAdapterAllowed, GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__NoRemoteAdapterForChainId, GlacisAbstractAdapter__OnlyGlacisRouterAllowed, GlacisAbstractAdapter__SourceChainNotRegistered, GlacisAbstractAdapter__ChainIsNotAvailable} from "../../../contracts/adapters/GlacisAbstractAdapter.sol";
import {GlacisHyperlaneAdapter__OnlyMailboxAllowed, GlacisHyperlaneAdapter__FeeNotEnough} from "../../../contracts/adapters/GlacisHyperlaneAdapter.sol";
import {IGlacisAdapter} from "../../../contracts/interfaces/IGlacisAdapter.sol";
import {SimpleNonblockingLzAppEvents} from "../../../contracts/adapters/LayerZero/SimpleNonblockingLzApp.sol";
import {AddressBytes32} from "../../../contracts/libraries/AddressBytes32.sol";

// solhint-disable-next-line
contract AdapterTests__Hyperlane is LocalTestSetup {
    HyperlaneMailboxMock internal mailboxMock;
    GlacisHyperlaneAdapter internal hyperlaneAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    using Strings for address;
    using AddressBytes32 for address;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (mailboxMock) = deployHyperlaneFixture();
        hyperlaneAdapter = deployHyperlaneAdapter(
            glacisRouter,
            mailboxMock
        );
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
    }

    function test__setGlacisChainIds_Hyperlane(uint32 chain) external {
        vm.assume(chain != 0);

        uint256[] memory chains = new uint256[](1);
        chains[0] = chain;
        uint32[] memory hyperlaneDomains = new uint32[](1);
        hyperlaneDomains[0] = chain;

        hyperlaneAdapter.setGlacisChainIds(chains, hyperlaneDomains);

        assertEq(hyperlaneAdapter.adapterChainID(chain), chain);
        assertEq(hyperlaneAdapter.adapterChainIdToGlacisChainId(chain), chain);
        assertTrue(hyperlaneAdapter.chainIsAvailable(chain));
    }

    function test__setGlacisChainIdsErrors_Hyperlane(uint32 chain) external {
        vm.assume(chain != 0);

        uint256[] memory chains = new uint256[](1);
        chains[0] = chain;
        uint32[] memory hyperlaneDomains = new uint32[](2);
        hyperlaneDomains[0] = chain;
        hyperlaneDomains[0] = chain;
        
        vm.expectRevert(GlacisAbstractAdapter__IDArraysMustBeSameLength.selector);
        hyperlaneAdapter.setGlacisChainIds(chains, hyperlaneDomains);

        hyperlaneDomains = new uint32[](1);
        hyperlaneDomains[0] = chain;
        chains[0] = 0;
        
        vm.expectRevert(GlacisAbstractAdapter__DestinationChainIdNotValid.selector);
        hyperlaneAdapter.setGlacisChainIds(chains, hyperlaneDomains);
    }

    function test__chainIsNotAvailable_Hyperlane(uint256 chainId) external {
        vm.assume(chainId != block.chainid);
        assertFalse(hyperlaneAdapter.chainIsAvailable(chainId));
    }

    function test__sendMessageChecksAvailability_Hyperlane(uint256 chainId) external {
        vm.assume(chainId != 0);
        GlacisHyperlaneAdapterHarness harness = deployHarness();

        // Test no remote adapter
        vm.startPrank(address(glacisRouter));
        vm.expectRevert(abi.encodeWithSelector(GlacisAbstractAdapter__NoRemoteAdapterForChainId.selector, chainId));
        harness.sendMessagePublic(
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
        harness.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        // Test no domain label
        vm.startPrank(address(glacisRouter));
        vm.expectRevert(abi.encodeWithSelector(GlacisAbstractAdapter__ChainIsNotAvailable.selector, chainId));
        harness.sendMessagePublic(
            chainId,
            address(this),
            CrossChainGas(100, 100),
            abi.encode(0)
        );
    }

    function test__handleOnlyAllowsMailbox_Hyperlane() external {
        // Add remote adapter to get past
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = 100;
        uint32[] memory hyperlaneDomains = new uint32[](1);
        hyperlaneDomains[0] = 100;
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(0x123).toBytes32();
        hyperlaneAdapter.setGlacisChainIds(glacisIDs, hyperlaneDomains);
        hyperlaneAdapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        // Test for bad mailbox
        vm.expectRevert(GlacisHyperlaneAdapter__OnlyMailboxAllowed.selector);
        hyperlaneAdapter.handle(100, adapterCounterparts[0], abi.encode(0));
    }

    function test__insufficientFee_Hyperlane() external {
        mailboxMock.setHookFee(1 ether);

        // Add remote adapter to get past
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = 100;
        uint32[] memory hyperlaneDomains = new uint32[](1);
        hyperlaneDomains[0] = 100;
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(0x123).toBytes32();
        hyperlaneAdapter.setGlacisChainIds(glacisIDs, hyperlaneDomains);
        hyperlaneAdapter.addRemoteCounterparts(glacisIDs, adapterCounterparts);

        vm.expectRevert(GlacisHyperlaneAdapter__FeeNotEnough.selector);
        address[] memory adapters = new address[](1);
        adapters[0] = HYPERLANE_GMP_ID;
        clientSample.setRemoteValue{ value: 1 ether - 1}(
            block.chainid, 
            address(clientSample).toBytes32(), 
            abi.encode(0), 
            adapters, 
            createFees(1 ether - 1, 1), 
            address(this), 
            false, 
            1 ether - 1
        );
    }

    function deployHarness() private returns (GlacisHyperlaneAdapterHarness) {
        return new GlacisHyperlaneAdapterHarness(
            address(glacisRouter),
            address(mailboxMock),
            address(this)
        );
    }
}

contract GlacisHyperlaneAdapterHarness is GlacisHyperlaneAdapter, GlacisCommons {
    constructor(
        address _glacisRouter,
        address _hyperlaneMailbox,
        address _owner
    ) GlacisHyperlaneAdapter(_glacisRouter, _hyperlaneMailbox, _owner) { }

    function sendMessagePublic(
        uint256 toChainId,
        address refundAddress,
        CrossChainGas calldata gas,
        bytes memory payload
    ) external payable {
        _sendMessage(toChainId, refundAddress, gas, payload);
    }
}