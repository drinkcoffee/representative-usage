// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

contract Globals is Script {
    string public path = "./temp/addresses-and-keys.txt";

    // Distributor of native token.
    address public root;
    uint256 public rootPKey;

    // Deployer of all contracts
    address public deployer;
    uint256 public deployerPKey;

    // Have one admin account for everything: In the real deployment these are multisigs, with different
    // multisigs used for different adminstration groups.
    address public admin;
    uint256 public adminPKey;




    // ***************************************************
    // Code below manages accounts
    // ***************************************************
    uint256 public constant NUM_PLAYERS = 1000; // Number of players with some value
    uint256 public currentPlayer;
    address[] players;
    uint256 public poor; // Index for creating EOAs that don't have any native tokens.

    function distributeNativeTokenToGamePlayers() internal {
        vm.startBroadcast(rootPKey);

        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            bytes memory userStr = abi.encodePacked("player", i);
            address user = makeAddr(string(userStr));
            players.push(user);
            payable(user).transfer(0.00001 ether);
        }
        vm.stopBroadcast();
    }


    function getEOAWithNativeTokens() internal returns(address) {
        currentPlayer = (currentPlayer + 1) % NUM_PLAYERS;
        return players[currentPlayer];
    }

    function getEOAWithNoNativeTokens() internal returns(address) {
        bytes memory userStr = abi.encodePacked("poorplayer", poor++);
        return makeAddr(string(userStr));
    }

}
