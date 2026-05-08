// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title BridgeAxis USD Credit
/// @notice Internal reserve credit that can be consumed 1:1 by BridgeAxis controllers to mint AIUSD.
contract BUSDC is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;

    error ZeroAddressAdmin();
    error ZeroAddressAccount();
    error ZeroAmount();
    error ZeroReasonId();
    error SupplyCapExceeded();

    event ReserveMinted(
        address indexed operator,
        address indexed account,
        uint256 amount,
        bytes32 indexed reasonId
    );
    event ReserveBurned(
        address indexed operator,
        address indexed account,
        uint256 amount,
        bytes32 indexed reasonId
    );

    constructor(address admin) ERC20("BridgeAxis USD Credit", "bUSDC") {
        if (admin == address(0)) {
            revert ZeroAddressAdmin();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mintReserve(address account, uint256 amount, bytes32 reasonId) external onlyRole(MINTER_ROLE) {
        _mintReserve(account, amount, reasonId);
    }

    function burnReserve(address account, uint256 amount, bytes32 reasonId) external onlyRole(BURNER_ROLE) {
        _burnReserve(account, amount, reasonId);
    }

    function burnOwnReserve(uint256 amount, bytes32 reasonId) external {
        _burnReserve(msg.sender, amount, reasonId);
    }

    function _mintReserve(address account, uint256 amount, bytes32 reasonId) private {
        if (account == address(0)) {
            revert ZeroAddressAccount();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (reasonId == bytes32(0)) {
            revert ZeroReasonId();
        }
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert SupplyCapExceeded();
        }

        _mint(account, amount);
        emit ReserveMinted(msg.sender, account, amount, reasonId);
    }

    function _burnReserve(address account, uint256 amount, bytes32 reasonId) private {
        if (account == address(0)) {
            revert ZeroAddressAccount();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (reasonId == bytes32(0)) {
            revert ZeroReasonId();
        }

        _burn(account, amount);
        emit ReserveBurned(msg.sender, account, amount, reasonId);
    }
}
