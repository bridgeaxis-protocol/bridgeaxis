// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AIUSD} from "../../contracts/aiusd/AIUSD.sol";
import {AIUSDController} from "../../contracts/aiusd/AIUSDController.sol";
import {AIUSDTestBase} from "./utils/AIUSDTestBase.t.sol";

contract AIUSDSecurityTest is AIUSDTestBase {
    function testSecurity_ExecutionHubRemainsImmutableAfterConfiguration() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(AIUSD.ExecutionHubAlreadyConfigured.selector, address(controller)));
        aiusd.setExecutionHub(address(this));
    }

    function testSecurity_UnauthorizedDeskCannotAllocateManagedBalance() public {
        vm.prank(alice);
        vm.expectRevert();
        controller.allocateStrategyBalance(alice, 1e18);
    }

    function testSecurity_UnauthorizedDeskCannotDispatchCapital() public {
        _routeCapital(alice, 3e18);

        vm.prank(alice);
        vm.expectRevert();
        controller.dispatchCapital(alice, 1e18);
    }

    function testSecurity_OperatorCannotSettleMoreThanManagedEvenWithLargeFreeBalance() public {
        _routeCapital(alice, 20e18);
        _allocateManagedForEpoch(owner, alice, 3e18, 10 days);

        vm.prank(operator);
        vm.expectRevert();
        controller.settleManagedStrategyBalance(alice, 4e18);
    }

    function testSecurity_ReceivingFreeBalanceDoesNotUnlockManagedBalance() public {
        _routeCapital(alice, 1e18);
        _allocateManagedForEpoch(owner, alice, 5e18, 10 days);
        _routeCapital(bob, 1e18);

        vm.prank(bob);
        aiusd.transfer(alice, 1e18);

        vm.prank(alice);
        vm.expectRevert();
        aiusd.transfer(carol, 3e18);

        vm.prank(alice);
        aiusd.transfer(carol, 2e18);
    }

    function testSecurity_ManagedWindowExpiresBeforeTransfersUnlock() public {
        _allocateManagedForEpoch(owner, alice, 2e18, 1 days);

        vm.prank(alice);
        vm.expectRevert();
        aiusd.transfer(bob, 1e18);

        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(alice);
        aiusd.transfer(bob, 2e18);

        assertEq(aiusd.balanceOf(bob), 2e18);
    }

    function testSecurity_ZeroOperatorAddressRejected() public {
        vm.prank(owner);
        vm.expectRevert(AIUSDController.ZeroAddressAccount.selector);
        controller.setDeskOperator(address(0), true);
    }

    function testSecurity_FullManagedSettlementClearsWindowState() public {
        _allocateManagedForEpoch(owner, alice, 3e18, 10 days);

        vm.prank(operator);
        controller.settleManagedStrategyBalance(alice, 3e18);

        (uint256 managedBalance, uint64 releaseTime, bool active) = controller.executionWindowOf(alice);
        assertEq(managedBalance, 0);
        assertEq(releaseTime, 0);
        assertFalse(active);
    }
}
