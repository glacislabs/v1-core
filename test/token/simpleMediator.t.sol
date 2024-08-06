// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroV2Mock, SimpleTokenMediator, XERC20Sample, GlacisCommons} from "../LocalTestSetup.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";
import {GlacisRouter__ClientDeniedRoute} from "../../contracts/routers/GlacisRouter.sol";

contract TokenMediatorTests is LocalTestSetup {
    using AddressBytes32 for address;

    GlacisRouter internal glacisRouter;

    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;

    SimpleTokenMediator internal simpleTokenMediator;
    XERC20Sample internal xERC20Sample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (, xERC20Sample, , , , , ) = deployGlacisTokenFixture(glacisRouter);
        (axelarGatewayMock, axelarGasServiceMock) = deployAxelarFixture();
        axelarAdapter = deployAxelarAdapters(
            glacisRouter,
            axelarGatewayMock,
            axelarGasServiceMock
        );
        LayerZeroV2Mock lzEndpoint = deployLayerZeroFixture();
        deployLayerZeroAdapters(glacisRouter, lzEndpoint);

        setUpSimpleTokenMediator(1);
    }

    function setUpSimpleTokenMediator(uint256 quorum) internal {
        simpleTokenMediator = new SimpleTokenMediator(
            address(glacisRouter),
            quorum,
            address(this)
        );
        simpleTokenMediator.setXERC20(address(xERC20Sample));
        simpleTokenMediator.addAllowedRoute(
            GlacisCommons.GlacisRoute(
                block.chainid, // fromChainId
                address(simpleTokenMediator).toBytes32(), // from
                address(WILDCARD) // from adapters
            )
        );
        addRemoteMediator(
            block.chainid,
            address(simpleTokenMediator).toBytes32()
        );
        xERC20Sample.setLimits(address(simpleTokenMediator), 10e18, 10e18);
    }

    function addRemoteMediator(uint256 chainId, bytes32 addr) internal {
        uint256[] memory chainIdArr = new uint256[](1);
        chainIdArr[0] = chainId;
        bytes32[] memory addrArr = new bytes32[](1);
        addrArr[0] = addr;
        simpleTokenMediator.addRemoteCounterparts(chainIdArr, addrArr);
    }

    function test__SimpleTokenMediator_AddsRemoteAddress(
        bytes32 addr,
        uint256 chainId
    ) external {
        vm.assume(chainId != 0);
        addRemoteMediator(chainId, addr);
        assertEq(simpleTokenMediator.getRemoteCounterpart(chainId), addr);
    }

    function test__SimpleTokenMediator_RemovesRemoteAddress(
        address addr,
        uint256 chainId
    ) external {
        vm.assume(chainId != 0);
        addRemoteMediator(chainId, addr.toBytes32());
        simpleTokenMediator.removeRemoteCounterpart(chainId);
        assertEq(simpleTokenMediator.getRemoteCounterpart(chainId), bytes32(0));
    }

    function test__SimpleTokenMediator_NonOwnersCannotAddRemote() external {
        vm.startPrank(address(0x123));
        vm.expectRevert("Ownable: caller is not the owner");
        addRemoteMediator(block.chainid, address(0x123).toBytes32());
    }

    function test__SimpleTokenMediator_NonOwnersCannotRemoveRemote() external {
        vm.startPrank(address(0x123));
        vm.expectRevert("Ownable: caller is not the owner");
        simpleTokenMediator.removeRemoteCounterpart(block.chainid);
    }

    function test__SimpleTokenMediator_SetsXERC20(address xerc20) external {
        simpleTokenMediator.setXERC20(xerc20);
        assertEq(xerc20, simpleTokenMediator.xERC20Token());
    }

    function test__SimpleTokenMediator_NonOwnersCannotSetXERC20() external {
        vm.startPrank(address(0x123));
        vm.expectRevert("Ownable: caller is not the owner");
        simpleTokenMediator.setXERC20(address(0));
    }

    function test__SimpleTokenMediator_AcceptsExecuteFromMediatorSource(
        address addr,
        uint256 chainId
    ) external {
        vm.assume(chainId != 0);

        addRemoteMediator(chainId, addr.toBytes32());

        // Message is being received by the router
        vm.startPrank(address(glacisRouter));

        address[] memory gmpArray = new address[](1);
        gmpArray[0] = AXELAR_GMP_ID;

        simpleTokenMediator.receiveMessage(
            gmpArray,
            chainId,
            addr.toBytes32(),
            abi.encode(address(0x123).toBytes32(), 1)
        );
        assertEq(xERC20Sample.balanceOf(address(0x123)), 1);
    }

    function test__SimpleTokenMediator_SendsCrossChain(
        address targetAddr,
        uint256 amount
    ) external {
        vm.assume(amount < xERC20Sample.balanceOf(address(this)));
        vm.assume(targetAddr != address(0));
        vm.assume(targetAddr != address(this));

        address[] memory adapters = new address[](1);
        adapters[0] = AXELAR_GMP_ID;
        CrossChainGas[] memory fees = createFees(1 ether, 1);

        xERC20Sample.approve(address(simpleTokenMediator), amount);
        simpleTokenMediator.sendCrossChain{value: 1 ether}(
            block.chainid,
            targetAddr.toBytes32(),
            adapters,
            fees,
            address(this),
            amount
        );

        assertEq(xERC20Sample.balanceOf(targetAddr), amount);
    }

    function test__SimpleTokenMediator_SendsCrossChainAccessDenied() external {
        address targetAddr = address(0x123);
        uint256 amount = 1000;

        // Allowed routes removed
        simpleTokenMediator.removeAllowedRoute(
            GlacisCommons.GlacisRoute(
                block.chainid, // fromChainId
                address(simpleTokenMediator).toBytes32(), // from
                address(WILDCARD) // from adapters
            )
        );

        address[] memory adapters = new address[](1);
        adapters[0] = AXELAR_GMP_ID;
        CrossChainGas[] memory fees = createFees(1 ether, 1);

        xERC20Sample.approve(address(simpleTokenMediator), amount);

        vm.expectRevert(GlacisRouter__ClientDeniedRoute.selector);
        simpleTokenMediator.sendCrossChain{value: 1 ether}(
            block.chainid,
            targetAddr.toBytes32(),
            adapters,
            fees,
            address(this),
            amount
        );
    }

    function test__SimpleTokenMediator_SendsCrossChainRedundantQuorum(
        address targetAddr,
        uint256 amount
    ) external {
        vm.assume(amount < xERC20Sample.balanceOf(address(this)));
        vm.assume(targetAddr != address(0));
        vm.assume(targetAddr != address(this));

        setUpSimpleTokenMediator(2);

        address[] memory adapters = new address[](2);
        adapters[0] = AXELAR_GMP_ID;
        adapters[1] = LAYERZERO_GMP_ID;
        CrossChainGas[] memory fees = createFees(0.5 ether, 2);

        xERC20Sample.approve(address(simpleTokenMediator), amount);
        simpleTokenMediator.sendCrossChain{value: 1 ether}(
            block.chainid,
            targetAddr.toBytes32(),
            adapters,
            fees,
            address(this),
            amount
        );

        assertEq(xERC20Sample.balanceOf(targetAddr), amount);
    }

    function test__SimpleTokenMediator_SendsCrossChainQuorumLimits(
        address targetAddr,
        uint256 amount
    ) external {
        vm.assume(amount < xERC20Sample.balanceOf(address(this)));
        vm.assume(targetAddr != address(0));
        vm.assume(targetAddr != address(this));

        setUpSimpleTokenMediator(2);

        address[] memory adapters = new address[](1);
        adapters[0] = AXELAR_GMP_ID;
        CrossChainGas[] memory fees = createFees(1 ether, 1);

        xERC20Sample.approve(address(simpleTokenMediator), amount);
        simpleTokenMediator.sendCrossChain{value: 1 ether}(
            block.chainid,
            targetAddr.toBytes32(),
            adapters,
            fees,
            address(this),
            amount
        );

        assertEq(xERC20Sample.balanceOf(targetAddr), 0);
    }

    function test__SimpleTokenMediator_SendsCrossChainRetry(
        address targetAddr,
        uint256 amount
    ) external {
        vm.assume(amount < xERC20Sample.balanceOf(address(this)));
        vm.assume(targetAddr != address(0));
        vm.assume(targetAddr != address(this));

        setUpSimpleTokenMediator(2);

        address[] memory adapters = new address[](1);
        adapters[0] = AXELAR_GMP_ID;
        CrossChainGas[] memory fees = createFees(1 ether, 1);

        xERC20Sample.approve(address(simpleTokenMediator), amount);
        (bytes32 messageId, uint256 nonce) = simpleTokenMediator.sendCrossChain{value: 1 ether}(
            block.chainid,
            targetAddr.toBytes32(),
            adapters,
            fees,
            address(this),
            amount
        );

        assertEq(xERC20Sample.balanceOf(targetAddr), 0);

        adapters[0] = LAYERZERO_GMP_ID;
        simpleTokenMediator.sendCrossChainRetry{value: 1 ether}(
            block.chainid,
            targetAddr.toBytes32(),
            adapters,
            fees,
            address(this),
            messageId,
            nonce,
            amount
        );

        assertEq(xERC20Sample.balanceOf(targetAddr), amount);
    }

    receive() external payable {}
}
