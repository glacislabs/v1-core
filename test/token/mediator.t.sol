// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroV2Mock} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {GlacisTokenMediator__OnlyTokenMediatorAllowed} from "../../contracts/mediators/GlacisTokenMediator.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";

import {GlacisTokenMediator, XERC20Sample} from "../LocalTestSetup.sol";

contract TokenMediatorTests is LocalTestSetup {
    using AddressBytes32 for address;

    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;
    GlacisTokenMediator internal glacisTokenMediator;
    XERC20Sample internal xERC20Sample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (
            glacisTokenMediator,
            xERC20Sample,
            ,
            ,
            ,
            ,

        ) = deployGlacisTokenFixture(glacisRouter);
        (axelarGatewayMock, axelarGasServiceMock) = deployAxelarFixture();
        axelarAdapter = deployAxelarAdapters(
            glacisRouter,
            axelarGatewayMock,
            axelarGasServiceMock
        );
        LayerZeroV2Mock lzEndpoint = deployLayerZeroFixture();
        deployLayerZeroAdapters(glacisRouter, lzEndpoint);
    }

    function addRemoteMediator(uint256 chainId, bytes32 addr) internal {
        uint256[] memory chainIdArr = new uint256[](1);
        chainIdArr[0] = chainId;
        bytes32[] memory addrArr = new bytes32[](1);
        addrArr[0] = addr;
        glacisTokenMediator.addRemoteCounterparts(chainIdArr, addrArr);
    }

    function test__TokenMediator_AddsRemoteAddress(
        bytes32 addr,
        uint256 chainId
    ) external {
        vm.assume(chainId != 0);
        addRemoteMediator(chainId, addr);
        assertEq(glacisTokenMediator.getRemoteCounterpart(chainId), addr);
    }

    function test__TokenMediator_RemovesRemoteAddress(
        address addr,
        uint256 chainId
    ) external {
        vm.assume(chainId != 0);
        addRemoteMediator(chainId, addr.toBytes32());
        glacisTokenMediator.removeRemoteCounterpart(chainId);
        assertEq(glacisTokenMediator.getRemoteCounterpart(chainId), bytes32(0));
    }

    function test__TokenMediator_NonOwnersCannotAddRemote() external {
        vm.startPrank(address(0x123));
        vm.expectRevert("Ownable: caller is not the owner");
        addRemoteMediator(block.chainid, address(0x123).toBytes32());
    }

    function test__TokenMediator_NonOwnersCannotRemoveRemote() external {
        vm.startPrank(address(0x123));
        vm.expectRevert("Ownable: caller is not the owner");
        glacisTokenMediator.removeRemoteCounterpart(block.chainid);
    }

    function test__TokenMediator_RejectsExecuteFromNonMediatorSources(
        address addr,
        address otherAddr,
        uint256 chainId
    ) external {
        vm.assume(addr != otherAddr);
        vm.assume(chainId != 0);

        addRemoteMediator(chainId, addr.toBytes32());

        // Message is being received by the router
        vm.startPrank(address(glacisRouter));

        address[] memory gmpArray = new address[](1);
        gmpArray[0] = AXELAR_GMP_ID;

        vm.expectRevert(GlacisTokenMediator__OnlyTokenMediatorAllowed.selector);
        glacisTokenMediator.receiveMessage(
            gmpArray,
            chainId,
            address(otherAddr).toBytes32(), // fromAddress; this is what we're testing for
            bytes("")
        );
    }

    function test__TokenMediator_AcceptsExecuteFromMediatorSource(
        address addr,
        uint256 chainId
    ) external {
        vm.assume(chainId != 0);

        addRemoteMediator(chainId, addr.toBytes32());

        // Message is being received by the router
        vm.startPrank(address(glacisRouter));

        address[] memory gmpArray = new address[](1);
        gmpArray[0] = AXELAR_GMP_ID;

        glacisTokenMediator.receiveMessage(
            gmpArray,
            chainId,
            addr.toBytes32(),
            abi.encode(
                address(0x123),
                address(0x123),
                address(xERC20Sample),
                address(xERC20Sample),
                1,
                bytes("")
            )
        );
        assertEq(xERC20Sample.balanceOf(address(0x123)), 1);
    }

    function test__TokenMediator_IsAllowedRouteFalseWhenSendToEOAWithoutRemoteMediator(
        uint256 chainId
    ) external {
        vm.assume(chainId != 0);
        bytes memory payload = abi.encode(
            address(0x123), // EOA
            msg.sender,
            address(xERC20Sample),
            address(xERC20Sample),
            1,
            bytes("")
        );
        bool isAllowed = glacisTokenMediator.isAllowedRoute(
            GlacisRoute(
                chainId,
                address(0x456).toBytes32(), // wrong mediator address (what we're testing)
                AXELAR_GMP_ID
            ),
            payload
        );
        assertFalse(isAllowed);
    }

    function test__TokenMediator_IsAllowedRouteTrueWhenSendToEOAWithRemoteMediator(
        address addr,
        uint256 chainId
    ) external {
        vm.assume(chainId != 0);
        vm.assume(addr != address(0) && addr.code.length == 0);
        bytes memory payload = abi.encode(
            address(0x123), // EOA
            msg.sender,
            address(xERC20Sample),
            address(xERC20Sample),
            1,
            bytes("")
        );
        addRemoteMediator(chainId, addr.toBytes32());
        bool isAllowed = glacisTokenMediator.isAllowedRoute(
            GlacisRoute(
                chainId,
                addr.toBytes32(), // correct mediator address (what we're testing)
                AXELAR_GMP_ID
            ),
            payload
        );
        assertTrue(isAllowed);
    }

    function test__TokenMediator_IsAllowedRouteFalseWhenSendToEOAWithCustomAdapter(
        address addr,
        uint256 chainId
    ) external {
        vm.assume(chainId != 0);
        vm.assume(addr != address(0) && addr.code.length == 0);
        bytes memory payload = abi.encode(
            address(0x123), // EOA
            msg.sender,
            address(xERC20Sample),
            address(xERC20Sample),
            1,
            bytes("")
        );
        addRemoteMediator(chainId, addr.toBytes32());
        bool isAllowed = glacisTokenMediator.isAllowedRoute(
            GlacisRoute(
                chainId,
                addr.toBytes32(), // correct mediator address
                address(0x123456789)
            ), // Custom Adapter
            payload
        );
        assertFalse(isAllowed);
    }
}
