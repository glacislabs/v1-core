// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroGMPMock, GlacisLayerZeroAdapter} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {GlacisAbstractAdapter__OnlyAdapterAllowed} from "../../contracts/adapters/GlacisAbstractAdapter.sol";
import {SimpleNonblockingLzAppEvents} from "../../contracts/adapters/LayerZero/SimpleNonblockingLzApp.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";

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
        (clientSample,) = deployGlacisClientSample(glacisRouter);
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
        (clientSample,) = deployGlacisClientSample(glacisRouter);
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
        lzAdapterHarness.harness_onlyAuthorizedAdapter(chainId, origin.toBytes32());
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
