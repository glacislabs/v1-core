// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisRouter, GlacisCommons} from "../LocalTestSetup.sol";
import {GlacisAbstractRouter__InvalidAdapterAddress, GlacisAbstractRouter__GMPIDCannotBeZero, GlacisAbstractRouter__GMPIDTooHigh} from "../../contracts/routers/GlacisAbstractRouter.sol";
import "forge-std/console.sol";

contract RouterTests is LocalTestSetup {
    GlacisRouter internal glacisRouter;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
    }

    function test__GlacisRouter_RegistersAdapter(address adapter, uint8 gmpID) external {
        vm.assume(adapter != address(0));
        vm.assume(gmpID <= GLACIS_RESERVED_IDS);
        vm.assume(gmpID > 0);

        glacisRouter.registerAdapter(gmpID, adapter);

        assertEq(glacisRouter.glacisGMPIdToAdapter(gmpID), adapter);
        assertEq(glacisRouter.adapterToGlacisGMPId(adapter), gmpID);
    }

    function test__GlacisRouter_ReplacesAdapter(address adapter, address replacingAdapter, uint8 gmpID) external {
        vm.assume(adapter != address(0));
        vm.assume(replacingAdapter != address(0));
        vm.assume(gmpID <= GLACIS_RESERVED_IDS);
        vm.assume(gmpID > 0);
        
        glacisRouter.registerAdapter(gmpID, adapter);

        assertEq(glacisRouter.glacisGMPIdToAdapter(gmpID), adapter);
        assertEq(glacisRouter.adapterToGlacisGMPId(adapter), gmpID);

        glacisRouter.registerAdapter(gmpID, replacingAdapter);

        assertEq(glacisRouter.glacisGMPIdToAdapter(gmpID), replacingAdapter);
        assertEq(glacisRouter.adapterToGlacisGMPId(replacingAdapter), gmpID);
    }

    function test__GlacisRouter_DeletesAdapter(address adapter, uint8 gmpID) external {
        vm.assume(adapter != address(0));
        vm.assume(gmpID <= GLACIS_RESERVED_IDS);
        vm.assume(gmpID > 0);
        
        glacisRouter.registerAdapter(gmpID, adapter);
        glacisRouter.unRegisterAdapter(gmpID);

        assertEq(glacisRouter.glacisGMPIdToAdapter(gmpID), address(0));
        assertEq(glacisRouter.adapterToGlacisGMPId(adapter), 0);
    }

    function test__GlacisRouter_DoesNotAllowBadAdapters() external {
        vm.expectRevert(GlacisAbstractRouter__InvalidAdapterAddress.selector);
        glacisRouter.registerAdapter(1, address(0));
    }

    function test__GlacisRouter_AddAdapterDoesNotAllowBadIDs() external {
        vm.expectRevert(GlacisAbstractRouter__GMPIDCannotBeZero.selector);
        glacisRouter.registerAdapter(0, address(0x123));

        vm.expectRevert(GlacisAbstractRouter__GMPIDTooHigh.selector);
        glacisRouter.registerAdapter(uint8(GLACIS_RESERVED_IDS) + 1, address(0x123));
    }

    function test__GlacisRouter_NonOwnersCannotAddOrDeleteAdapters() external {
        vm.prank(address(0x123));
        vm.expectRevert("Ownable: caller is not the owner");
        glacisRouter.registerAdapter(1, address(0x123));
    }

    receive() external payable {}
}
