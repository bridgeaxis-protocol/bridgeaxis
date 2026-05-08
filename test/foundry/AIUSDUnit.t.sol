// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AIUSD} from "../../contracts/aiusd/AIUSD.sol";
import {AIUSDTestBase} from "./utils/AIUSDTestBase.t.sol";

contract AIUSDUnitTest is AIUSDTestBase {
    function test_ExecutionHubCannotBeZero() public {
        AIUSD token = new AIUSD(owner);

        vm.prank(owner);
        vm.expectRevert(AIUSD.ZeroAddressExecutionHub.selector);
        token.setExecutionHub(address(0));
    }

    function test_ExecutionHubCanOnlyBeConfiguredOnce() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(AIUSD.ExecutionHubAlreadyConfigured.selector, address(controller)));
        aiusd.setExecutionHub(address(this));
    }

    function test_RecordStrategyAllocationMintsWhenCalledByHub() public {
        AIUSD token = new AIUSD(owner);

        vm.prank(owner);
        token.setExecutionHub(address(this));

        token.recordStrategyAllocation(alice, 5e18);

        assertEq(token.balanceOf(alice), 5e18);
        assertEq(token.totalSupply(), 5e18);
    }

    function test_NonHubCannotRecordStrategyAllocation() public {
        vm.prank(alice);
        vm.expectRevert();
        aiusd.recordStrategyAllocation(alice, 1e18);
    }

    function test_NonHubCannotSettleStrategyAllocation() public {
        vm.prank(alice);
        vm.expectRevert();
        aiusd.settleStrategyAllocation(alice, 1e18);
    }

    function test_RecordStrategyAllocationRejectsZeroAccount() public {
        AIUSD token = new AIUSD(owner);

        vm.prank(owner);
        token.setExecutionHub(address(this));

        vm.expectRevert(AIUSD.ZeroAddressAccount.selector);
        token.recordStrategyAllocation(address(0), 1e18);
    }

    function test_SettleStrategyAllocationRejectsZeroAccount() public {
        AIUSD token = new AIUSD(owner);

        vm.prank(owner);
        token.setExecutionHub(address(this));

        vm.expectRevert(AIUSD.ZeroAddressAccount.selector);
        token.settleStrategyAllocation(address(0), 1e18);
    }

    function test_ManagedBalanceIsZeroBeforeHubConfiguration() public {
        AIUSD token = new AIUSD(owner);
        assertEq(token.managedBalanceOf(alice), 0);
    }

    function test_ManagedBalanceReturnsZeroAfterWindowExpires() public {
        _allocateManagedForEpoch(owner, alice, 3e18, 1 days);
        vm.warp(block.timestamp + 1 days + 1);

        assertEq(aiusd.managedBalanceOf(alice), 0);
    }

    function test_TradableBalanceMatchesFreePortion() public {
        _routeCapital(alice, 10e18);
        _allocateManagedForEpoch(owner, alice, 3e18, 10 days);

        assertEq(aiusd.balanceOf(alice), 13e18);
        assertEq(aiusd.managedBalanceOf(alice), 3e18);
        assertEq(aiusd.tradableBalanceOf(alice), 10e18);
    }

    function test_TransferRevertsWhenExceedingTradableBalance() public {
        _routeCapital(alice, 10e18);
        _allocateManagedForEpoch(owner, alice, 3e18, 10 days);

        vm.prank(alice);
        vm.expectRevert();
        aiusd.transfer(bob, 11e18);
    }

    function test_TransferWithinTradableBalanceSucceeds() public {
        _routeCapital(alice, 10e18);
        _allocateManagedForEpoch(owner, alice, 3e18, 10 days);

        vm.prank(alice);
        aiusd.transfer(bob, 10e18);

        assertEq(aiusd.balanceOf(alice), 3e18);
        assertEq(aiusd.balanceOf(bob), 10e18);
        assertEq(aiusd.managedBalanceOf(alice), 3e18);
    }

    function test_SupplyCapIsEnforced() public {
        AIUSD token = new AIUSD(owner);

        vm.prank(owner);
        token.setExecutionHub(address(this));

        uint256 maxSupply = token.MAX_SUPPLY();
        token.recordStrategyAllocation(alice, maxSupply);

        vm.expectRevert(abi.encodeWithSelector(AIUSD.SupplyCapExceeded.selector, maxSupply + 1, maxSupply));
        token.recordStrategyAllocation(alice, 1);
    }
}
