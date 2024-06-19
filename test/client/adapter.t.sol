// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroGMPMock, GlacisLayerZeroAdapter, GlacisCommons} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {GlacisAbstractAdapter__OnlyAdapterAllowed, GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__NoRemoteAdapterForChainId, GlacisAbstractAdapter__OnlyGlacisRouterAllowed, GlacisAbstractAdapter__SourceChainNotRegistered} from "../../contracts/adapters/GlacisAbstractAdapter.sol";
import {IGlacisAdapter} from "../../contracts/interfaces/IGlacisAdapter.sol";
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
    using AddressBytes32 for address;

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

    function test__setGlacisChainIds_Axelar(
        uint256 chain,
        string memory name
    ) external {
        vm.assume(chain != 0);
        vm.assume(bytes(name).length > 0);

        uint256[] memory chains = new uint256[](1);
        chains[0] = chain;
        string[] memory axelarNames = new string[](1);
        axelarNames[0] = name;

        axelarAdapter.setGlacisChainIds(chains, axelarNames);

        assertEq(axelarAdapter.glacisChainIdToAdapterChainId(chain), name);
        assertEq(axelarAdapter.adapterChainIdToGlacisChainId(name), chain);
        assertTrue(axelarAdapter.chainIsAvailable(chain));
    }

    function test__setGlacisChainIdsErrors_Axelar(
        uint256 chain,
        string memory name
    ) external {
        vm.assume(chain != 0);
        vm.assume(bytes(name).length > 0);

        uint256[] memory chains = new uint256[](1);
        chains[0] = chain;
        string[] memory axelarNames = new string[](2);
        axelarNames[0] = name;
        axelarNames[0] = name;
        
        vm.expectRevert(GlacisAbstractAdapter__IDArraysMustBeSameLength.selector);
        axelarAdapter.setGlacisChainIds(chains, axelarNames);

        axelarNames = new string[](1);
        axelarNames[0] = name;
        chains[0] = 0;
        
        vm.expectRevert(GlacisAbstractAdapter__DestinationChainIdNotValid.selector);
        axelarAdapter.setGlacisChainIds(chains, axelarNames);
    }

    function test__chainIsNotAvailable_Axelar(uint256 chainId) external {
        vm.assume(chainId != block.chainid);
        assertFalse(axelarAdapter.chainIsAvailable(chainId));
    }

    function test__toLowerCase_Axelar() external {
        string
            memory str1 = "!!!aaAabBbbcCcdDDeFGhIiJjjKkl%%%1234LmmmMnOoPpQRStTUvwwWxYyyyzZZzzz...";
        string
            memory convertStr1 = "!!!aaaabbbbcccdddefghiijjjkkl%%%1234lmmmmnooppqrsttuvwwwxyyyyzzzzzz...";
        GlacisAxelarAdapterHarness harness = deployHarness();

        assertEq(harness.toLowerCase(str1), convertStr1);
    }

    function test__sendMessageOnlyAllowsAdapter_Axelar(uint256 chainId) external {
        vm.assume(chainId != 0);
        GlacisAxelarAdapterHarness harness = deployHarness();

        vm.expectRevert(GlacisAbstractAdapter__OnlyGlacisRouterAllowed.selector);
        harness.sendMessagePublic(
            chainId,
            address(this),
            CrossChainGas(100, 100),
            abi.encode(0)
        );
    }

    function test__sendMessageChecksAvailability_Axelar(uint256 chainId) external {
        vm.assume(chainId != 0);
        GlacisAxelarAdapterHarness harness = new GlacisAxelarAdapterHarness(
            address(glacisRouter),
            address(axelarGatewayMock),
            address(axelarGasServiceMock),
            address(this)
        );

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
        vm.expectRevert(abi.encodeWithSelector(IGlacisAdapter.IGlacisAdapter__ChainIsNotAvailable.selector, chainId));
        harness.sendMessagePublic(
            chainId,
            address(this),
            CrossChainGas(100, 100),
            abi.encode(0)
        );
    }

    function deployHarness() private returns (GlacisAxelarAdapterHarness) {
        return new GlacisAxelarAdapterHarness(
            address(glacisRouter),
            address(axelarGatewayMock),
            address(axelarGasServiceMock),
            address(this)
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

contract GlacisAxelarAdapterHarness is GlacisAxelarAdapter, GlacisCommons {
    constructor(
        address _glacisRouter,
        address _axelarGateway,
        address _axelarGasReceiver,
        address _owner
    )
        GlacisAxelarAdapter(
            _glacisRouter,
            _axelarGateway,
            _axelarGasReceiver,
            _owner
        )
    {}

    function toLowerCase(
        string memory str
    ) external pure returns (string memory) {
        return _toLowerCase(str);
    }

    function sendMessagePublic(
        uint256 toChainId,
        address refundAddress,
        CrossChainGas calldata gas,
        bytes memory payload
    ) external {
        return _sendMessage(toChainId, refundAddress, gas, payload);
    }

    function executePublic(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) external {
        return _execute(sourceChain, sourceAddress, payload);
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
