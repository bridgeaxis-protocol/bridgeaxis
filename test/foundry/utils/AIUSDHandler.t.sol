// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AIUSD} from "../../../contracts/aiusd/AIUSD.sol";
import {AIUSDController} from "../../../contracts/aiusd/AIUSDController.sol";
import {BUSDC} from "../../../contracts/aiusd/BUSDC.sol";

contract AIUSDHandler is Test {
    uint256 internal constant MAX_TEST_AMOUNT = 10_000e18;
    bytes32 internal constant TEST_RESERVE_REASON = keccak256("BRIDGEAXIS_INVARIANT_RESERVE");

    AIUSD public immutable aiusd;
    AIUSDController public immutable controller;
    BUSDC public immutable busdc;
    address public immutable owner;
    address public immutable operator;
    address[] internal actors;

    constructor(
        AIUSD aiusd_,
        AIUSDController controller_,
        BUSDC busdc_,
        address owner_,
        address operator_,
        address[] memory actors_
    ) {
        aiusd = aiusd_;
        controller = controller_;
        busdc = busdc_;
        owner = owner_;
        operator = operator_;
        actors = actors_;
    }

    function actor(uint8 seed) public view returns (address) {
        return actors[seed % actors.length];
    }

    function _boundAmount(uint96 rawAmount) internal pure returns (uint256) {
        uint256 amount = uint256(rawAmount);
        if (amount == 0) {
            amount = 1;
        }
        return amount > MAX_TEST_AMOUNT ? (amount % MAX_TEST_AMOUNT) + 1 : amount;
    }

    function _boundEpoch(uint64 rawEpoch) internal view returns (uint64) {
        uint256 maxEpoch = controller.MAX_EXECUTION_EPOCH();
        uint256 epoch = uint256(rawEpoch);
        if (epoch == 0) {
            epoch = 1;
        }
        return uint64((epoch % maxEpoch) + 1);
    }

    function _mintReserve(address account, uint256 amount) internal {
        vm.prank(owner);
        busdc.mintReserve(account, amount, TEST_RESERVE_REASON);
    }

    function routeCapital(uint8 actorSeed, uint96 rawAmount) external {
        address target = actor(actorSeed);
        uint256 amount = _boundAmount(rawAmount);

        _mintReserve(target, amount);
        vm.prank(target);
        controller.routeCapital(amount);
    }

    function allocateManaged(uint8 actorSeed, uint96 rawAmount, uint64 rawEpoch) external {
        address target = actor(actorSeed);
        uint256 amount = _boundAmount(rawAmount);
        uint64 epoch = _boundEpoch(rawEpoch);

        _mintReserve(owner, amount);
        vm.prank(owner);
        controller.allocateStrategyBalanceForEpoch(target, amount, epoch);
    }

    function settleTradable(uint8 actorSeed, uint96 rawAmount) external {
        address target = actor(actorSeed);
        uint256 available = controller.tradableBalanceOf(target);
        if (available == 0) {
            return;
        }

        uint256 amount = bound(_boundAmount(rawAmount), 1, available);
        vm.prank(target);
        controller.settleStrategyBalance(amount);
    }

    function settleManaged(uint8 actorSeed, uint96 rawAmount) external {
        address target = actor(actorSeed);
        uint256 managed = controller.managedBalanceOf(target);
        if (managed == 0) {
            return;
        }

        uint256 amount = bound(_boundAmount(rawAmount), 1, managed);
        vm.prank(operator);
        controller.settleManagedStrategyBalance(target, amount);
    }

    function transferTradable(uint8 fromSeed, uint8 toSeed, uint96 rawAmount) external {
        address from = actor(fromSeed);
        address to = actor(uint8(uint16(toSeed) + 1));
        if (from == to) {
            return;
        }

        uint256 tradable = aiusd.tradableBalanceOf(from);
        if (tradable == 0) {
            return;
        }

        uint256 amount = bound(_boundAmount(rawAmount), 1, tradable);
        vm.prank(from);
        aiusd.transfer(to, amount);
    }

    function warpForward(uint64 rawSeconds) external {
        uint256 step = uint256(rawSeconds) % 30 days;
        vm.warp(block.timestamp + step);
    }
}
