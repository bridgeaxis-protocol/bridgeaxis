// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AIUSDController} from "../../contracts/aiusd/AIUSDController.sol";
import {AIUSDTestBase} from "./utils/AIUSDTestBase.t.sol";

contract AIUSDControllerUnitTest is AIUSDTestBase {
    function test_RouteCapitalBurnsReserveAndCreditsAIUSD() public {
        _mintReserve(alice, 7e18);

        vm.prank(alice);
        controller.routeCapital(7e18);

        assertEq(aiusd.balanceOf(alice), 7e18);
        assertEq(busdc.balanceOf(alice), 0);
        assertEq(busdc.balanceOf(address(controller)), 0);
    }

    function test_RouteCapitalRevertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(AIUSDController.ZeroAmount.selector);
        controller.routeCapital(0);
    }

    function test_RouteCapitalWithReasonRejectsZeroReason() public {
        _mintReserve(alice, 1e18);

        vm.prank(alice);
        vm.expectRevert(AIUSDController.ZeroReasonId.selector);
        controller.routeCapitalWithReason(1e18, bytes32(0));
    }

    function test_AllocateStrategyBalanceRequiresOwnerOrOperator() public {
        vm.prank(alice);
        vm.expectRevert();
        controller.allocateStrategyBalance(alice, 1e18);
    }

    function test_AllocateStrategyBalanceCreditsBeneficiary() public {
        _allocateManaged(owner, bob, 4e18);

        assertEq(aiusd.balanceOf(bob), 4e18);
        assertEq(busdc.balanceOf(owner), 0);
    }

    function test_AllocateStrategyBalanceFromReserveConsumesSeparateReserveAccount() public {
        bytes32 reasonId = keccak256("BRIDGEAXIS_TREASURY_BACKUP");
        _mintReserve(owner, 10_000_000e18);

        vm.prank(operator);
        controller.allocateStrategyBalanceFromReserve(owner, bob, 10_000_000e18, reasonId);

        assertEq(busdc.balanceOf(owner), 0);
        assertEq(aiusd.balanceOf(bob), 10_000_000e18);
    }

    function test_AllocateStrategyBalanceForEpochRevertsOnZeroBeneficiary() public {
        vm.prank(owner);
        vm.expectRevert(AIUSDController.ZeroAddressAccount.selector);
        controller.allocateStrategyBalanceForEpoch(address(0), 1e18, 1 days);
    }

    function test_AllocateStrategyBalanceForEpochRevertsOnZeroEpoch() public {
        vm.prank(owner);
        vm.expectRevert(AIUSDController.ZeroExecutionEpoch.selector);
        controller.allocateStrategyBalanceForEpoch(alice, 1e18, 0);
    }

    function test_AllocateStrategyBalanceForEpochRevertsOnExcessiveEpoch() public {
        vm.prank(owner);
        vm.expectRevert();
        controller.allocateStrategyBalanceForEpoch(alice, 1e18, type(uint64).max);
    }

    function test_AllocateStrategyBalanceForEpochStoresReleaseTime() public {
        uint64 releaseTime = _allocateManagedForEpoch(owner, alice, 2e18, 3 days);

        assertEq(aiusd.balanceOf(alice), 2e18);
        assertEq(controller.managedBalanceOf(alice), 2e18);
        assertEq(controller.executionWindowEndsAt(alice), releaseTime);
    }

    function test_SettleStrategyBalanceRevertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(AIUSDController.ZeroAmount.selector);
        controller.settleStrategyBalance(0);
    }

    function test_SettleStrategyBalanceBurnsTradableOnly() public {
        _routeCapital(alice, 10e18);
        _allocateManagedForEpoch(owner, alice, 2e18, 5 days);

        vm.prank(alice);
        controller.settleStrategyBalance(10e18);

        assertEq(aiusd.balanceOf(alice), 2e18);
        assertEq(controller.managedBalanceOf(alice), 2e18);
        assertEq(controller.tradableBalanceOf(alice), 0);
    }

    function test_SettleManagedStrategyBalanceRequiresAuthorization() public {
        _allocateManagedForEpoch(owner, alice, 2e18, 5 days);

        vm.prank(alice);
        vm.expectRevert();
        controller.settleManagedStrategyBalance(alice, 1e18);
    }

    function test_SettleManagedStrategyBalanceRevertsOnZeroAmount() public {
        _allocateManagedForEpoch(owner, alice, 2e18, 5 days);

        vm.prank(owner);
        vm.expectRevert(AIUSDController.ZeroAmount.selector);
        controller.settleManagedStrategyBalance(alice, 0);
    }

    function test_SettleManagedStrategyBalanceReducesManagedWindow() public {
        _allocateManagedForEpoch(owner, alice, 5e18, 5 days);

        vm.prank(operator);
        controller.settleManagedStrategyBalance(alice, 2e18);

        assertEq(aiusd.balanceOf(alice), 3e18);
        assertEq(controller.managedBalanceOf(alice), 3e18);
        assertGt(controller.executionWindowEndsAt(alice), block.timestamp);
    }

    function test_DispatchCapitalRequiresAuthorization() public {
        vm.prank(alice);
        vm.expectRevert();
        controller.dispatchCapital(bob, 1e18);
    }

    function test_DispatchCapitalRevertsOnZeroRecipient() public {
        vm.prank(owner);
        vm.expectRevert(AIUSDController.ZeroAddressAccount.selector);
        controller.dispatchCapital(address(0), 1e18);
    }

    function test_SetDeskOperatorOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        controller.setDeskOperator(bob, true);
    }

    function test_ExpiredExecutionWindowIsIgnoredByReads() public {
        _allocateManagedForEpoch(owner, alice, 2e18, 1 days);
        vm.warp(block.timestamp + 1 days + 1);

        assertEq(controller.managedBalanceOf(alice), 0);
        assertEq(controller.executionWindowEndsAt(alice), 0);
    }
}
