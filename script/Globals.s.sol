// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

// Open Zeppelin contracts
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Globals is Script {
    string public RUN_NAME = "0";

    // Holds funds to be distributed to all other accounts
    uint256 public TREASURY_PKEY;

    string public path;

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

    int256 public PASSPORT_GEM_NEW_PASSPORT = 2;
    int256 public PASSPORT_GEM_GAME = 2;
    int256 public PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME = 1;
    int256 public PASSPORT_HUNTERS_ON_CHAIN_RECIPE = 1;
    int256 public PASSPORT_HUNTERS_ON_CHAIN_BITGEM = 1;
    int256 public PASSPORT_GUILD_OF_GUARDIANS_CLAIM = 1;
    int256 public PASSPORT_SPACETREK_CLAIM = 1;
    int256 public PASSPORT_SPACENATION_COIN = 1;
    int256 public EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM = 3;
    int256 public EOA_HUNTERS_ON_CHAIN_RELAYER_MINT = 1;
    int256 public EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT = 2;
    int256 public EOA_GEM_GAME = 3;
    int256 public EOA_VALUE_TRANSFER = 5;
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


    function setupGlobalAccounts() internal {
        vm.writeLine(path, "Run Name");
        vm.writeLine(path, RUN_NAME);
        console.logString(string(abi.encodePacked("Run Name: ", RUN_NAME)));

        address treasury = vm.addr(TREASURY_PKEY);
        vm.label(treasury, "treasury");
        if (treasury.balance == 0) {
            console.logString("ERROR: Treasury has 0 native gas token");
            revert("Treasury has 0 native gas token");
        }

        (root, rootPKey) = makeAddrAndKey(
            string(abi.encodePacked(RUN_NAME, "root"))
        );
        vm.writeLine(path, "Root Address");
        vm.writeLine(path, Strings.toHexString(root));
        vm.writeLine(path, "Root PKey");
        vm.writeLine(path, Strings.toHexString(rootPKey));
        vm.startBroadcast(TREASURY_PKEY);
        payable(root).transfer(31 ether);
        if (root.balance == 0) {
            console.logString("ERROR: Root has 0 native gas token");
            revert("Root has 0 native gas token");
        }
        vm.stopBroadcast();

        (deployer, deployerPKey) = makeAddrAndKey(
            string(abi.encodePacked(RUN_NAME, "deployer"))
        );
        vm.writeLine(path, "Deployer Address");
        vm.writeLine(path, Strings.toHexString(deployer));
        vm.writeLine(path, "Deployer PKey");
        vm.writeLine(path, Strings.toHexString(deployerPKey));
        vm.startBroadcast(rootPKey);
        payable(deployer).transfer(2 ether);
        if (deployer.balance == 0) {
            console.logString("ERROR: Deployer has 0 native gas token");
            revert("Deployer has 0 native gas token");
        }
        vm.stopBroadcast();

        (admin, adminPKey) = makeAddrAndKey(
            string(abi.encodePacked(RUN_NAME, "admin"))
        );
        vm.writeLine(path, "Admin Address");
        vm.writeLine(path, Strings.toHexString(admin));
        vm.writeLine(path, "Admin PKey");
        vm.writeLine(path, Strings.toHexString(adminPKey));
        vm.startBroadcast(rootPKey);
        payable(admin).transfer(2 ether);
        if (admin.balance == 0) {
            console.logString("ERROR: Admin has 0 native gas token");
            revert("Admin has 0 native gas token");
        }
        vm.stopBroadcast();

        (fountain, fountainPKey) = makeAddrAndKey(
            string(abi.encodePacked(RUN_NAME, "fountain"))
        );
        vm.writeLine(path, "Fountain Address");
        vm.writeLine(path, Strings.toHexString(fountain));
        vm.writeLine(path, "Fountain PKey");
        vm.writeLine(path, Strings.toHexString(fountainPKey));
        vm.startBroadcast(rootPKey);
        payable(fountain).transfer(2 ether);
        if (fountain.balance == 0) {
            console.logString("ERROR: Fountain has 0 native gas token");
            revert("Fountain has 0 native gas token");
        }
        vm.stopBroadcast();
    }



    function distributeNativeTokenToGamePlayers() internal {
        vm.writeLine(path, "Distributing value to user EOAs:");
        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            bytes memory userStr = abi.encodePacked(
                "player",
                RUN_NAME,
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

    function loadUserEOAs() internal {
        vm.readLine(path); // Discard line:Distributing value to user EOAs:
        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            bytes memory userStr = abi.encodePacked(
                "player",
                RUN_NAME,
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
        TREASURY_PKEY = vm.envUint("ACCOUNT_PVT_KEY");
        RUN_NAME = vm.envString("RUN_NAME");

        path = string(
            abi.encodePacked(
                "./temp/addresses-and-keys-",
                RUN_NAME,
                ".txt"
            )
        );
    }
}
