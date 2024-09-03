// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroV2Mock, GlacisLayerZeroV2Adapter, GlacisCommons} from "../LocalTestSetup.sol";
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
import {GlacisRouter__FeeArrayMustEqualGMPArray, GlacisRouter__ClientDeniedRoute, GlacisRouter__MessageAlreadyReceivedFromGMP} from "../../contracts/routers/GlacisRouter.sol";
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
    LayerZeroV2Mock internal lzGatewayMock;
    GlacisLayerZeroV2Adapter internal lzAdapter;

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
        (lzGatewayMock) = deployLayerZeroFixture();
        lzAdapter = deployLayerZeroAdapters(glacisRouter, lzGatewayMock);
        customAdapter = address(
            new CustomAdapterSample(address(glacisRouter), address(this))
        );

        // Add custom adapter to allowed routes
        glacisTokenClientSampleSource.addAllowedRoute(
            GlacisCommons.GlacisRoute(
                block.chainid, // fromChainId
                address(glacisTokenClientSampleDestination).toBytes32(), // from
                customAdapter // fromGmpId
            )
        );
        glacisTokenClientSampleDestination.addAllowedRoute(
            GlacisCommons.GlacisRoute(
                block.chainid, // fromChainId
                address(glacisTokenClientSampleSource).toBytes32(), // from
                customAdapter // fromGmpId
            )
        );
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

        address[] memory adapters = new address[](1);
        adapters[0] = customAdapter;

        glacisTokenClientSampleSource.sendMessageAndTokens{value: 0.1 ether}(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            adapters,
            createFees(0.1 ether, 1),
            abi.encode(amount),
            address(xERC20Sample),
            amount
        );

        assertEq(
            glacisTokenClientSampleDestination.value(),
            preDestinationValue + amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preSourceBalance - amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            preDestinationBalance + amount
        );
    }

    function test__FeeArrayFailureWithCustomAdapterToken(
        uint256 amount
    ) external {
        vm.assume(amount < 10e15);
        xERC20Sample.transfer(address(glacisTokenClientSampleSource), amount);

        address[] memory adapters = new address[](2);
        adapters[0] = AXELAR_GMP_ID;
        adapters[1] = customAdapter;
        CrossChainGas[] memory fees = createFees(0.1 ether, 1);

        vm.expectRevert(GlacisRouter__FeeArrayMustEqualGMPArray.selector);
        glacisTokenClientSampleSource.sendMessageAndTokens{value: 0.1 ether}(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            adapters,
            fees,
            abi.encode(amount),
            address(xERC20Sample),
            amount
        );
    }

    function test__Redundancy_CustomAdapterAndGMPToken(
        uint256 amount
    ) external {
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

        address[] memory adapters = new address[](2);
        adapters[0] = AXELAR_GMP_ID;
        adapters[1] = customAdapter;

        glacisTokenClientSampleDestination.setQuorum(2);
        glacisTokenClientSampleSource.sendMessageAndTokens{value: 0.4 ether}(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            adapters,
            createFees(0.2 ether, 2),
            abi.encode(amount),
            address(xERC20Sample),
            amount
        );

        assertEq(
            glacisTokenClientSampleDestination.value(),
            preDestinationValue + amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preSourceBalance - amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            preDestinationBalance + amount
        );
    }

    function test__Redundancy_TwoCustomAdaptersToken(uint256 amount) external {
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

        // Create second adapter & pack it
        address[] memory adapters = new address[](2);
        {
            adapters[0] = customAdapter;

            address notAddedCustomAdapter = address(
                new CustomAdapterSample(address(glacisRouter), address(this))
            );
            adapters[1] = notAddedCustomAdapter;

            glacisTokenClientSampleSource.addAllowedRoute(
                GlacisCommons.GlacisRoute(
                    block.chainid, // fromChainId
                    address(glacisTokenClientSampleDestination).toBytes32(), // from
                    notAddedCustomAdapter // fromGmpId
                )
            );
            glacisTokenClientSampleDestination.addAllowedRoute(
                GlacisCommons.GlacisRoute(
                    block.chainid, // fromChainId
                    address(glacisTokenClientSampleSource).toBytes32(), // from
                    notAddedCustomAdapter // fromGmpId
                )
            );
        }

        glacisTokenClientSampleDestination.setQuorum(2);
        glacisTokenClientSampleSource.sendMessageAndTokens{value: 0.4 ether}(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            adapters,
            createFees(0.2 ether, 2),
            abi.encode(amount),
            address(xERC20Sample),
            amount
        );

        assertEq(
            glacisTokenClientSampleDestination.value(),
            preDestinationValue + amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preSourceBalance - amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            preDestinationBalance + amount
        );
    }

    function test__Redundancy_TwoCustomAdaptersTwoGMPsToken(
        uint256 amount
    ) external {
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

        // Create gmps + customAdapters
        address[] memory adapters = new address[](4);
        {
            adapters[0] = customAdapter;

            address notAddedCustomAdapter = address(
                new CustomAdapterSample(address(glacisRouter), address(this))
            );
            adapters[1] = notAddedCustomAdapter;

            glacisTokenClientSampleSource.addAllowedRoute(
                GlacisCommons.GlacisRoute(
                    block.chainid, // fromChainId
                    address(glacisTokenClientSampleDestination).toBytes32(), // from
                    notAddedCustomAdapter // fromGmpId
                )
            );
            glacisTokenClientSampleDestination.addAllowedRoute(
                GlacisCommons.GlacisRoute(
                    block.chainid, // fromChainId
                    address(glacisTokenClientSampleSource).toBytes32(), // from
                    notAddedCustomAdapter // fromGmpId
                )
            );
        }
        adapters[2] = AXELAR_GMP_ID;
        adapters[3] = LAYERZERO_GMP_ID;

        glacisTokenClientSampleDestination.setQuorum(4);
        glacisTokenClientSampleSource.sendMessageAndTokens{value: 0.8 ether}(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            adapters,
            createFees(0.2 ether, 4),
            abi.encode(amount),
            address(xERC20Sample),
            amount
        );

        assertEq(
            glacisTokenClientSampleDestination.value(),
            preDestinationValue + amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preSourceBalance - amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            preDestinationBalance + amount
        );
    }

    function test__Quorum_ShouldStopFinalExecutionWithCustomAdapter(
        uint256 amount
    ) external {
        vm.assume(glacisTokenClientSampleDestination.value() != amount);
        vm.assume(amount < 10e15);

        xERC20Sample.transfer(address(glacisTokenClientSampleSource), amount);

        address[] memory adapters = new address[](2);
        adapters[0] = customAdapter;
        adapters[1] = customAdapter;

        glacisTokenClientSampleDestination.setQuorum(2);

        vm.expectRevert(GlacisRouter__MessageAlreadyReceivedFromGMP.selector);
        glacisTokenClientSampleSource.sendMessageAndTokens{value: 0.4 ether}(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            adapters,
            createFees(0.2 ether, 2),
            abi.encode(amount),
            address(xERC20Sample),
            amount
        );
    }

    function test__FailureToReceiveWithoutAddingCustomAdapterToken(
        uint256 amount
    ) external {
        vm.assume(amount < 10e15);
        xERC20Sample.transfer(address(glacisTokenClientSampleSource), amount);

        address notAddedCustomAdapter = address(
            new CustomAdapterSample(address(glacisRouter), address(this))
        );
        address[] memory adapters = new address[](1);
        adapters[0] = notAddedCustomAdapter;

        glacisTokenClientSampleDestination.setQuorum(1);

        vm.expectRevert(GlacisRouter__ClientDeniedRoute.selector);
        glacisTokenClientSampleSource.sendMessageAndTokens{value: 0.4 ether}(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            adapters,
            createFees(0.4 ether, 1),
            abi.encode(amount),
            address(xERC20Sample),
            amount
        );
    }

    receive() external payable {}
}
