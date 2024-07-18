// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

contract Globals is Script {
    string public constant RUN_NAME = "0";


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
    uint256 public constant NUM_PLAYERS = 100; // Number of players with some value
    uint256 public currentPlayer;
    address[] players;
    uint256[] playersPKeys;
    uint256 public poor; // Index for creating EOAs that don't have any native tokens.

    function distributeNativeTokenToGamePlayers() internal {

        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            bytes memory userStr = abi.encodePacked("player", i);
            (address user, uint256 userPKey) = makeAddrAndKey(string(userStr));
            players.push(user);
            playersPKeys.push(userPKey);
            vm.startBroadcast(rootPKey);
            payable(user).transfer(0.001 ether);
            vm.stopBroadcast();
        }
    }


    function getEOAWithNativeTokens() internal returns(address, uint256) {
        currentPlayer = (currentPlayer + 1) % NUM_PLAYERS;
        return (players[currentPlayer], playersPKeys[currentPlayer]);
    }

    function getEOAWithNoNativeTokens() internal returns(address) {
        bytes memory userStr = abi.encodePacked("poorplayer", poor++);
        return makeAddr(string(userStr));
    }

}
