// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AIUSDController} from "../../contracts/aiusd/AIUSDController.sol";
import {AIUSDTestBase} from "./utils/AIUSDTestBase.t.sol";

contract AIUSDFuzzTest is AIUSDTestBase {
    function _boundedAmount(uint96 rawAmount) internal pure returns (uint256) {
        uint256 amount = uint256(rawAmount);
        if (amount == 0) {
            amount = 1;
        }
        return amount > MAX_TEST_AMOUNT ? (amount % MAX_TEST_AMOUNT) + 1 : amount;
    }

    function _boundedEpoch(uint64 rawEpoch) internal view returns (uint64) {
        uint256 maxEpoch = controller.MAX_EXECUTION_EPOCH();
        uint256 epoch = uint256(rawEpoch);
        if (epoch == 0) {
            epoch = 1;
        }
        return uint64((epoch % maxEpoch) + 1);
    }

    function testFuzz_RouteCapitalCreditsOneToOne(uint8 actorSeed, uint96 rawAmount) public {
        address actor = _actor(actorSeed);
        uint256 amount = _boundedAmount(rawAmount);

        _routeCapital(actor, amount);

        assertEq(aiusd.balanceOf(actor), amount);
        assertEq(busdc.balanceOf(address(controller)), 0);
    }

    function testFuzz_AllocateStrategyBalanceCreditsBeneficiary(
        uint8 beneficiarySeed,
        uint96 rawAmount
    ) public {
        address beneficiary = _actor(beneficiarySeed);
        uint256 amount = _boundedAmount(rawAmount);

        _allocateManaged(owner, beneficiary, amount);

        assertEq(aiusd.balanceOf(beneficiary), amount);
    }

    function testFuzz_ManagedAllocationTracksManagedBalance(
        uint8 actorSeed,
        uint96 rawAmount,
        uint64 rawEpoch
    ) public {
        address actor = _actor(actorSeed);
        uint256 amount = _boundedAmount(rawAmount);
        uint64 epoch = _boundedEpoch(rawEpoch);

        _allocateManagedForEpoch(owner, actor, amount, epoch);

        assertEq(controller.managedBalanceOf(actor), amount);
        assertEq(aiusd.managedBalanceOf(actor), amount);
    }

    function testFuzz_ManagedAllocationSetsReleaseInFuture(
        uint8 actorSeed,
        uint96 rawAmount,
        uint64 rawEpoch
    ) public {
        address actor = _actor(actorSeed);
        uint256 amount = _boundedAmount(rawAmount);
        uint64 epoch = _boundedEpoch(rawEpoch);

        uint64 releaseTime = _allocateManagedForEpoch(owner, actor, amount, epoch);

        assertEq(controller.executionWindowEndsAt(actor), releaseTime);
        assertGt(releaseTime, block.timestamp);
    }

    function testFuzz_SecondManagedAllocationExtendsRelease(
        uint8 actorSeed,
        uint96 rawAmountA,
        uint64 rawEpochA,
        uint96 rawAmountB,
        uint64 rawEpochB
    ) public {
        address actor = _actor(actorSeed);
        uint256 amountA = _boundedAmount(rawAmountA);
        uint64 epochA = _boundedEpoch(rawEpochA);
        uint256 amountB = _boundedAmount(rawAmountB);
        uint64 epochB = _boundedEpoch(rawEpochB);

        uint64 firstRelease = _allocateManagedForEpoch(owner, actor, amountA, epochA);
        vm.warp(block.timestamp + 1 hours);
        uint256 afterWarp = block.timestamp;
        uint64 secondRelease = _allocateManagedForEpoch(owner, actor, amountB, epochB);
        uint256 expectedManaged = firstRelease > afterWarp ? amountA + amountB : amountB;
        uint64 expectedRelease = firstRelease > afterWarp
            ? (secondRelease > firstRelease ? secondRelease : firstRelease)
            : secondRelease;

        assertEq(controller.managedBalanceOf(actor), expectedManaged);
        assertEq(controller.executionWindowEndsAt(actor), expectedRelease);
    }

    function testFuzz_TradableTransferPreservesManagedBalance(
        uint8 actorSeed,
        uint8 receiverSeed,
        uint96 rawFreeAmount,
        uint96 rawManagedAmount,
        uint64 rawEpoch
    ) public {
        address actor = _actor(actorSeed);
        address receiver = _actor(uint8(uint16(receiverSeed) + 1));
        vm.assume(actor != receiver);

        uint256 freeAmount = _boundedAmount(rawFreeAmount);
        uint256 managedAmount = _boundedAmount(rawManagedAmount);
        uint64 epoch = _boundedEpoch(rawEpoch);

        _routeCapital(actor, freeAmount);
        _allocateManagedForEpoch(owner, actor, managedAmount, epoch);

        vm.prank(actor);
        aiusd.transfer(receiver, freeAmount);

        assertEq(controller.managedBalanceOf(actor), managedAmount);
        assertEq(aiusd.balanceOf(receiver), freeAmount);
    }

    function testFuzz_TransferAboveTradableReverts(
        uint8 actorSeed,
        uint8 receiverSeed,
        uint96 rawFreeAmount,
        uint96 rawManagedAmount,
        uint64 rawEpoch
    ) public {
        address actor = _actor(actorSeed);
        address receiver = _actor(uint8(uint16(receiverSeed) + 1));
        vm.assume(actor != receiver);

        uint256 freeAmount = _boundedAmount(rawFreeAmount);
        uint256 managedAmount = _boundedAmount(rawManagedAmount);
        uint64 epoch = _boundedEpoch(rawEpoch);

        _routeCapital(actor, freeAmount);
        _allocateManagedForEpoch(owner, actor, managedAmount, epoch);

        vm.prank(actor);
        vm.expectRevert();
        aiusd.transfer(receiver, freeAmount + 1);
    }

    function testFuzz_SettleTradableCannotExceedFreePortion(
        uint8 actorSeed,
        uint96 rawFreeAmount,
        uint96 rawManagedAmount,
        uint64 rawEpoch
    ) public {
        address actor = _actor(actorSeed);
        uint256 freeAmount = _boundedAmount(rawFreeAmount);
        uint256 managedAmount = _boundedAmount(rawManagedAmount);
        uint64 epoch = _boundedEpoch(rawEpoch);

        _routeCapital(actor, freeAmount);
        _allocateManagedForEpoch(owner, actor, managedAmount, epoch);

        vm.prank(actor);
        vm.expectRevert();
        controller.settleStrategyBalance(freeAmount + 1);
    }

    function testFuzz_SettleManagedCannotExceedManagedPortion(
        uint8 actorSeed,
        uint96 rawFreeAmount,
        uint96 rawManagedAmount,
        uint64 rawEpoch
    ) public {
        address actor = _actor(actorSeed);
        uint256 freeAmount = _boundedAmount(rawFreeAmount);
        uint256 managedAmount = _boundedAmount(rawManagedAmount);
        uint64 epoch = _boundedEpoch(rawEpoch);

        _routeCapital(actor, freeAmount);
        _allocateManagedForEpoch(owner, actor, managedAmount, epoch);

        vm.prank(operator);
        vm.expectRevert();
        controller.settleManagedStrategyBalance(actor, managedAmount + 1);
    }

    function testFuzz_SettleManagedExactAmountClearsWindow(
        uint8 actorSeed,
        uint96 rawManagedAmount,
        uint64 rawEpoch
    ) public {
        address actor = _actor(actorSeed);
        uint256 managedAmount = _boundedAmount(rawManagedAmount);
        uint64 epoch = _boundedEpoch(rawEpoch);

        _allocateManagedForEpoch(owner, actor, managedAmount, epoch);

        vm.prank(operator);
        controller.settleManagedStrategyBalance(actor, managedAmount);

        assertEq(controller.managedBalanceOf(actor), 0);
        assertEq(controller.executionWindowEndsAt(actor), 0);
    }

    function testFuzz_DispatchCapitalMovesExactAmount(uint96 rawAmount) public {
        uint256 amount = _boundedAmount(rawAmount);

        bytes32 minterRole = busdc.MINTER_ROLE();
        vm.prank(owner);
        busdc.grantRole(minterRole, address(controller));

        vm.prank(owner);
        controller.dispatchCapital(bob, amount);

        assertEq(busdc.balanceOf(bob), amount);
    }

    function testFuzz_ManagedBalanceExpiresAfterWarp(
        uint8 actorSeed,
        uint96 rawAmount,
        uint64 rawEpoch
    ) public {
        address actor = _actor(actorSeed);
        uint256 amount = _boundedAmount(rawAmount);
        uint64 epoch = _boundedEpoch(rawEpoch);

        _allocateManagedForEpoch(owner, actor, amount, epoch);
        vm.warp(block.timestamp + epoch + 1);

        assertEq(controller.managedBalanceOf(actor), 0);
        assertEq(aiusd.managedBalanceOf(actor), 0);
    }

    function testFuzz_TradableBalanceEqualsBalanceMinusManaged(
        uint8 actorSeed,
        uint96 rawFreeAmount,
        uint96 rawManagedAmount,
        uint64 rawEpoch
    ) public {
        address actor = _actor(actorSeed);
        uint256 freeAmount = _boundedAmount(rawFreeAmount);
        uint256 managedAmount = _boundedAmount(rawManagedAmount);
        uint64 epoch = _boundedEpoch(rawEpoch);

        _routeCapital(actor, freeAmount);
        _allocateManagedForEpoch(owner, actor, managedAmount, epoch);

        assertEq(aiusd.tradableBalanceOf(actor), aiusd.balanceOf(actor) - aiusd.managedBalanceOf(actor));
    }

    function testFuzz_MaxExecutionEpochIsAccepted(uint8 actorSeed, uint96 rawAmount) public {
        address actor = _actor(actorSeed);
        uint256 amount = _boundedAmount(rawAmount);

        _allocateManagedForEpoch(owner, actor, amount, uint64(controller.MAX_EXECUTION_EPOCH()));

        assertEq(controller.managedBalanceOf(actor), amount);
    }

    function testFuzz_ExecutionEpochAboveMaximumReverts(uint8 actorSeed, uint96 rawAmount) public {
        address actor = _actor(actorSeed);
        uint256 amount = _boundedAmount(rawAmount);

        _mintReserve(owner, amount);

        vm.prank(owner);
        vm.expectRevert();
        controller.allocateStrategyBalanceForEpoch(actor, amount, type(uint64).max);
    }

    function testFuzz_AllocateManagedAndFreePreservesTotalSupply(
        uint8 actorSeed,
        uint96 rawFreeAmount,
        uint96 rawManagedAmount,
        uint64 rawEpoch
    ) public {
        address actor = _actor(actorSeed);
        uint256 freeAmount = _boundedAmount(rawFreeAmount);
        uint256 managedAmount = _boundedAmount(rawManagedAmount);
        uint64 epoch = _boundedEpoch(rawEpoch);

        _routeCapital(actor, freeAmount);
        _allocateManagedForEpoch(owner, actor, managedAmount, epoch);

        assertEq(aiusd.totalSupply(), freeAmount + managedAmount);
    }

    function testFuzz_SettlingTradableReducesTotalSupply(
        uint8 actorSeed,
        uint96 rawAmount
    ) public {
        address actor = _actor(actorSeed);
        uint256 amount = _boundedAmount(rawAmount);

        _routeCapital(actor, amount);

        vm.prank(actor);
        controller.settleStrategyBalance(amount);

        assertEq(aiusd.totalSupply(), 0);
    }

    function testFuzz_SettlingManagedReducesTotalSupply(
        uint8 actorSeed,
        uint96 rawAmount,
        uint64 rawEpoch
    ) public {
        address actor = _actor(actorSeed);
        uint256 amount = _boundedAmount(rawAmount);
        uint64 epoch = _boundedEpoch(rawEpoch);

        _allocateManagedForEpoch(owner, actor, amount, epoch);

        vm.prank(operator);
        controller.settleManagedStrategyBalance(actor, amount);

        assertEq(aiusd.totalSupply(), 0);
    }

    function testFuzz_ZeroAmountRouteAlwaysReverts(uint8 actorSeed) public {
        address actor = _actor(actorSeed);
        vm.prank(actor);
        vm.expectRevert(AIUSDController.ZeroAmount.selector);
        controller.routeCapital(0);
    }

    function testFuzz_ZeroAmountManagedSettlementAlwaysReverts(uint8 actorSeed) public {
        address actor = _actor(actorSeed);
        _allocateManagedForEpoch(owner, actor, 1e18, 1 days);

        vm.prank(operator);
        vm.expectRevert(AIUSDController.ZeroAmount.selector);
        controller.settleManagedStrategyBalance(actor, 0);
    }

    function testFuzz_ZeroBeneficiaryAllocationAlwaysReverts(uint96 rawAmount) public {
        uint256 amount = _boundedAmount(rawAmount);
        _mintReserve(owner, amount);

        vm.prank(owner);
        vm.expectRevert(AIUSDController.ZeroAddressAccount.selector);
        controller.allocateStrategyBalance(address(0), amount);
    }

    function testFuzz_OperatorGrantCanBeToggled(uint8 actorSeed) public {
        address actor = _actor(actorSeed);

        vm.prank(owner);
        controller.setDeskOperator(actor, true);
        assertTrue(controller.hasRole(controller.OPERATOR_ROLE(), actor));

        vm.prank(owner);
        controller.setDeskOperator(actor, false);
        assertFalse(controller.hasRole(controller.OPERATOR_ROLE(), actor));
    }
}
