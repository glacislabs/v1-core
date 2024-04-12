// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroGMPMock} from "../LocalTestSetup.sol";
import {GlacisTokenMediator, GlacisTokenClientSampleSource, GlacisTokenClientSampleDestination, XERC20Sample, ERC20Sample, XERC20LockboxSample, XERC20NativeLockboxSample} from "../LocalTestSetup.sol";
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
import {GlacisRouter__FeeArrayMustEqualGMPArray, GlacisRouter__OnlyAdaptersAllowed, GlacisRouter__MessageAlreadyReceivedFromGMP} from "../../contracts/routers/GlacisRouter.sol";
import "forge-std/console.sol";

contract CustomAdapterTokenTests is LocalTestSetup {
    using AddressBytes32 for address;

    GlacisRouter internal glacisRouter;
    GlacisTokenMediator internal glacisTokenMediator;
    XERC20Sample internal xERC20Sample;
    ERC20Sample internal erc20Sample;
    XERC20LockboxSample internal xERC20LockboxSample;
    XERC20NativeLockboxSample internal xERC20NativeLockboxSample;
    GlacisTokenClientSampleSource internal glacisTokenClientSampleSource;
    GlacisTokenClientSampleDestination
        internal glacisTokenClientSampleDestination;

    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;

    address internal customAdapter;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (
            glacisTokenMediator,
            xERC20Sample,
            erc20Sample,
            xERC20LockboxSample,
            xERC20NativeLockboxSample,
            glacisTokenClientSampleSource,
            glacisTokenClientSampleDestination
        ) = deployGlacisTokenFixture(glacisRouter);
        (axelarGatewayMock, axelarGasServiceMock) = deployAxelarFixture();
        axelarAdapter = deployAxelarAdapters(
            glacisRouter,
            axelarGatewayMock,
            axelarGasServiceMock
        );
        customAdapter = address(
            new CustomAdapterSample(address(glacisRouter), address(this))
        );
        glacisTokenClientSampleSource.addCustomAdapter(customAdapter);
        glacisTokenClientSampleDestination.addCustomAdapter(customAdapter);
    }

    function test__Abstraction_CustomAdapterToken(uint256 amount) external {
        vm.assume(amount < 10e15);
        xERC20Sample.transfer(address(glacisTokenClientSampleSource), amount);
        uint256 preSourceBalance = xERC20Sample.balanceOf(
            address(glacisTokenClientSampleSource)
        );
        uint256 preDestinationBalance = xERC20Sample.balanceOf(
            address(glacisTokenClientSampleDestination)
        );
        uint256 preDestinationValue = glacisTokenClientSampleDestination
            .value();

        uint8[] memory gmps = new uint8[](0);
        address[] memory customAdapters = new address[](1);
        customAdapters[0] = customAdapter;

        glacisTokenClientSampleSource.sendMessageAndTokens{value: 0.1 ether}(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            gmps,
            customAdapters,
            createFees(0.1 ether, 1),
            abi.encode(amount),
            address(xERC20Sample),
            amount
        );

        assertEq(glacisTokenClientSampleDestination.value(), preDestinationValue + amount);
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preSourceBalance - amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            preDestinationBalance + amount
        );
    }

    /*

    function test__FeeArrayFailureWithCustomAdapter(uint256 val) external {
        uint8[] memory gmps = new uint8[](1);
        gmps[0] = 1;
        uint256[] memory fees = new uint256[](1);
        fees[0] = 0.2 ether;
        address[] memory customAdapters = new address[](1);
        customAdapters[0] = customAdapter;

        vm.expectRevert(GlacisRouter__FeeArrayMustEqualGMPArray.selector);
        clientSample.setRemoteValue{value: 0.2 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(val),
            gmps,
            customAdapters,
            fees,
            address(this),
            false,
            0.1 ether
        );
    }

    function test__Redundancy_CustomAdapterAndGMP(uint256 val) external {
        uint8[] memory gmps = new uint8[](1);
        gmps[0] = 1;
        address[] memory customAdapters = new address[](1);
        customAdapters[0] = customAdapter;
        uint256[] memory fees = new uint256[](2);
        fees[0] = 0.2 ether;
        fees[1] = 0.2 ether;

        clientSample.setQuorum(2);

        clientSample.setRemoteValue{value: 0.4 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(val),
            gmps,
            customAdapters,
            fees,
            address(this),
            false,
            0.4 ether
        );

        assertEq(clientSample.value(), val);
    }

    function test__Redundancy_TwoCustomAdapters(uint256 val) external {
        address notAddedCustomAdapter = address(
            new CustomAdapterSample(address(glacisRouter), address(this))
        );
        clientSample.addCustomAdapter(notAddedCustomAdapter);

        uint8[] memory gmps = new uint8[](0);
        address[] memory customAdapters = new address[](2);
        customAdapters[0] = customAdapter;
        customAdapters[1] = notAddedCustomAdapter;

        clientSample.setQuorum(2);

        clientSample.setRemoteValue{value: 0.4 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(val),
            gmps,
            customAdapters,
            createFees(0.2 ether, 2),
            address(this),
            false,
            0.4 ether
        );

        assertEq(clientSample.value(), val);
    }

    function test__Redundancy_TwoCustomAdaptersTwoGMPs(uint256 val) external {
        address notAddedCustomAdapter = address(
            new CustomAdapterSample(address(glacisRouter), address(this))
        );
        clientSample.addCustomAdapter(notAddedCustomAdapter);

        uint8[] memory gmps = new uint8[](2);
        gmps[0] = 1;
        gmps[1] = 2;
        address[] memory customAdapters = new address[](2);
        customAdapters[0] = customAdapter;
        customAdapters[1] = notAddedCustomAdapter;

        clientSample.setQuorum(4);

        clientSample.setRemoteValue{value: 0.8 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(val),
            gmps,
            customAdapters,
            createFees(0.2 ether, 4),
            address(this),
            false,
            0.8 ether
        );

        assertEq(clientSample.value(), val);
    }

    function test__Quorum_SameCustomAdapter(uint256 val) external {
        vm.assume(clientSample.value() != val);

        uint8[] memory gmps = new uint8[](0);
        address[] memory customAdapters = new address[](2);
        customAdapters[0] = customAdapter;
        customAdapters[1] = customAdapter;

        clientSample.setQuorum(2);

        vm.expectRevert(GlacisRouter__MessageAlreadyReceivedFromGMP.selector);
        clientSample.setRemoteValue{value: 0.4 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(val),
            gmps,
            customAdapters,
            createFees(0.2 ether, 2),
            address(this),
            false,
            0.4 ether
        );
    }

    function test__Quorum_ShouldStopFinalExecutionWithCustomAdapter(
        uint256 val
    ) external {
        vm.assume(clientSample.value() != val);

        address notAddedCustomAdapter = address(
            new CustomAdapterSample(address(glacisRouter), address(this))
        );
        clientSample.addCustomAdapter(notAddedCustomAdapter);

        uint8[] memory gmps = new uint8[](0);
        address[] memory customAdapters = new address[](2);
        customAdapters[0] = customAdapter;
        customAdapters[1] = notAddedCustomAdapter;

        clientSample.setQuorum(2);

        clientSample.setRemoteValue{value: 0.4 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(val),
            gmps,
            customAdapters,
            createFees(0.2 ether, 2),
            address(this),
            false,
            0.4 ether
        );

        assertEq(clientSample.value(), val);
    }

    function test__FailureToReceiveWithoutAddingCustomAdapter(
        uint256 val
    ) external {
        address notAddedCustomAdapter = address(
            new CustomAdapterSample(address(glacisRouter), address(this))
        );

        uint8[] memory gmps = new uint8[](1);
        gmps[0] = 1;
        address[] memory customAdapters = new address[](1);
        customAdapters[0] = notAddedCustomAdapter;

        clientSample.setQuorum(2);

        vm.expectRevert(GlacisRouter__OnlyAdaptersAllowed.selector);
        clientSample.setRemoteValue{value: 0.4 ether}(
            block.chainid,
            address(clientSample).toBytes32(),
            abi.encode(val),
            gmps,
            customAdapters,
            createFees(0.2 ether, 2),
            address(this),
            false,
            0.4 ether
        );
    }

    */

    receive() external payable {}
}
