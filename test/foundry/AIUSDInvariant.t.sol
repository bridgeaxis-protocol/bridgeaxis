// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {AIUSDHandler} from "./utils/AIUSDHandler.t.sol";
import {AIUSDTestBase} from "./utils/AIUSDTestBase.t.sol";

contract AIUSDInvariantTest is StdInvariant, AIUSDTestBase {
    AIUSDHandler internal handler;
    address[] internal trackedActors;

    function setUp() public override {
        super.setUp();

        trackedActors.push(alice);
        trackedActors.push(bob);
        trackedActors.push(carol);
        trackedActors.push(dave);

        handler = new AIUSDHandler(aiusd, controller, busdc, owner, operator, trackedActors);
        targetContract(address(handler));
    }

    function invariant_TotalSupplyNeverExceedsCap() public view {
        assertLe(aiusd.totalSupply(), aiusd.MAX_SUPPLY());
    }

    function invariant_ManagedBalanceNeverExceedsAccountBalance() public view {
        for (uint256 i = 0; i < trackedActors.length; i++) {
            address actor = trackedActors[i];
            assertLe(aiusd.managedBalanceOf(actor), aiusd.balanceOf(actor));
            assertLe(controller.managedBalanceOf(actor), aiusd.balanceOf(actor));
        }
    }

    function invariant_ControllerAndTokenViewsStayAligned() public view {
        for (uint256 i = 0; i < trackedActors.length; i++) {
            address actor = trackedActors[i];
            assertEq(aiusd.managedBalanceOf(actor), controller.managedBalanceOf(actor));
            assertEq(aiusd.tradableBalanceOf(actor), controller.tradableBalanceOf(actor));
        }
    }

    function invariant_ExecutionHubRemainsBoundToController() public view {
        assertEq(aiusd.executionHub(), address(controller));
    }
}
