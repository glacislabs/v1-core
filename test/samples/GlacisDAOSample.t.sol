// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

import {LocalTestSetup} from "../LocalTestSetup.sol";
import {GlacisDAOSample, GlacisDAOSample__NotEnoughMessageValueRemainingForFees} from "../../contracts/samples/GlacisDAOSample.sol";
import {IGlacisRouterEvents} from "../../contracts/interfaces/IGlacisRouter.sol";
import {GlacisTokenMediator} from "../../contracts/mediators/GlacisTokenMediator.sol";
import {GlacisRouter, GlacisRouter__MessageAlreadyReceivedFromGMP} from "../../contracts/routers/GlacisRouter.sol";
import {GlacisAxelarAdapter} from "../../contracts/adapters/GlacisAxelarAdapter.sol";
import {AxelarGatewayMock} from "../mocks/axelar/AxelarGatewayMock.sol";
import {AxelarRetryGatewayMock} from "../mocks/axelar/AxelarRetryGatewayMock.sol";
import {AxelarGasServiceMock} from "../mocks/axelar/AxelarGasServiceMock.sol";
import {LayerZeroGMPMock} from "../mocks/lz/LayerZeroMock.sol";

contract GlacisDaoSampleTests is LocalTestSetup, IGlacisRouterEvents {
    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;
    GlacisRouter internal glacisRouter;
    GlacisTokenMediator internal glacisTokenMediator;
    GlacisDAOSample internal clientSample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (axelarGatewayMock, axelarGasServiceMock) = deployAxelarFixture();
        axelarAdapter = deployAxelarAdapters(
            glacisRouter,
            axelarGatewayMock,
            axelarGasServiceMock
        );
        LayerZeroGMPMock lzEndpoint = deployLayerZeroFixture();
        deployLayerZeroAdapters(glacisRouter, lzEndpoint);

        address[] memory members = new address[](1);
        members[0] = address(this);

        (glacisTokenMediator, , , , , , ) = deployGlacisTokenFixture(
            glacisRouter
        );

        clientSample = deployGlacisDAOSample(
            members,
            glacisRouter,
            glacisTokenMediator
        );
    }

    function sendSelfConfigProposal() internal {
        // Set up generic proposal
        GlacisDAOSample.Proposal[] memory p = new GlacisDAOSample.Proposal[](1);
        uint8[] memory gmps = new uint8[](1);
        gmps[0] = AXELAR_GMP_ID;
        p[0] = GlacisDAOSample.Proposal(
            block.chainid, // toChain
            true, // retry
            gmps, // gmps
            address(0), // token
            0, // tokenAmount
            address(clientSample), // finalTo
            0, // call value
            abi.encodeWithSelector(GlacisDAOSample.selfConfig.selector, "hello") // payload
        );

        clientSample.propose(p);
    }

    function test_SampleDAO_Proposal() external {
        sendSelfConfigProposal();

        // Test main
        (GlacisDAOSample.Proposal[] memory newP, , uint256 votes) = clientSample
            .getProposalData(0);
        assertEq(1, clientSample.nextProposal());
        assertEq(1, newP.length);
        assertEq(0, votes);

        // Test proposal data
        assertEq(newP[0].toChain, block.chainid);
        assertEq(newP[0].finalTo, address(clientSample));
        assertEq(newP[0].retriable, true);
        assertEq(newP[0].gmps.length, 1);
        assertEq(newP[0].gmps[0], AXELAR_GMP_ID);
        assertEq(
            newP[0].calldataPayload,
            abi.encodeWithSelector(GlacisDAOSample.selfConfig.selector, "hello")
        );
    }

    function test_SampleDAO_Retry() external {
        // Set up retry mock by replacing the gateway & adapter
        AxelarRetryGatewayMock mock = deployAxelarRetryFixture();
        GlacisAxelarAdapter adapter = new GlacisAxelarAdapter(
            address(glacisRouter),
            address(mock),
            address(axelarGasServiceMock),
            address(this)
        );
        // Add chain IDs
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = block.chainid;
        string[] memory axelarLabels = new string[](1);
        axelarLabels[0] = "Anvil";
        adapter.setGlacisChainIds(glacisIDs, axelarLabels);
        adapter.addRemoteAdapter(block.chainid, address(adapter));

        glacisRouter.registerAdapter(AXELAR_GMP_ID, address(adapter));
        assertEq(
            glacisRouter.glacisGMPIdToAdapter(AXELAR_GMP_ID),
            address(adapter)
        );

        // Send first proposal
        sendSelfConfigProposal();
        assertEq("", clientSample.configText());
        assertEq(0, clientSample.configVersion());

        // Approve first proposal
        uint256[][] memory fees = new uint256[][](1);
        fees[0] = createFees(0.2 ether / glacisIDs.length, glacisIDs.length);
        vm.expectEmit(false, false, false, true, address(glacisRouter));
        emit IGlacisRouterEvents.GlacisAbstractRouter__MessageIdCreated(
            bytes32(0),
            address(clientSample),
            0
        );
        clientSample.approve{value: 0.2 ether}(0, vm.addr(1), fees);

        // Should have no changes because of retry mock
        assertEq("", clientSample.configText());
        assertEq(0, clientSample.configVersion());

        // But should have a messageId
        (, bytes32[] memory messageIDs, ) = clientSample.getProposalData(0);
        assertNotEq(messageIDs[0], bytes32(uint256(0)));
        assertEq(
            address(clientSample),
            glacisRouter.messageSenders(messageIDs[0])
        );

        // Attempt retry
        clientSample.retry{value: 0.2 ether}(
            0,
            0,
            0,
            createFees(0.2 ether / glacisIDs.length, glacisIDs.length)
        );

        // Now changes should have appeared
        assertEq("hello", clientSample.configText());
        assertEq(1, clientSample.configVersion());

        // Attempt retry, should revert
        vm.expectRevert(GlacisRouter__MessageAlreadyReceivedFromGMP.selector);
        clientSample.retry{value: 0.2 ether}(
            0,
            0,
            0,
            createFees(0.2 ether / glacisIDs.length, glacisIDs.length)
        );
    }

    function test_SampleDAO_AbstractSelfCall() external {
        DAOAbstractCallTester abstractHarness = new DAOAbstractCallTester();
        bytes memory call = abi.encodeWithSelector(
            DAOAbstractCallTester.setValue.selector,
            uint256(128)
        );

        // Set up call proposal
        uint8[] memory gmps = new uint8[](1);
        gmps[0] = AXELAR_GMP_ID;
        GlacisDAOSample.Proposal[] memory p = new GlacisDAOSample.Proposal[](1);
        p[0] = GlacisDAOSample.Proposal(
            block.chainid, // toChain
            true, // retry
            gmps, // gmps
            address(0), // token
            0, // tokenAmount
            address(abstractHarness), // finalTo
            0, // call value
            call
        );

        clientSample.propose(p);

        // Now approve
        uint256[][] memory fees = new uint256[][](1);
        fees[0] = createFees(1 ether / gmps.length, gmps.length);
        clientSample.approve{value: 1 ether}(0, msg.sender, fees);

        // Assert value change
        assertEq(128, abstractHarness.value());
    }

    function test_SampleDAO_FeesWithTooSmallValueShouldFail() external {
        // Set up proposal with complex fees & routes
        GlacisDAOSample.Proposal[] memory p = new GlacisDAOSample.Proposal[](2);
        uint8[] memory gmps = new uint8[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;
        p[0] = GlacisDAOSample.Proposal(
            block.chainid, // toChain
            false, // retry
            gmps, // gmps
            address(0), // token
            0, // tokenAmount
            address(clientSample), // finalTo
            0, // call value
            abi.encodeWithSelector(GlacisDAOSample.selfConfig.selector, "hello") // payload
        );
        p[1] = GlacisDAOSample.Proposal(
            block.chainid, // toChain
            false, // retry
            gmps, // gmps
            address(0), // token
            0, // tokenAmount
            address(clientSample), // finalTo
            0, // call value
            abi.encodeWithSelector(GlacisDAOSample.selfConfig.selector, "hello") // payload
        );

        clientSample.propose(p);

        // Set up fees
        uint256[][] memory fees = new uint256[][](2);
        uint256[] memory destOneFees = new uint256[](2);
        uint256[] memory destTwoFees = new uint256[](2);
        destOneFees[0] = 0.3 ether;
        destOneFees[1] = 0.2 ether;
        destTwoFees[0] = 0.1 ether;
        destTwoFees[1] = 0.1 ether;
        fees[0] = destOneFees;
        fees[1] = destTwoFees;

        // Approve with the fees
        vm.expectRevert(
            GlacisDAOSample__NotEnoughMessageValueRemainingForFees.selector
        );
        clientSample.approve{value: 0.6 ether}(0, fees);
    }

    event Transfer(address indexed from, address indexed to, uint256 value);

    function test_SampleDAO_XTokenForward() external {
        address SAMPLE_TOKEN = address(clientSample.SAMPLE_TOKEN());

        GlacisDAOSample.Proposal[] memory p = new GlacisDAOSample.Proposal[](1);
        uint8[] memory gmps = new uint8[](1);
        gmps[0] = AXELAR_GMP_ID;
        p[0] = GlacisDAOSample.Proposal(
            block.chainid, // toChain
            true, // retry
            gmps, // gmps
            address(SAMPLE_TOKEN), // token
            1 ether, // tokenAmount
            address(clientSample), // finalTo
            0, // call value
            abi.encodeWithSelector(GlacisDAOSample.selfConfig.selector, "hello") // payload
        );

        clientSample.propose(p);

        // Assert that there will be a burn & mint
        vm.expectEmit(true, true, false, true, address(SAMPLE_TOKEN));
        emit Transfer(address(clientSample), address(0), 1 ether);
        vm.expectEmit(true, true, false, true, address(SAMPLE_TOKEN));
        emit Transfer(address(0), address(clientSample), 1 ether);

        uint256[][] memory fees = new uint256[][](1);
        fees[0] = createFees(1 ether / gmps.length, gmps.length);
        clientSample.approve{value: 1 ether}(0, msg.sender, fees);
    }

    receive() external payable {}
}

contract DAOAbstractCallTester {
    uint256 public value;

    function setValue(uint256 _value) public {
        value = _value;
    }
}
