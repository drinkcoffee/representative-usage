// Code from: https://explorer.immutable.com/address/0x99099c183c6C2Ff4bbe3D2eD500aFeB7B037944C?tab=contract
// Bytecode was put through an online decompiler (https://ethervm.io/decompile), 
// plus there has been some guess work. 

// SPDX-License-Identifier: MIT
// solhint-disable not-rely-on-time

pragma solidity ^0.8;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

    error Unauthorized();
    error ContractPaused();

/**
 * @title ClaimGame - A simple contract that creates an on-chain transaction for a pausable claim
 * @author Immutable
 * @dev The ClaimGame contract is not designed to be upgradeable or extended
 */
contract HuntersOnChainClaimGame is AccessControl, Pausable {
    /// @notice Indicates that an account has earned a gem
    event Claim(address indexed account, uint256 timestamp);

    /// @notice Role to allow pausing the contract
    bytes32 private constant _PAUSE = keccak256("PAUSE");

    /// @notice Role to allow unpausing the contract
    bytes32 private constant _UNPAUSE = keccak256("UNPAUSE");

    /**
     *   @notice Sets the DEFAULT_ADMIN, PAUSE and UNPAUSE roles
     *   @param _admin The address for the admin role
     *   @param _pauser The address for the pauser role
     *   @param _unpauser The address for the unpauser role
     */
    constructor(address _admin, address _pauser, address _unpauser) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(_PAUSE, _pauser);
        _grantRole(_UNPAUSE, _unpauser);
    }

    /**
     *   @notice Pauses the contract
     */
    function pause() external {
        if (!hasRole(_PAUSE, msg.sender)) revert Unauthorized();
        _pause();
    }

    /**
     *   @notice Unpauses the contract
     */
    function unpause() external {
        if (!hasRole(_UNPAUSE, msg.sender)) revert Unauthorized();
        _unpause();
    }

    /**
    *    @notice Claim function
    */
    function claim() external {
        if (paused()) revert ContractPaused();
        emit Claim(msg.sender, block.timestamp);
    }
}
