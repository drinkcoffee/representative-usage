// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Blacklist.sol";

contract BitGem is ERC20, ERC20Burnable, Blacklist, AccessControl, Pausable {
    bytes32 constant MINTER_ADMIN_ROLE = keccak256("MINTER_ADMIN_ROLE");
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address private _defaultAdmin;
    address private _assignedDefaultAdmin = address(0x0);

    event DefaultAdminTransferStarted(address oldAdmin, address newAdmin);
    event DefaultAdminTransferred(address oldAdmin, address newAdmin);

    constructor(address admin, address minter) ERC20("BitGem", "BGEM") {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);

        // MINTER_ADMIN_ROLE can grant MINTER_ROLE
        _setRoleAdmin(MINTER_ROLE, MINTER_ADMIN_ROLE);
        _setupRole(MINTER_ADMIN_ROLE, admin);

        _setupRole(MINTER_ROLE, minter);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        // This blocks transfer, transferFrom, burn and burnFrom calls from and
        // to blacklisted addresses
        require(!blacklist[from], "From address is blacklisted");
        require(!blacklist[to], "To address is blacklisted");

        super._beforeTokenTransfer(from, to, amount);
    }

    /// @notice Mints tokens to an address
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    /// @dev Requires MINTER_ROLE
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // Pausable logic

    /// @notice Pauses the contract
    /// @dev This halts all transfer functionality, until resume() is called
    /// @dev Requires DEFAULT_ADMIN_ROLE
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        _pause();
    }

    /// @notice Resumes the contract
    /// @dev This resumes all transfer functionality 
    /// @dev Requires DEFAULT_ADMIN_ROLE
    function resume() external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        _unpause();
    }

    // Default admin transfer logic

    /// @notice Initiates a request to transfer DEFAULT_ADMIN_ROLE
    /// @param newAdmin New admin
    /// @dev This won't be used unless one of the default admins is compromised
    function transferDefaultAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAdmin != address(0x0), "New admin cannot be 0x0");
        require(newAdmin != _assignedDefaultAdmin, "New admin cannot be the same as the old one");

        _assignedDefaultAdmin = newAdmin;
        emit DefaultAdminTransferStarted(msg.sender, newAdmin);
    }

    /// @notice Cancels a request to transfer DEFAULT_ADMIN_ROLE
    function cancelDefaultAdminTransfer() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _assignedDefaultAdmin = address(0x0);
    }

    /// @notice Claims DEFAULT_ADMIN_ROLE
    /// @dev If user doesn't claim the role, default admin doesn't change
    function claimDefaultAdmin() external {
        require(msg.sender == _assignedDefaultAdmin, "You are not assigned to be the new default admin");

        _grantRole(DEFAULT_ADMIN_ROLE, _assignedDefaultAdmin);
        _revokeRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);

        emit DefaultAdminTransferred(_defaultAdmin, _assignedDefaultAdmin);

        _assignedDefaultAdmin = address(0x0);
        _defaultAdmin = msg.sender;
    }
}
