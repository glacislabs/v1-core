// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroGMPMock, GlacisLayerZeroAdapter, WormholeRelayerMock, GlacisWormholeAdapter} from "../LocalTestSetup.sol";
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

contract CustomAdapterTests is LocalTestSetup {
    using AddressBytes32 for address;

    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;

    LayerZeroGMPMock internal lzGatewayMock;
    GlacisLayerZeroAdapter internal lzAdapter;

    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;

    address internal customAdapter;

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

        customAdapter = address(
            new CustomAdapterSample(address(glacisRouter), address(this))
        );
        clientSample.addCustomAdapter(customAdapter);
    }

    function test__Abstraction_CustomAdapter(uint256 val) external {
        uint8[] memory gmps = new uint8[](0);
        uint256[] memory fees = new uint256[](1);
        fees[0] = 0.1 ether;
        address[] memory customAdapters = new address[](1);
        customAdapters[0] = customAdapter;

        clientSample.setRemoteValue{value: 0.1 ether}(
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

        assertEq(clientSample.value(), val);
    }

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

    function test__Quorum_ShouldStopFinalExecutionWithCustomAdapter(uint256 val) external {
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

    receive() external payable {}
}
