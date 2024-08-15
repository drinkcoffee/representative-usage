// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

// Open Zeppelin contracts
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Globals is Script {
    string public RUN_NAME = "0";
    string public treasuryAddress;

    string public path = "./temp/addresses-and-keys.txt";

    // Distributor of native token.
    // Account only used during set-up
    address public root;
    uint256 public rootPKey;

    // Deployer of all contracts
    // Account only used during set-up
    address public deployer;
    uint256 public deployerPKey;

    // Have one admin account for everything: In the real deployment these are multisigs, with different
    // multisigs used for different adminstration groups.
    // Account only used during set-up
    address public admin;
    uint256 public adminPKey;

    // Address from which all EOA value transfers are sent.
    // Account only used during run time testing
    address public fountain;
    uint256 public fountainPKey;

    int256 public PASSPORT_GEM_NEW_PASSPORT = 0;
    int256 public PASSPORT_GEM_GAME = 0;
    int256 public PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME = 0;
    int256 public PASSPORT_HUNTERS_ON_CHAIN_RECIPE = 0;
    int256 public PASSPORT_HUNTERS_ON_CHAIN_BITGEM = 0;
    int256 public PASSPORT_GUILD_OF_GUARDIANS_CLAIM = 0;
    int256 public PASSPORT_SPACETREK_CLAIM = 0;
    int256 public PASSPORT_SPACENATION_COIN = 0;
    int256 public EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM = 0;
    int256 public EOA_HUNTERS_ON_CHAIN_RELAYER_MINT = 0;
    int256 public EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT = 0;
    int256 public EOA_GEM_GAME = 0;
    int256 public EOA_VALUE_TRANSFER = 0;
    int256 public EOA_BABY_SHARK_UNIVERSE_PROXY = 0;
    int256 public EOA_BABY_SHARK_UNIVERSE = 0;
    int256 public EOA_BLACKPASS = 0;
    int256 public HUNTERS_ON_CHAIN = 0;

    // ***************************************************
    // Code below manages accounts
    // ***************************************************
    uint256 public constant NUM_PLAYERS = 10; // Number of players with some value
    uint256 public currentPlayer;
    address[] players;
    uint256[] playersPKeys;
    uint256 public poor; // Index for creating EOAs that don't have any native tokens.

    function distributeNativeTokenToGamePlayers(
        string memory _runName
    ) internal {
        vm.writeLine(path, "Distributing value to user EOAs:");
        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            bytes memory userStr = abi.encodePacked(
                "player",
                _runName,
                treasuryAddress,
                i
            );
            (address user, uint256 userPKey) = makeAddrAndKey(string(userStr));
            players.push(user);
            vm.writeLine(path, Strings.toHexString(user));
            playersPKeys.push(userPKey);
            vm.startBroadcast(rootPKey);
            payable(user).transfer(0.1 ether);
            vm.stopBroadcast();
        }
    }

    function loadUserEOAs(string memory _runName) internal {
        vm.readLine(path); // Discard line:Distributing value to user EOAs:
        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            bytes memory userStr = abi.encodePacked(
                "player",
                _runName,
                treasuryAddress,
                i
            );
            (address user, uint256 userPKey) = makeAddrAndKey(string(userStr));
            players.push(user);
            vm.readLine(path); // Discard line: <user address>
            playersPKeys.push(userPKey);
        }
    }

    function getEOAWithNativeTokens() internal returns (address, uint256) {
        currentPlayer = (currentPlayer + 1) % NUM_PLAYERS;
        return (players[currentPlayer], playersPKeys[currentPlayer]);
    }

    function getEOAWithNoNativeTokens() internal returns (address) {
        bytes memory userStr = abi.encodePacked("poorplayer", poor++);
        return makeAddr(string(userStr));
    }

    function loadEnvironment() internal {
        // Load the environment
        RUN_NAME = vm.envString("RUN_NAME");
        PASSPORT_GEM_NEW_PASSPORT = vm.envInt("PASSPORT_GEM_NEW_PASSPORT");
        PASSPORT_GEM_GAME = vm.envInt("PASSPORT_GEM_GAME");
        PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME = vm.envInt(
            "PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME"
        );
        PASSPORT_HUNTERS_ON_CHAIN_RECIPE = vm.envInt(
            "PASSPORT_HUNTERS_ON_CHAIN_RECIPE"
        );
        PASSPORT_HUNTERS_ON_CHAIN_BITGEM = vm.envInt(
            "PASSPORT_HUNTERS_ON_CHAIN_BITGEM"
        );
        PASSPORT_GUILD_OF_GUARDIANS_CLAIM = vm.envInt(
            "PASSPORT_GUILD_OF_GUARDIANS_CLAIM"
        );
        PASSPORT_SPACETREK_CLAIM = vm.envInt("PASSPORT_SPACETREK_CLAIM");
        PASSPORT_SPACENATION_COIN = vm.envInt("PASSPORT_SPACENATION_COIN");
        EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM = vm.envInt(
            "EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM"
        );
        EOA_HUNTERS_ON_CHAIN_RELAYER_MINT = vm.envInt(
            "EOA_HUNTERS_ON_CHAIN_RELAYER_MINT"
        );
        EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT = vm.envInt(
            "EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT"
        );
        EOA_GEM_GAME = vm.envInt("EOA_GEM_GAME");
        EOA_VALUE_TRANSFER = vm.envInt("EOA_VALUE_TRANSFER");
        EOA_BABY_SHARK_UNIVERSE_PROXY = vm.envInt(
            "EOA_BABY_SHARK_UNIVERSE_PROXY"
        );
        EOA_BABY_SHARK_UNIVERSE = vm.envInt("EOA_BABY_SHARK_UNIVERSE");
        EOA_BLACKPASS = vm.envInt("EOA_BLACKPASS");
        HUNTERS_ON_CHAIN = vm.envInt("HUNTERS_ON_CHAIN");
    }
}
