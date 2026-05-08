// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AIUSD} from "../../../contracts/aiusd/AIUSD.sol";
import {AIUSDController} from "../../../contracts/aiusd/AIUSDController.sol";
import {BUSDC} from "../../../contracts/aiusd/BUSDC.sol";

abstract contract AIUSDTestBase is Test {
    uint8 internal constant AIUSD_DECIMALS = 18;
    bytes32 internal constant TEST_RESERVE_REASON = keccak256("BRIDGEAXIS_TEST_RESERVE");

    address internal owner = makeAddr("owner");
    address internal operator = makeAddr("operator");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");

    uint256 internal constant MAX_TEST_AMOUNT = 1_000_000e18;

    AIUSD internal aiusd;
    AIUSDController internal controller;
    BUSDC internal busdc;

    function setUp() public virtual {
        vm.startPrank(owner);
        busdc = new BUSDC(owner);
        aiusd = new AIUSD(owner);
        controller = new AIUSDController(address(busdc), address(aiusd), owner);
        aiusd.setExecutionHub(address(controller));
        busdc.grantRole(busdc.BURNER_ROLE(), address(controller));
        controller.setDeskOperator(operator, true);
        vm.stopPrank();
    }

    function _actor(uint8 seed) internal view returns (address) {
        address[4] memory actors = [alice, bob, carol, dave];
        return actors[seed % actors.length];
    }

    function _mintReserve(address account, uint256 amount) internal {
        vm.prank(owner);
        busdc.mintReserve(account, amount, TEST_RESERVE_REASON);
    }

    function _routeCapital(address account, uint256 amount) internal {
        _mintReserve(account, amount);
        vm.prank(account);
        controller.routeCapital(amount);
    }

    function _allocateManaged(address caller, address beneficiary, uint256 amount) internal {
        _mintReserve(caller, amount);
        vm.prank(caller);
        controller.allocateStrategyBalance(beneficiary, amount);
    }

    function _allocateManagedForEpoch(
        address caller,
        address beneficiary,
        uint256 amount,
        uint64 epoch
    ) internal returns (uint64 releaseTime) {
        _mintReserve(caller, amount);
        vm.prank(caller);
        releaseTime = controller.allocateStrategyBalanceForEpoch(beneficiary, amount, epoch);
    }
}
