// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

import {Applications} from "./Applications.s.sol";

// Open Zeppelin contracts
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
// Slightly hacked Open Zeppelin contracts
import {EIP712WithChanges} from "./EIP712WithChanges.sol";

// Immutable Contracts repo
import {ImmutableERC20MinterBurnerPermit} from "../src/im-contracts/token/erc20/preset/ImmutableERC20MinterBurnerPermit.sol";
import {ImmutableERC1155} from "../src/im-contracts/token/erc1155/preset/ImmutableERC1155.sol";

// Gem Game
import {GemGame} from "../src/im-contracts/games/gems/GemGame.sol";

// Hunters on Chain
import {Relayer} from "../src/hunters-on-chain/Relayer.sol";
import {Shards} from "../src/hunters-on-chain/Shards.sol";
import {BgemClaim, IBgem} from "../src/hunters-on-chain/Claim.sol";
import {HuntersOnChainClaimGame} from "../src/hunters-on-chain/HuntersOnChainClaimGame.sol";
import {Equipments} from "../src/hunters-on-chain/Equipments.sol";
import {Artifacts} from "../src/hunters-on-chain/Artifacts.sol";
import {Recipe} from "../src/hunters-on-chain/Recipe.sol";
import {Fund} from "../src/hunters-on-chain/Fund.sol";

// Guild of Guardians
import {GuildOfGuardiansClaimGame} from "../src/guild-of-guardians/GuildOfGuardiansClaimGame.sol";

contract RunCustom is Applications {
    function run(string memory _executionType) public {
        require(bytes(_executionType).length != 0, "Specify execution type as a parameter");

        loadEnvironment();

        if (Strings.equal(_executionType, "check-treasury")) {
            console.logString("Checking Treasury Account");
            address treasury = vm.addr(TREASURY_PKEY);
            console.log("Treasury (%s) balance: %i", treasury, treasury.balance);
        }
        else if (Strings.equal(_executionType, "deploy")) {
            console.logString("Deploying contracts");
            deployAll();
            insertMarkerTransaction();
        } 
        else if (Strings.equal(_executionType, "check-deploy")) {
            console.logString("Checking contracts deploy and accounts funded for execution");
            console.log("Relayer (%s) balance: %i, nonce: %i", relayer, relayer.balance, vm.getNonce(relayer));
        } 
        else if (Strings.equal(_executionType, "deploy-execute")) {
            deployAll();
            insertMarkerTransaction();
            executeAll();
        }
        else {
            console.log("Unknown execution type: %s", _executionType);
        }
    }


    function deployAll() private {
        if (vm.exists(path)) {
            vm.removeFile(path);
        }
        vm.writeLine(path, ("Execution Start *********************************"));
        console.logString(string(abi.encodePacked(
                    "Deployment address Information logged to: ",
                    path
                )
            )
        );

        setupGlobalAccounts();
        setupPassportAccounts();
        setupApplicationAccounts();

        distributeNativeTokenToGamePlayers();

        installCreate3Deployer();
        installPassportWallet();
        installSeaport();
        installGemGame();
        installRoyaltyAllowlist(); // Must be installed after Passport.
        installHuntersOnChain();
        installGuildOfGuardians();

        vm.closeFile(path);
    }


    function insertMarkerTransaction() private {
        console.logString("Insert into sendRawTransaction log file an easily findable transaction");
        address zero = address(0);
        vm.broadcast(TREASURY_PKEY);
        payable(zero).transfer(0 ether);
    }


    function executeAll() internal {
        for (uint256 j = 0; j < 100; j++) {
            for (int i = 0; i < PASSPORT_GEM_NEW_PASSPORT; i++) {
                callGemGameFromUsersPassport(true);
            }

            for (int i = 0; i < PASSPORT_GEM_GAME; i++) {
                callGemGameFromUsersPassport(false);
            }

            for (int i = 0; i < PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME; i++) {
                callHuntersOnChainClaimGamePassport(false);
            }

            for (int i = 0; i < PASSPORT_HUNTERS_ON_CHAIN_RECIPE; i++) {
                callHuntersOnChainRecipeOpenChestPassport(false);
            }

            for (int i = 0; i < PASSPORT_HUNTERS_ON_CHAIN_BITGEM; i++) {
                callHuntersOnChainBGemClaimPassport(false);
            }

            for (int i = 0; i < PASSPORT_GUILD_OF_GUARDIANS_CLAIM; i++) {
                callGuildOfGuardiansClaimGamePassport(false);
            }
            // skipping PASSPORT_SPACETREK_CLAIM , PASSPORT_SPACENATION_COIN

            for (int i = 0; i < EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM; i++) {
                callHuntersOnChainBGemClaimEOA();
            }

            for (int i = 0; i < EOA_HUNTERS_ON_CHAIN_RELAYER_MINT; i++) {
                callHuntersOnChainBGemMintERC20(false);
            }

            for (int i = 0; i < EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT; i++) {
                callShardsERC1155SafeMintBatch(false);
            }

            for (int i = 0; i < EOA_GEM_GAME; i++) {
                callGemGameFromUserEOA();
            }

            for (int i = 0; i < EOA_VALUE_TRANSFER; i++) {
                callValueTransferEOAtoEOA();
            }

            // skipping EOA_BABY_SHARK_UNIVERSE_PROXY, EOA_BABY_SHARK_UNIVERSE, EOA_BLACKPASS

            for (int i = 0; i < HUNTERS_ON_CHAIN; i++) {
                callHuntersOnChainFund();
            }
        }
    }
}
