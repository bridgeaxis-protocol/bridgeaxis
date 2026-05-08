// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IAIUSDController.sol";

contract AIUSD is ERC20, AccessControl {
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    address public executionHub;

    error ZeroAddressAdmin();
    error ZeroAddressAccount();
    error ZeroAddressExecutionHub();
    error ExecutionHubAlreadyConfigured(address executionHub);
    error SupplyCapExceeded(uint256 requestedSupply, uint256 maxSupply);
    error InsufficientTradableBalance(address account, uint256 requested, uint256 available);

    event ExecutionHubConfigured(address indexed executionHub);
    event StrategyAllocationRecorded(address indexed executionHub, address indexed account, uint256 amount);
    event StrategyAllocationSettled(address indexed executionHub, address indexed account, uint256 amount);

    constructor(address admin) ERC20("AIUSD", "AIUSD") {
        if (admin == address(0)) {
            revert ZeroAddressAdmin();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setExecutionHub(address executionHubAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (executionHubAddress == address(0)) {
            revert ZeroAddressExecutionHub();
        }

        if (executionHub != address(0)) {
            revert ExecutionHubAlreadyConfigured(executionHub);
        }

        executionHub = executionHubAddress;
        _grantRole(CONTROLLER_ROLE, executionHubAddress);

        emit ExecutionHubConfigured(executionHubAddress);
    }

    function recordStrategyAllocation(address account, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        if (account == address(0)) {
            revert ZeroAddressAccount();
        }

        uint256 requestedSupply = totalSupply() + amount;
        if (requestedSupply > MAX_SUPPLY) {
            revert SupplyCapExceeded(requestedSupply, MAX_SUPPLY);
        }

        _mint(account, amount);

        emit StrategyAllocationRecorded(msg.sender, account, amount);
    }

    function settleStrategyAllocation(address account, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        if (account == address(0)) {
            revert ZeroAddressAccount();
        }

        _burn(account, amount);

        emit StrategyAllocationSettled(msg.sender, account, amount);
    }

    function managedBalanceOf(address account) public view returns (uint256) {
        if (executionHub == address(0)) {
            return 0;
        }

        (uint256 managedBalance, uint256 releaseTime) = IAIUSDController(executionHub)
            .getExecutionWindowInfo(account);

        if (managedBalance == 0 || block.timestamp >= releaseTime) {
            return 0;
        }

        return managedBalance;
    }

    function tradableBalanceOf(address account) external view returns (uint256) {
        uint256 balance = balanceOf(account);
        uint256 managedBalance = managedBalanceOf(account);

        if (managedBalance >= balance) {
            return 0;
        }

        return balance - managedBalance;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from != address(0) && to != address(0) && executionHub != address(0)) {
            (uint256 managedBalance, uint256 releaseTime) = IAIUSDController(executionHub)
                .getExecutionWindowInfo(from);

            if (managedBalance != 0 && block.timestamp < releaseTime) {
                uint256 balance = balanceOf(from);
                uint256 tradableBalance = balance > managedBalance ? balance - managedBalance : 0;

                if (amount > tradableBalance) {
                    revert InsufficientTradableBalance(from, amount, tradableBalance);
                }
            }
        }

        super._update(from, to, amount);
    }
}
