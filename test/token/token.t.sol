// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroGMPMock} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {GlacisTokenClientSampleSource} from "../contracts/samples/GlacisTokenClientSampleSource.sol";
import {GlacisTokenClientSampleDestination} from "../contracts/samples/GlacisTokenClientSampleDestination.sol";
import {GlacisRouter__ClientDeniedRoute} from "../../contracts/routers/GlacisRouter.sol";
import {GlacisCommons} from "../../contracts/commons/GlacisCommons.sol";

import {GlacisTokenMediator, GlacisTokenClientSampleSource, GlacisTokenClientSampleDestination, GXTSample, ERC20Sample, XERC20LockboxSample, XERC20NativeLockboxSample} from "../LocalTestSetup.sol";

/* solhint-disable contract-name-camelcase */
contract TokenTests__Axelar is LocalTestSetup {
    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;
    GlacisTokenMediator internal glacisTokenMediator;
    GXTSample internal xERC20Sample;
    ERC20Sample internal erc20Sample;
    XERC20LockboxSample internal xERC20LockboxSample;
    XERC20NativeLockboxSample internal xERC20NativeLockboxSample;
    GlacisTokenClientSampleSource internal glacisTokenClientSampleSource;
    GlacisTokenClientSampleDestination
        internal glacisTokenClientSampleDestination;

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
        LayerZeroGMPMock lzEndpoint = deployLayerZeroFixture();
        deployLayerZeroAdapters(glacisRouter, lzEndpoint);
    }

    function test__Token_SendXERC20_Axelar(uint256 amount) external {
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
        glacisTokenClientSampleSource.sendMessageAndTokens__abstract{
            value: 0.1 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination),
            AXELAR_GMP_ID,
            "", // no message only tokens
            address(xERC20Sample),
            amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preSourceBalance - amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            preDestinationBalance + amount
        );
        assertEq(
            glacisTokenClientSampleDestination.value(),
            preDestinationValue
        );
    }

    function test__Token_SendXERC20AndMessage_Axelar(
        uint256 amount,
        uint256 remoteIncrementValue
    ) external {
        vm.assume(amount < 10e15);
        xERC20Sample.transfer(address(glacisTokenClientSampleSource), amount);
        uint256 preSourceBalance = xERC20Sample.balanceOf(
            address(glacisTokenClientSampleSource)
        );
        uint256 preDestinationBalance = xERC20Sample.balanceOf(
            address(glacisTokenClientSampleDestination)
        );
        glacisTokenClientSampleSource.sendMessageAndTokens__abstract{
            value: 0.1 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination),
            AXELAR_GMP_ID,
            abi.encode(remoteIncrementValue),
            address(xERC20Sample),
            amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preSourceBalance - amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            preDestinationBalance + amount
        );
        assertEq(
            glacisTokenClientSampleDestination.value(),
            remoteIncrementValue
        );
    }

    function test__Token_SendXERC20ToEOA_Axelar(uint256 amount) external {
        address randomAccount = 0xA8f2985759e66b3E04cC47CdBD0bfE46fAf48792;
        assertEq(randomAccount.code.length, 0);

        vm.assume(amount < 10e15);
        xERC20Sample.transfer(address(glacisTokenClientSampleSource), amount);
        uint256 preSourceBalance = xERC20Sample.balanceOf(
            address(glacisTokenClientSampleSource)
        );
        uint256 preDestinationBalance = xERC20Sample.balanceOf(randomAccount);
        glacisTokenClientSampleSource.sendMessageAndTokens__abstract{
            value: 0.1 ether
        }(
            block.chainid,
            randomAccount,
            AXELAR_GMP_ID,
            abi.encode(0),
            address(xERC20Sample),
            amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preSourceBalance - amount
        );
        assertEq(
            xERC20Sample.balanceOf(randomAccount),
            preDestinationBalance + amount
        );
    }

    function test__Token_Quorum2DoesNotExecute() external {
        glacisTokenClientSampleDestination.setQuorum(2);
        xERC20Sample.transfer(address(glacisTokenClientSampleSource), 5);

        // Send a single message that we expect not to finish executing
        glacisTokenClientSampleSource.sendMessageAndTokens__abstract{
            value: 0.1 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination),
            AXELAR_GMP_ID,
            abi.encode(1),
            address(xERC20Sample),
            5
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            0
        );
    }

    function test__Token_Quorum2Executes() external {
        glacisTokenClientSampleDestination.setQuorum(2);
        xERC20Sample.transfer(address(glacisTokenClientSampleSource), 5);

        // Send a redundant message that we expect to finish executing
        uint8[] memory gmps = new uint8[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;
        glacisTokenClientSampleSource.sendMessageAndTokens__redundant{
            value: 0.5 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination),
            gmps,
            createFees(0.5 ether / 2, 2),
            abi.encode(1),
            address(xERC20Sample),
            5
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            5
        );
    }

    function test__Token_DynamicQuorum() external {
        glacisTokenClientSampleDestination = new GlacisTokenClientSampleDestinationQuorumHarness(
            address(xERC20Sample),
            address(erc20Sample),
            address(xERC20LockboxSample),
            address(glacisTokenMediator),
            address(glacisRouter),
            address(this)
        );
        glacisTokenClientSampleDestination.addAllowedRoute(
            GlacisCommons.GlacisRoute(
                block.chainid, // fromChainId
                address(glacisTokenClientSampleSource), // from
                0 // fromGmpId
            )
        );

        xERC20Sample.transfer(address(glacisTokenClientSampleSource), 100);

        // Send a single message with 5 that we expect to finish executing
        glacisTokenClientSampleSource.sendMessageAndTokens__abstract{
            value: 0.1 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination),
            AXELAR_GMP_ID,
            abi.encode(1),
            address(xERC20Sample),
            5
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            5
        );

        // Send a single message with 20 that we expect NOT to finish executing
        glacisTokenClientSampleSource.sendMessageAndTokens__abstract{
            value: 0.1 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination),
            AXELAR_GMP_ID,
            abi.encode(1),
            address(xERC20Sample),
            20
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            5
        );

        // Send a redundant message that we expect to finish executing
        uint8[] memory gmps = new uint8[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;
        glacisTokenClientSampleSource.sendMessageAndTokens__redundant{
            value: 0.5 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination),
            gmps,
            createFees(0.5 ether / 2, 2),
            abi.encode(1),
            address(xERC20Sample),
            15
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            20
        );
    }

    function test__Token_XERC20LockBox_Deposit(uint256 amount) external {
        vm.assume(amount < 10e17);
        erc20Sample.approve(address(xERC20LockboxSample), amount);
        uint256 preERC20SourceBalance = erc20Sample.balanceOf(address(this));
        uint256 preXERC20SourceBalance = xERC20Sample.balanceOf(address(this));
        xERC20LockboxSample.deposit(amount);
        assertEq(
            erc20Sample.balanceOf(address(this)),
            preERC20SourceBalance - amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(this)),
            preXERC20SourceBalance + amount
        );
    }

    function test__Token_XERC20LockBox_DepositNative(uint256 amount) external {
        vm.assume(amount < 10e17);
        erc20Sample.approve(address(xERC20NativeLockboxSample), amount);
        uint256 preNativeSourceSignerBalance = address(this).balance;
        uint256 preNativeSourceLockboxBalance = address(
            xERC20NativeLockboxSample
        ).balance;
        uint256 preXERC20SourceBalance = xERC20Sample.balanceOf(address(this));
        xERC20NativeLockboxSample.depositNative{value: amount}();
        assertEq(address(this).balance, preNativeSourceSignerBalance - amount);
        assertEq(
            address(xERC20NativeLockboxSample).balance,
            preNativeSourceLockboxBalance + amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(this)),
            preXERC20SourceBalance + amount
        );
    }

    function test__Token_XERC20LockBox_DepositNativeTo(
        uint256 amount
    ) external {
        vm.assume(amount < 10e17);
        erc20Sample.approve(address(xERC20NativeLockboxSample), amount);
        uint256 preNativeSourceSignerBalance = address(this).balance;
        uint256 preNativeSourceLockboxBalance = address(
            xERC20NativeLockboxSample
        ).balance;
        uint256 preXERC20SourceReceiverBalance = xERC20Sample.balanceOf(
            address(glacisTokenClientSampleSource)
        );
        xERC20NativeLockboxSample.depositNativeTo{value: amount}(
            address(glacisTokenClientSampleSource)
        );
        assertEq(address(this).balance, preNativeSourceSignerBalance - amount);
        assertEq(
            address(xERC20NativeLockboxSample).balance,
            preNativeSourceLockboxBalance + amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preXERC20SourceReceiverBalance + amount
        );
    }

    function test__Token_XERC20LockBox_DepositTo(uint256 amount) external {
        vm.assume(amount < 10e17);
        erc20Sample.approve(address(xERC20LockboxSample), amount);
        uint256 preERC20SourceSignerBalance = erc20Sample.balanceOf(
            address(this)
        );
        uint256 preXERC20SourceReceiverBalance = erc20Sample.balanceOf(
            address(glacisTokenClientSampleSource)
        );
        uint256 preXERC20SourceLockboxBalance = xERC20Sample.balanceOf(
            address(glacisTokenClientSampleSource)
        );
        xERC20LockboxSample.depositTo(
            address(glacisTokenClientSampleSource),
            amount
        );
        assertEq(
            erc20Sample.balanceOf(address(this)),
            preERC20SourceSignerBalance - amount
        );
        assertEq(
            erc20Sample.balanceOf(address(xERC20LockboxSample)),
            preXERC20SourceLockboxBalance + amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preXERC20SourceReceiverBalance + amount
        );
    }

    function test__Token_XERC20LockBox_Withdraw(uint256 amount) external {
        vm.assume(amount < 10e17);
        erc20Sample.approve(address(xERC20LockboxSample), amount);
        xERC20LockboxSample.deposit(amount);
        uint256 preERC20SourceLockboxBalance = erc20Sample.balanceOf(
            address(xERC20LockboxSample)
        );
        uint256 preERC20SourceSignerBalance = erc20Sample.balanceOf(
            address(this)
        );
        uint256 preXERC20SourceBalance = xERC20Sample.balanceOf(address(this));
        xERC20Sample.approve(address(xERC20LockboxSample), amount);
        xERC20LockboxSample.withdraw(amount);
        assertEq(
            erc20Sample.balanceOf(address(xERC20LockboxSample)),
            preERC20SourceLockboxBalance - amount
        );
        assertEq(
            erc20Sample.balanceOf(address(this)),
            preERC20SourceSignerBalance + amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(this)),
            preXERC20SourceBalance - amount
        );
    }

    function test__Token_XERC20LockBox_WithdrawTo(uint256 amount) external {
        vm.assume(amount < 10e17);
        erc20Sample.approve(address(xERC20LockboxSample), amount);
        xERC20LockboxSample.deposit(amount);
        xERC20Sample.approve(address(xERC20LockboxSample), amount);
        uint256 preERC20SourceLockboxBalance = erc20Sample.balanceOf(
            address(xERC20LockboxSample)
        );
        uint256 preERC20SourceREceiverBalance = erc20Sample.balanceOf(
            address(glacisTokenClientSampleSource)
        );
        uint256 preXERC20SourceSignerBalance = xERC20Sample.balanceOf(
            address(this)
        );
        xERC20LockboxSample.withdrawTo(
            address(glacisTokenClientSampleSource),
            amount
        );
        assertEq(
            erc20Sample.balanceOf(address(xERC20LockboxSample)),
            preERC20SourceLockboxBalance - amount
        );
        assertEq(
            erc20Sample.balanceOf(address(glacisTokenClientSampleSource)),
            preERC20SourceREceiverBalance + amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(this)),
            preXERC20SourceSignerBalance - amount
        );
    }

    function test__Token_IsAllowedRouteDeniesExecution(
        uint256 amount,
        uint256 remoteIncrementValue
    ) external {
        // Recreate glacisTokenClientSampleSource with new address, so
        // glacisTokenClientSampleDestination never adds it as an accepted route.
        glacisTokenClientSampleSource = new GlacisTokenClientSampleSource(
            address(xERC20Sample),
            address(erc20Sample),
            address(xERC20LockboxSample),
            address(glacisTokenMediator),
            address(glacisRouter),
            address(this)
        );
        vm.assume(amount < 10e15);
        xERC20Sample.transfer(address(glacisTokenClientSampleSource), amount);

        vm.expectRevert(GlacisRouter__ClientDeniedRoute.selector);
        glacisTokenClientSampleSource.sendMessageAndTokens__abstract{
            value: 0.1 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination),
            AXELAR_GMP_ID,
            abi.encode(remoteIncrementValue),
            address(xERC20Sample),
            amount
        );
    }

    receive() external payable {}
}

contract GlacisTokenClientSampleDestinationQuorumHarness is
    GlacisTokenClientSampleDestination
{
    constructor(
        address xERC20Sample_,
        address erc20Sample_,
        address xERC20LockboxSample_,
        address glacisTokenMediator_,
        address glacisRouter_,
        address owner_
    )
        GlacisTokenClientSampleDestination(
            xERC20Sample_,
            erc20Sample_,
            xERC20LockboxSample_,
            glacisTokenMediator_,
            glacisRouter_,
            owner_
        )
    {}

    function getQuorum(
        GlacisCommons.GlacisData memory, // glacisData,
        bytes memory, // payload,
        address, // token,
        uint256 tokenAmount
    ) external view virtual override returns (uint256) {
        if (tokenAmount < 10) {
            return 1;
        } else {
            return 2;
        }
    }
}
