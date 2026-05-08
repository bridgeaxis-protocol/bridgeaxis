// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./AIUSD.sol";
import "./BUSDC.sol";
import "./IAIUSDController.sol";

contract AIUSDController is Ownable, AccessControl, ReentrancyGuard, IAIUSDController {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    bytes32 public constant ROUTE_CAPITAL_REASON = keccak256("BRIDGEAXIS_ROUTE_CAPITAL");
    bytes32 public constant STRATEGY_ALLOCATION_REASON = keccak256("BRIDGEAXIS_STRATEGY_ALLOCATION");
    bytes32 public constant MANAGED_ALLOCATION_REASON = keccak256("BRIDGEAXIS_MANAGED_STRATEGY_ALLOCATION");
    bytes32 public constant RESERVE_DISPATCH_REASON = keccak256("BRIDGEAXIS_RESERVE_DISPATCH");

    uint64 public constant MAX_EXECUTION_EPOCH = 3650 days;

    struct ExecutionWindow {
        uint256 amount;
        uint64 releaseTime;
    }

    BUSDC public immutable busdc;
    AIUSD public immutable aiusd;

    mapping(address => ExecutionWindow) private _executionWindows;

    error ZeroAddressOwner();
    error ZeroAddressAccount();
    error ZeroAmount();
    error ZeroReasonId();
    error ZeroExecutionEpoch();
    error ExecutionEpochTooLong(uint256 requested, uint256 maximum);
    error NotAuthorized(address account);
    error InsufficientTradableBalance(address account, uint256 requested, uint256 available);
    error InsufficientManagedBalance(address account, uint256 requested, uint256 available);

    event CapitalRouted(address indexed operator, address indexed beneficiary, uint256 amount, bytes32 indexed reasonId);
    event StrategyBalanceAllocated(
        address indexed operator,
        address indexed reserveAccount,
        address indexed beneficiary,
        uint256 amount,
        bytes32 reasonId
    );
    event StrategyBalanceAllocatedForEpoch(
        address indexed operator,
        address indexed reserveAccount,
        address indexed beneficiary,
        uint256 amount,
        uint64 releaseTime,
        bytes32 reasonId
    );
    event StrategyBalanceSettled(address indexed operator, address indexed account, uint256 amount);
    event ManagedStrategyBalanceSettled(
        address indexed operator,
        address indexed account,
        uint256 amount,
        uint256 remainingManagedBalance,
        uint64 releaseTime
    );
    event ReserveConsumed(
        address indexed operator,
        address indexed reserveAccount,
        address indexed beneficiary,
        uint256 amount,
        bytes32 reasonId
    );
    event ReserveDispatched(address indexed operator, address indexed recipient, uint256 amount, bytes32 indexed reasonId);
    event ExecutionWindowReleased(address indexed account, uint256 amount);
    event DeskOperatorUpdated(address indexed operator, bool granted);

    modifier onlyOwnerOrOperator() {
        if (owner() != msg.sender && !hasRole(OPERATOR_ROLE, msg.sender)) {
            revert NotAuthorized(msg.sender);
        }
        _;
    }

    constructor(address busdcAddress, address aiusdAddress, address initialOwner) Ownable(initialOwner) {
        if (busdcAddress == address(0) || aiusdAddress == address(0)) {
            revert ZeroAddressAccount();
        }

        if (initialOwner == address(0)) {
            revert ZeroAddressOwner();
        }

        busdc = BUSDC(busdcAddress);
        aiusd = AIUSD(aiusdAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
    }

    function routeCapital(uint256 amount) external nonReentrant {
        _routeCapital(msg.sender, msg.sender, amount, ROUTE_CAPITAL_REASON);
    }

    function routeCapitalWithReason(uint256 amount, bytes32 reasonId) external nonReentrant {
        _routeCapital(msg.sender, msg.sender, amount, reasonId);
    }

    function allocateStrategyBalance(
        address beneficiary,
        uint256 amount
    ) external onlyOwnerOrOperator nonReentrant {
        _allocateStrategyBalance(msg.sender, beneficiary, amount, STRATEGY_ALLOCATION_REASON);
    }

    function allocateStrategyBalanceWithReason(
        address beneficiary,
        uint256 amount,
        bytes32 reasonId
    ) external onlyOwnerOrOperator nonReentrant {
        _allocateStrategyBalance(msg.sender, beneficiary, amount, reasonId);
    }

    function allocateStrategyBalanceFromReserve(
        address reserveAccount,
        address beneficiary,
        uint256 amount,
        bytes32 reasonId
    ) external onlyOwnerOrOperator nonReentrant {
        _allocateStrategyBalanceFromReserve(reserveAccount, beneficiary, amount, reasonId);
    }

    function allocateStrategyBalanceForEpoch(
        address beneficiary,
        uint256 amount,
        uint64 executionEpoch
    ) external onlyOwnerOrOperator nonReentrant returns (uint64 releaseTime) {
        releaseTime = _allocateStrategyBalanceForEpoch(
            msg.sender,
            beneficiary,
            amount,
            executionEpoch,
            MANAGED_ALLOCATION_REASON
        );
    }

    function allocateStrategyBalanceForEpochWithReason(
        address beneficiary,
        uint256 amount,
        uint64 executionEpoch,
        bytes32 reasonId
    ) external onlyOwnerOrOperator nonReentrant returns (uint64 releaseTime) {
        releaseTime = _allocateStrategyBalanceForEpoch(msg.sender, beneficiary, amount, executionEpoch, reasonId);
    }

    function allocateStrategyBalanceForEpochFromReserve(
        address reserveAccount,
        address beneficiary,
        uint256 amount,
        uint64 executionEpoch,
        bytes32 reasonId
    ) external onlyOwnerOrOperator nonReentrant returns (uint64 releaseTime) {
        releaseTime = _allocateStrategyBalanceForEpoch(reserveAccount, beneficiary, amount, executionEpoch, reasonId);
    }

    function settleStrategyBalance(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert ZeroAmount();
        }

        uint256 tradableBalance = tradableBalanceOf(msg.sender);
        if (amount > tradableBalance) {
            revert InsufficientTradableBalance(msg.sender, amount, tradableBalance);
        }

        aiusd.settleStrategyAllocation(msg.sender, amount);

        emit StrategyBalanceSettled(msg.sender, msg.sender, amount);
    }

    function settleManagedStrategyBalance(
        address account,
        uint256 amount
    ) external onlyOwnerOrOperator nonReentrant {
        if (account == address(0)) {
            revert ZeroAddressAccount();
        }

        if (amount == 0) {
            revert ZeroAmount();
        }

        _syncExecutionWindow(account);

        ExecutionWindow storage executionWindow = _executionWindows[account];
        uint256 managedBalance = executionWindow.amount;

        if (managedBalance < amount || executionWindow.releaseTime == 0) {
            revert InsufficientManagedBalance(account, amount, managedBalance);
        }

        managedBalance -= amount;
        uint64 releaseTime = executionWindow.releaseTime;

        if (managedBalance == 0) {
            delete _executionWindows[account];
            releaseTime = 0;
        } else {
            executionWindow.amount = managedBalance;
        }

        aiusd.settleStrategyAllocation(account, amount);

        emit ManagedStrategyBalanceSettled(msg.sender, account, amount, managedBalance, releaseTime);
    }

    /// @notice Optional reserve recovery path. The controller must be granted BUSDC.MINTER_ROLE to use it.
    function dispatchCapital(address recipient, uint256 amount) external onlyOwnerOrOperator nonReentrant {
        if (recipient == address(0)) {
            revert ZeroAddressAccount();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        busdc.mintReserve(recipient, amount, RESERVE_DISPATCH_REASON);
        emit ReserveDispatched(msg.sender, recipient, amount, RESERVE_DISPATCH_REASON);
    }

    function setDeskOperator(address operator, bool granted) external onlyOwner {
        if (operator == address(0)) {
            revert ZeroAddressAccount();
        }

        if (granted) {
            grantRole(OPERATOR_ROLE, operator);
        } else {
            revokeRole(OPERATOR_ROLE, operator);
        }

        emit DeskOperatorUpdated(operator, granted);
    }

    function managedBalanceOf(address account) public view returns (uint256) {
        (uint256 managedBalance, ) = _activeExecutionWindow(account);
        return managedBalance;
    }

    function tradableBalanceOf(address account) public view returns (uint256) {
        uint256 balance = aiusd.balanceOf(account);
        uint256 managedBalance = managedBalanceOf(account);

        if (managedBalance >= balance) {
            return 0;
        }

        return balance - managedBalance;
    }

    function executionWindowEndsAt(address account) external view returns (uint64) {
        (, uint64 releaseTime) = _activeExecutionWindow(account);
        return releaseTime;
    }

    function executionWindowOf(
        address account
    ) external view returns (uint256 managedBalance, uint64 releaseTime, bool active) {
        (managedBalance, releaseTime) = _activeExecutionWindow(account);
        active = managedBalance != 0;
    }

    function getExecutionWindowInfo(
        address account
    ) external view override returns (uint256 managedBalance, uint256 releaseTime) {
        uint64 activeReleaseTime;
        (managedBalance, activeReleaseTime) = _activeExecutionWindow(account);
        releaseTime = activeReleaseTime;
    }

    function _routeCapital(address reserveAccount, address beneficiary, uint256 amount, bytes32 reasonId) private {
        _consumeReserve(reserveAccount, beneficiary, amount, reasonId);
        aiusd.recordStrategyAllocation(beneficiary, amount);

        emit CapitalRouted(msg.sender, beneficiary, amount, reasonId);
    }

    function _allocateStrategyBalance(address reserveAccount, address beneficiary, uint256 amount, bytes32 reasonId) private {
        _allocateStrategyBalanceFromReserve(reserveAccount, beneficiary, amount, reasonId);
    }

    function _allocateStrategyBalanceFromReserve(
        address reserveAccount,
        address beneficiary,
        uint256 amount,
        bytes32 reasonId
    ) private {
        if (beneficiary == address(0)) {
            revert ZeroAddressAccount();
        }

        _consumeReserve(reserveAccount, beneficiary, amount, reasonId);
        aiusd.recordStrategyAllocation(beneficiary, amount);

        emit StrategyBalanceAllocated(msg.sender, reserveAccount, beneficiary, amount, reasonId);
    }

    function _allocateStrategyBalanceForEpoch(
        address reserveAccount,
        address beneficiary,
        uint256 amount,
        uint64 executionEpoch,
        bytes32 reasonId
    ) private returns (uint64 releaseTime) {
        if (beneficiary == address(0)) {
            revert ZeroAddressAccount();
        }

        if (executionEpoch == 0) {
            revert ZeroExecutionEpoch();
        }

        if (executionEpoch > MAX_EXECUTION_EPOCH) {
            revert ExecutionEpochTooLong(executionEpoch, MAX_EXECUTION_EPOCH);
        }

        releaseTime = uint64(block.timestamp) + executionEpoch;

        _consumeReserve(reserveAccount, beneficiary, amount, reasonId);
        _expandExecutionWindow(beneficiary, amount, releaseTime);
        aiusd.recordStrategyAllocation(beneficiary, amount);

        emit StrategyBalanceAllocatedForEpoch(msg.sender, reserveAccount, beneficiary, amount, releaseTime, reasonId);
    }

    function _consumeReserve(address reserveAccount, address beneficiary, uint256 amount, bytes32 reasonId) private {
        if (reserveAccount == address(0) || beneficiary == address(0)) {
            revert ZeroAddressAccount();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (reasonId == bytes32(0)) {
            revert ZeroReasonId();
        }

        busdc.burnReserve(reserveAccount, amount, reasonId);
        emit ReserveConsumed(msg.sender, reserveAccount, beneficiary, amount, reasonId);
    }

    function _expandExecutionWindow(address account, uint256 amount, uint64 releaseTime) internal {
        _syncExecutionWindow(account);

        ExecutionWindow storage executionWindow = _executionWindows[account];
        executionWindow.amount += amount;

        if (releaseTime > executionWindow.releaseTime) {
            executionWindow.releaseTime = releaseTime;
        }
    }

    function _activeExecutionWindow(
        address account
    ) internal view returns (uint256 managedBalance, uint64 releaseTime) {
        ExecutionWindow memory executionWindow = _executionWindows[account];

        if (executionWindow.amount == 0 || block.timestamp >= executionWindow.releaseTime) {
            return (0, 0);
        }

        return (executionWindow.amount, executionWindow.releaseTime);
    }

    function _syncExecutionWindow(address account) internal {
        ExecutionWindow memory executionWindow = _executionWindows[account];

        if (executionWindow.amount != 0 && block.timestamp >= executionWindow.releaseTime) {
            delete _executionWindows[account];
            emit ExecutionWindowReleased(account, executionWindow.amount);
        }
    }
}
