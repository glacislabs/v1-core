// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisRouter, GlacisCommons, CCIPRouterMock, GlacisCCIPAdapter} from "../../LocalTestSetup.sol";
import {GlacisClientSample} from "../../contracts/samples/GlacisClientSample.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {GlacisAbstractAdapter__OnlyAdapterAllowed, GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__NoRemoteAdapterForChainId, GlacisAbstractAdapter__OnlyGlacisRouterAllowed, GlacisAbstractAdapter__SourceChainNotRegistered, GlacisAbstractAdapter__ChainIsNotAvailable} from "../../../contracts/adapters/GlacisAbstractAdapter.sol";
import {GlacisCCIPAdapter__PaymentTooSmallForAnyDestinationExecution, GlacisCCIPAdapter__RefundAddressMustReceiveNativeCurrency} from "../../../contracts/adapters/GlacisCCIPAdapter.sol";
import {AddressBytes32} from "../../../contracts/libraries/AddressBytes32.sol";

// solhint-disable-next-line
contract AdapterTests__CCIP is LocalTestSetup {
    CCIPRouterMock internal ccipRouterMock;
    GlacisCCIPAdapter internal ccipAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    using Strings for address;
    using AddressBytes32 for address;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (ccipRouterMock) = deployCCIPFixture();
        ccipAdapter = deployCCIPAdapter(glacisRouter, ccipRouterMock);
        (clientSample, ) = deployGlacisClientSample(glacisRouter);
    }

    function test__setGlacisChainIds_CCIP(uint64 chain) external {
        vm.assume(chain != 0);

        uint256[] memory chains = new uint256[](1);
        chains[0] = chain;
        uint64[] memory ccipDomains = new uint64[](1);
        ccipDomains[0] = chain;

        ccipAdapter.setGlacisChainIds(chains, ccipDomains);

        assertEq(ccipAdapter.adapterChainID(chain), chain);
        assertEq(ccipAdapter.adapterChainIdToGlacisChainId(chain), chain);
        assertTrue(ccipAdapter.chainIsAvailable(chain));
    }

    function test__setGlacisChainIdsErrors_CCIP(
        uint256 chain,
        uint64 ccipId
    ) external {
        vm.assume(chain != 0);
        vm.assume(ccipId > 0);

        uint256[] memory chains = new uint256[](1);
        chains[0] = chain;
        uint64[] memory ccipDomains = new uint64[](2);
        ccipDomains[0] = ccipId;
        ccipDomains[1] = ccipId;

        vm.expectRevert(
            GlacisAbstractAdapter__IDArraysMustBeSameLength.selector
        );
        ccipAdapter.setGlacisChainIds(chains, ccipDomains);

        ccipDomains = new uint64[](1);
        ccipDomains[0] = ccipId;
        chains[0] = 0;

        vm.expectRevert(
            GlacisAbstractAdapter__DestinationChainIdNotValid.selector
        );
        ccipAdapter.setGlacisChainIds(chains, ccipDomains);
    }

    function test__chainIsNotAvailable_CCIP(uint256 chainId) external {
        vm.assume(chainId != block.chainid);
        assertFalse(ccipAdapter.chainIsAvailable(chainId));
    }

    function test__sendMessageOnlyAllowsAdapter_CCIP(uint256 chainId) external {
        vm.assume(chainId != 0);
        GlacisCCIPAdapterHarness harness = deployHarness();

        vm.expectRevert(GlacisAbstractAdapter__OnlyGlacisRouterAllowed.selector);
        harness.sendMessagePublic(
            chainId,
            address(this),
            CrossChainGas(100, 100),
            abi.encode(0)
        );
    }

    function test__sendMessageChecksAvailability_CCIP(uint256 chainId) external {
        vm.assume(chainId != 0);
        GlacisCCIPAdapterHarness harness = deployHarness();

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

        // Test no Axelar chain label
        vm.startPrank(address(glacisRouter));
        vm.expectRevert(abi.encodeWithSelector(GlacisAbstractAdapter__ChainIsNotAvailable.selector, chainId));
        harness.sendMessagePublic(
            chainId,
            address(this),
            CrossChainGas(100, 100),
            abi.encode(0)
        );
    }

    function test__extrapolateGasLimitFailsAtLowValue_CCIP() external {
        vm.expectRevert(GlacisCCIPAdapter__PaymentTooSmallForAnyDestinationExecution.selector);
        ccipAdapter.extrapolateGasLimitFromValue(
            10,    // too low
            uint64(block.chainid),
            abi.encode("")
        );
    }

    function test__extrapolateGasLimitDoesNotGoOverCCIPLimit_CCIP() external {
        uint256 estimate = ccipAdapter.extrapolateGasLimitFromValue(
            100 ether,    // too much gas for actual use
            uint64(block.chainid),
            abi.encode("")
        );

        // Currently limit is 3 million gas
        // https://docs.chain.link/ccip/service-limits
        assertLe(estimate, 3_000_000);
    }

    function test__allowsDefiningOwnGas_CCIP() external {
        address[] memory adapters = new address[](1);
        adapters[0] = CCIP_GMP_ID;
        CrossChainGas[] memory fees = new CrossChainGas[](1);
        fees[0] = CrossChainGas(100_000, 1 ether);

        clientSample.setRemoteValue{ value: 1 ether }(
            block.chainid, 
            address(clientSample).toBytes32(), 
            abi.encode(1), 
            adapters, 
            fees, 
            address(0x123), // EOA that can receive currency 
            false, 
            1 ether
        );
    }

    function test__definingOwnGasCannotHaveTooLowFee_CCIP() external {
        address[] memory adapters = new address[](1);
        adapters[0] = CCIP_GMP_ID;
        CrossChainGas[] memory fees = new CrossChainGas[](1);
        fees[0] = CrossChainGas(100_000, 1000);

        vm.expectRevert(GlacisCCIPAdapter__PaymentTooSmallForAnyDestinationExecution.selector);
        clientSample.setRemoteValue{ value: 1000 }(
            block.chainid, 
            address(clientSample).toBytes32(), 
            abi.encode(1), 
            adapters, 
            fees, 
            address(0x123), // EOA that can receive currency 
            false, 
            1000
        );
    }

    function test__enforcesSourceChainRefund_CCIP() external {
        address[] memory adapters = new address[](1);
        adapters[0] = CCIP_GMP_ID;
        CrossChainGas[] memory fees = new CrossChainGas[](1);
        fees[0] = CrossChainGas(100_000, 1 ether);

        vm.expectRevert(GlacisCCIPAdapter__RefundAddressMustReceiveNativeCurrency.selector);
        clientSample.setRemoteValue{ value: 1 ether }(
            block.chainid, 
            address(clientSample).toBytes32(), 
            abi.encode(1), 
            adapters, 
            fees, 
            address(this), // This contract does not accept refunds
            false, 
            1 ether
        );
    }

    function deployHarness() private returns (GlacisCCIPAdapterHarness) {
        return new GlacisCCIPAdapterHarness(
            address(glacisRouter),
            address(ccipRouterMock),
            address(this)
        );
    }
}

contract GlacisCCIPAdapterHarness is GlacisCCIPAdapter, GlacisCommons {
    constructor(
        address _glacisRouter,
        address _ccipMailbox,
        address _owner
    ) GlacisCCIPAdapter(_glacisRouter, _ccipMailbox, _owner) {}

    function sendMessagePublic(
        uint256 toChainId,
        address refundAddress,
        CrossChainGas calldata gas,
        bytes memory payload
    ) external payable {
        _sendMessage(toChainId, refundAddress, gas, payload);
    }
}