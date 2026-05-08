// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AIUSDTestBase} from "./utils/AIUSDTestBase.t.sol";

contract AIUSDIntegrationTest is AIUSDTestBase {
    function testIntegration_FullWalletManagedLifecycle() public {
        _routeCapital(alice, 10e18);
        _allocateManagedForEpoch(owner, alice, 2e18, 7 days);

        vm.prank(alice);
        aiusd.transfer(bob, 10e18);

        vm.prank(operator);
        controller.settleManagedStrategyBalance(alice, 2e18);

        assertEq(aiusd.balanceOf(alice), 0);
        assertEq(aiusd.balanceOf(bob), 10e18);
        assertEq(controller.managedBalanceOf(alice), 0);
    }

    function testIntegration_AggregatedExecutionWindowExtendsAcrossAllocations() public {
        uint64 firstRelease = _allocateManagedForEpoch(owner, alice, 2e18, 30 days);
        vm.warp(block.timestamp + 15 days);
        uint64 secondRelease = _allocateManagedForEpoch(owner, alice, 1e18, 45 days);

        assertEq(controller.managedBalanceOf(alice), 3e18);
        assertGt(secondRelease, firstRelease);
        assertEq(controller.executionWindowEndsAt(alice), secondRelease);
    }

    function testIntegration_MultiAccountWindowsRemainIsolated() public {
        _allocateManagedForEpoch(owner, alice, 2e18, 10 days);
        _allocateManagedForEpoch(operator, bob, 3e18, 20 days);
        _routeCapital(carol, 4e18);

        assertEq(controller.managedBalanceOf(alice), 2e18);
        assertEq(controller.managedBalanceOf(bob), 3e18);
        assertEq(controller.managedBalanceOf(carol), 0);
        assertEq(controller.tradableBalanceOf(carol), 4e18);
    }

    function testIntegration_ExpiredManagedWindowUnlocksRestrictedBalance() public {
        _routeCapital(alice, 5e18);
        _allocateManagedForEpoch(owner, alice, 2e18, 1 days);
        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(alice);
        aiusd.transfer(bob, 7e18);

        assertEq(aiusd.balanceOf(alice), 0);
        assertEq(aiusd.balanceOf(bob), 7e18);
    }

    function testIntegration_ReserveIsConsumedBeforeOutstandingAIUSDMints() public {
        _routeCapital(alice, 4e18);
        _allocateManaged(owner, bob, 3e18);
        _allocateManagedForEpoch(operator, carol, 2e18, 10 days);

        assertEq(busdc.balanceOf(address(controller)), 0);
        assertEq(busdc.totalSupply(), 0);
        assertEq(aiusd.totalSupply(), 9e18);
    }

    function testIntegration_OperatorAndHolderSettlementCanBeComposed() public {
        _routeCapital(alice, 8e18);
        _allocateManagedForEpoch(owner, alice, 2e18, 10 days);

        vm.prank(alice);
        controller.settleStrategyBalance(8e18);

        vm.prank(operator);
        controller.settleManagedStrategyBalance(alice, 2e18);

        assertEq(aiusd.totalSupply(), 0);
        assertEq(busdc.totalSupply(), 0);
    }
}
