// Code from: https://explorer.immutable.com/address/0xdf23776FA6ea2a328AD2A5d6cae609b62187d7Aa?tab=contract

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @author gfialho
/// @title Fund contract
contract Fund is Ownable {
    ////////////////////////////////////////////////////////////////////////////
    // Constructor
    ////////////////////////////////////////////////////////////////////////////
    constructor(address _owner) Ownable() {
        // NOTE: made small change to make compatible with Open Zeppelin v4.x
        _transferOwnership(_owner);
    }

    function fund(address payable[] calldata _wallets, uint256[] calldata _balances) external payable onlyOwner {
        require(_wallets.length == _balances.length, "Array lengths do not match.");

        uint256 total = msg.value;
        for (uint256 i = 0; i < _wallets.length; i++) {
            require(total >= _balances[i], "Insufficient balance.");
            total -= _balances[i];
            (bool sent, bytes memory data) = _wallets[i].call{value: _balances[i]}("");
            require(sent, "Failed to send Ether");
        }
    }

    function withdraw(address payable wallet) external payable onlyOwner {
        (bool sent, bytes memory data) = wallet.call{value: address(this).balance}("");
    }
}
