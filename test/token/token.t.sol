// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroV2Mock} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../contracts/samples/GlacisClientSample.sol";
import {GlacisTokenClientSampleSource} from "../contracts/samples/GlacisTokenClientSampleSource.sol";
import {GlacisTokenClientSampleDestination} from "../contracts/samples/GlacisTokenClientSampleDestination.sol";
import {GlacisRouter__ClientDeniedRoute} from "../../contracts/routers/GlacisRouter.sol";
import {GlacisCommons} from "../../contracts/commons/GlacisCommons.sol";
import {AddressBytes32} from "../../contracts/libraries/AddressBytes32.sol";
import {GlacisTokenMediator__IncorrectTokenVariant} from "../../contracts/mediators/GlacisTokenMediator.sol";
import {GlacisTokenMediator, GlacisTokenClientSampleSource, GlacisTokenClientSampleDestination, XERC20Sample, ERC20Sample, XERC20LockboxSample, XERC20NativeLockboxSample} from "../LocalTestSetup.sol";
import {console} from "forge-std/console.sol";
import {IXERC20} from "../../contracts/interfaces/IXERC20.sol";

/* solhint-disable contract-name-camelcase */
contract TokenTests__Axelar is LocalTestSetup {
    using AddressBytes32 for address;

    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;
    GlacisRouter internal glacisRouter;
    GlacisTokenMediator internal glacisTokenMediator;
    XERC20Sample internal xERC20Sample;
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
        LayerZeroV2Mock lzEndpoint = deployLayerZeroFixture();
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
            address(glacisTokenClientSampleDestination).toBytes32(),
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

    event ValueChanged(uint256 indexed value);

    function test__Token_SendMessageAndTokens_Axelar(uint256 amount) external {
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
            address(glacisTokenClientSampleDestination).toBytes32(),
            AXELAR_GMP_ID,
            abi.encode(amount), // no message only tokens
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
            preDestinationValue + amount
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
            address(glacisTokenClientSampleDestination).toBytes32(),
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
            randomAccount.toBytes32(),
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
            address(glacisTokenClientSampleDestination).toBytes32(),
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
        address[] memory gmps = new address[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;
        glacisTokenClientSampleSource.sendMessageAndTokens__redundant{
            value: 0.5 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
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
                address(glacisTokenClientSampleSource).toBytes32(), // from
                address(WILDCARD) // fromGmpId
            )
        );

        xERC20Sample.transfer(address(glacisTokenClientSampleSource), 100);

        // Send a single message with 5 that we expect to finish executing
        glacisTokenClientSampleSource.sendMessageAndTokens__abstract{
            value: 0.1 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
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
            address(glacisTokenClientSampleDestination).toBytes32(),
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
        address[] memory gmps = new address[](2);
        gmps[0] = AXELAR_GMP_ID;
        gmps[1] = LAYERZERO_GMP_ID;
        glacisTokenClientSampleSource.sendMessageAndTokens__redundant{
            value: 0.5 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
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

    function test__Token_XERC20_LimitsBurn(
        uint256 maxMintLimit,
        uint256 maxBurnLimit,
        uint256 excess
    ) external {
        vm.assume(maxBurnLimit > 0 && maxBurnLimit < 10e9);
        vm.assume(maxMintLimit > 0 && maxMintLimit < 10e9);
        vm.assume(excess > 0 && excess < 10e3);
        uint256 amount = maxBurnLimit + excess;
        address glacisRouter_ = glacisTokenClientSampleSource
            .GLACIS_TOKEN_ROUTER();

        // Set xERC20 limits to glacis router
        xERC20Sample.setLimits(glacisRouter_, maxMintLimit, maxBurnLimit);
        assertEq(xERC20Sample.mintingMaxLimitOf(glacisRouter_), maxMintLimit);
        assertEq(xERC20Sample.burningMaxLimitOf(glacisRouter_), maxBurnLimit);
        assertEq(
            xERC20Sample.mintingCurrentLimitOf(glacisRouter_),
            maxMintLimit
        );
        assertEq(
            xERC20Sample.burningCurrentLimitOf(glacisRouter_),
            maxBurnLimit
        );

        xERC20Sample.transfer(address(glacisTokenClientSampleSource), amount);

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);

        // Send more tokens that max burn limit
        glacisTokenClientSampleSource.sendMessageAndTokens__abstract{
            value: 0.1 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            AXELAR_GMP_ID,
            abi.encode(1),
            address(xERC20Sample),
            amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            0
        );
    }

    function test__Token_XERC20_LimitsMint(
        uint256 maxMintLimit,
        uint256 maxBurnLimit,
        uint256 excess
    ) external {
        vm.assume(maxMintLimit > 0 && maxMintLimit < 10e9);
        vm.assume(excess > 0 && excess < 10e3);
        // Set burn limit higher than mint limit
        maxBurnLimit = maxMintLimit + excess;
        uint256 amount = maxBurnLimit;
        address glacisRouter_ = glacisTokenClientSampleSource
            .GLACIS_TOKEN_ROUTER();

        // Set xERC20 limits to glacis router
        xERC20Sample.setLimits(glacisRouter_, maxMintLimit, maxBurnLimit);
        assertEq(xERC20Sample.mintingMaxLimitOf(glacisRouter_), maxMintLimit);
        assertEq(xERC20Sample.burningMaxLimitOf(glacisRouter_), maxBurnLimit);
        assertEq(
            xERC20Sample.mintingCurrentLimitOf(glacisRouter_),
            maxMintLimit
        );
        assertEq(
            xERC20Sample.burningCurrentLimitOf(glacisRouter_),
            maxBurnLimit
        );

        xERC20Sample.transfer(address(glacisTokenClientSampleSource), amount);

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);

        // Send more tokens that max mint limit
        glacisTokenClientSampleSource.sendMessageAndTokens__abstract{
            value: 0.1 ether
        }(
            block.chainid,
            address(glacisTokenClientSampleDestination).toBytes32(),
            AXELAR_GMP_ID,
            abi.encode(1),
            address(xERC20Sample),
            amount
        );
        assertEq(
            xERC20Sample.balanceOf(address(glacisTokenClientSampleDestination)),
            0
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

    function test__Token_XERC20LockBox_LimitsDeposit(
        uint256 maxBurnLimit,
        uint256 maxMintLimit,
        uint256 excess
    ) external {
        vm.assume(maxBurnLimit > 0 && maxBurnLimit < 10e17);
        vm.assume(maxMintLimit > 0 && maxMintLimit < 10e17);
        vm.assume(excess > 0 && excess < 10e3);

        // Lockbox should no apply caller mint limits
        uint256 amount = maxMintLimit + excess;
        erc20Sample.approve(address(xERC20LockboxSample), amount);
        address glacisRouter_ = glacisTokenClientSampleSource
            .GLACIS_TOKEN_ROUTER();
        xERC20Sample.setLimits(glacisRouter_, maxMintLimit, maxBurnLimit);
        xERC20Sample.setLockbox(address(xERC20LockboxSample));
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
            address(glacisTokenClientSampleDestination).toBytes32(),
            AXELAR_GMP_ID,
            abi.encode(remoteIncrementValue),
            address(xERC20Sample),
            amount
        );
    }

    function test__Token_TokenVariantsAccepted(
        bytes32 otherToken,
        uint256 otherChainId
    ) external {
        vm.assume(otherToken != bytes32(0));
        vm.assume(otherChainId != 0);

        // Sets the token as variant
        xERC20Sample.setTokenVariant(otherChainId, otherToken);

        // Sets fake glacisTokenMediator remote counterpart
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = otherChainId;
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(glacisTokenMediator).toBytes32();
        glacisTokenMediator.addRemoteCounterparts(
            glacisIDs,
            adapterCounterparts
        );

        // Prank a receiveMessage from a random chainID
        address[] memory gmps = new address[](1);
        gmps[0] = AXELAR_GMP_ID;
        vm.startPrank(address(glacisRouter));
        glacisTokenMediator.receiveMessage(
            gmps,
            otherChainId,
            address(glacisTokenMediator).toBytes32(),
            abi.encode(
                address(0x123).toBytes32(), // to = EOA
                address(0x456).toBytes32(), // from
                otherToken, // sourceToken
                address(xERC20Sample).toBytes32(), // token
                1 ether, // tokenAmount
                "" // originalPayload
            )
        );

        assertEq(xERC20Sample.balanceOf(address(0x123)), 1 ether);
    }

    function test__Token_BadTokenVariantDenied(
        bytes32 otherToken,
        uint256 otherChainId
    ) external {
        vm.assume(
            otherToken != bytes32(0) &&
                otherToken != address(xERC20Sample).toBytes32()
        );
        vm.assume(otherChainId != 0);

        // NOTE: Does not sets the token as variant

        // Sets fake glacisTokenMediator remote counterpart
        uint256[] memory glacisIDs = new uint256[](1);
        glacisIDs[0] = otherChainId;
        bytes32[] memory adapterCounterparts = new bytes32[](1);
        adapterCounterparts[0] = address(glacisTokenMediator).toBytes32();
        glacisTokenMediator.addRemoteCounterparts(
            glacisIDs,
            adapterCounterparts
        );

        // Prank a receiveMessage from a random chainID
        address[] memory gmps = new address[](1);
        gmps[0] = AXELAR_GMP_ID;
        vm.startPrank(address(glacisRouter));
        vm.expectRevert(
            abi.encodeWithSelector(
                GlacisTokenMediator__IncorrectTokenVariant.selector,
                otherToken,
                otherChainId
            )
        );
        glacisTokenMediator.receiveMessage(
            gmps,
            otherChainId,
            address(glacisTokenMediator).toBytes32(),
            abi.encode(
                address(0x123).toBytes32(), // to = EOA
                address(0x456).toBytes32(), // from
                otherToken, // sourceToken
                address(xERC20Sample).toBytes32(), // token
                1 ether, // tokenAmount
                "" // originalPayload
            )
        );
    }

    function test__Token_TokenVariantRemove(uint256 chainId) external {
        vm.assume(chainId != 0);
        // Sets the token as variant
        xERC20Sample.removeTokenVariant(chainId);
        assertEq(xERC20Sample.getTokenVariant(chainId), bytes32(0));
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
        uint256, // uniqueMessagesReceived
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
