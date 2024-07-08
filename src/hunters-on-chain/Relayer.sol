// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Relayer
/// @notice Contract for Hunters On Chain relayer
contract Relayer is Ownable {
    event Funded(uint256 amount);
    event Response(bool success, bytes data);  

    mapping(address => bool) public whitelist;
    address[] private whitelistedWallets;

    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
    }

    constructor(address[] memory _whitelisted) {
        whitelistedWallets = _whitelisted;
        for (uint i = 0; i < _whitelisted.length; i++) {
            whitelist[_whitelisted[i]] = true;
        }
    }

    function setWhitelist(address[] calldata addresses) 
        external onlyOwner {
        for (uint i = 0; i < whitelistedWallets.length; i++) {
            delete whitelist[whitelistedWallets[i]];
        }

        for (uint i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
        }

        whitelistedWallets = addresses;
    }


    function withdraw(uint amount) external onlyOwner {
        payable(msg.sender).transfer(amount);
    }

    function fund() external onlyOwner {
        uint256 balance = address(this).balance;    
        require(balance > whitelistedWallets.length, "Balance too low");

        uint256 transferAmount = balance / whitelistedWallets.length;

        for (uint256 i = 0; i < whitelistedWallets.length; i++) {
            payable(whitelistedWallets[i]).transfer(transferAmount);
        }

        emit Funded(transferAmount);
    }

    function execute(ForwardRequest[] calldata req) external {
        require(whitelist[msg.sender], "Not whitelisted");

        for (uint256 i = 0; i < req.length; i++) {
            (bool success, bytes memory returndata) = req[i].to.call{gas: req[i].gas, value: req[i].value}(
                abi.encodePacked(req[i].data, req[i].from)
            );
            
            emit Response(success, returndata);
        }
    }
}
