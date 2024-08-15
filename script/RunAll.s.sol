// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

import {RunBase} from "./RunBase.s.sol";

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

//contract RunAll is Applications {
contract RunAll is RunBase {
    function run() public override {
        // Anvil is resetting between deploy and run all, so deploy before run.
        deployAll();

        // Have this different for each run.
        string memory runName = RUN_NAME;
        console.logString("Start *********************************");
        console.logString(
            string(
                abi.encodePacked(
                    "Loading deployment address information from: ",
                    path
                )
            )
        );

        vm.readLine(path); // Discard line: Execution Start *********************************
        vm.readLine(path); // Discard line: Run Name
        vm.readLine(path); // Discard line: the run name

        loadAccounts(runName);
        loadUserEOAs(runName);

        loadCreate3Deployer();
        loadPassportWalletContracts();
        loadSeaport();
        loadGemGame();
        // Applications don't directly interact with Royalty Allowlist at run time, so nothing to load.
        loadHuntersOnChain();
        loadGuildOfGuardians();

        runAll();
    }


    // Percentages to two decimal places of chain utilisation on Sunday July 14, 2024
    // NOTE that the numbers are not consistent: the Passport numbers appear to be slightly inflated.
    uint256 public constant P_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT = 83;
    uint256 public constant P_PASSPORT_GEM_GAME =
        2627 - P_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT;
    uint256 public constant P_PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME = 305;
    uint256 public constant P_PASSPORT_HUNTERS_ON_CHAIN_RECIPE = 257;
    uint256 public constant P_PASSPORT_HUNTERS_ON_CHAIN_BITGEM = 115;
    uint256 public constant P_PASSPORT_GUILD_OF_GUARDIANS_CLAIM = 462;
    uint256 public constant P_PASSPORT_SPACETREK_CLAIM = 92;
    uint256 public constant P_PASSPORT_SPACENATION_COIN = 26;
    uint256 public constant P_PASSPORT_SEAPORT = 38;

    uint256 public constant P_EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM = 1961;
    uint256 public constant P_EOA_HUNTERS_ON_CHAIN_RELAYER_MINT = 1000; // Adds to 19.27, not sure of distribution
    uint256 public constant P_EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT = 927; // Adds to 19.27, not sure of distribution
    uint256 public constant P_EOA_GEM_GAME = 1247;
    uint256 public constant P_EOA_VALUE_TRANSFER = 1115;
    uint256 public constant P_EOA_BABY_SHARK_UNIVERSE_PROXY = 213;
    uint256 public constant P_EOA_BABY_SHARK_UNIVERSE = 44;
    uint256 public constant P_EOA_BLACKPASS = 33;

    // Once each hour, Hunters on Chain submits about a dozen big (20M gas) transactions
    // in sequential blocks. Given a number range of 100,000, and a weighting of two,
    // each 50,000 runs through the loop below will call the sequence of fund calls.
    uint256 public constant P_EOA_HUNTERS_ON_CHAIN_FUND = 2;

    uint256 public constant T_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT =
        P_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT;
    uint256 public constant T_PASSPORT_GEM_GAME =
        T_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT + P_PASSPORT_GEM_GAME;
    uint256 public constant T_PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME =
        T_PASSPORT_GEM_GAME + P_PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME;
    uint256 public constant T_PASSPORT_HUNTERS_ON_CHAIN_RECIPE =
        T_PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME +
            P_PASSPORT_HUNTERS_ON_CHAIN_RECIPE;
    uint256 public constant T_PASSPORT_HUNTERS_ON_CHAIN_BITGEM =
        T_PASSPORT_HUNTERS_ON_CHAIN_RECIPE + P_PASSPORT_HUNTERS_ON_CHAIN_BITGEM;
    uint256 public constant T_PASSPORT_GUILD_OF_GUARDIANS_CLAIM =
        T_PASSPORT_HUNTERS_ON_CHAIN_BITGEM +
            P_PASSPORT_GUILD_OF_GUARDIANS_CLAIM;
    uint256 public constant T_PASSPORT_SPACETREK_CLAIM =
        T_PASSPORT_GUILD_OF_GUARDIANS_CLAIM + P_PASSPORT_SPACETREK_CLAIM;
    uint256 public constant T_PASSPORT_SPACENATION_COIN =
        T_PASSPORT_SPACETREK_CLAIM + P_PASSPORT_SPACENATION_COIN;
    uint256 public constant T_PASSPORT_SEAPORT =
        T_PASSPORT_SPACENATION_COIN + P_PASSPORT_SEAPORT;
    uint256 public constant T_EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM =
        T_PASSPORT_SEAPORT + P_EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM;
    uint256 public constant T_EOA_HUNTERS_ON_CHAIN_RELAYER_MINT =
        T_EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM + P_EOA_HUNTERS_ON_CHAIN_RELAYER_MINT;
    uint256 public constant T_EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT =
        T_EOA_HUNTERS_ON_CHAIN_RELAYER_MINT +
            P_EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT;
    uint256 public constant T_EOA_GEM_GAME =
        T_EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT + P_EOA_GEM_GAME;
    uint256 public constant T_EOA_VALUE_TRANSFER =
        T_EOA_GEM_GAME + P_EOA_VALUE_TRANSFER;
    uint256 public constant T_EOA_BABY_SHARK_UNIVERSE_PROXY =
        T_EOA_VALUE_TRANSFER + P_EOA_BABY_SHARK_UNIVERSE_PROXY;
    uint256 public constant T_EOA_BABY_SHARK_UNIVERSE =
        T_EOA_BABY_SHARK_UNIVERSE_PROXY + P_EOA_BABY_SHARK_UNIVERSE;
    uint256 public constant T_EOA_BLACKPASS =
        T_EOA_BABY_SHARK_UNIVERSE + P_EOA_BLACKPASS;
    uint256 public constant T_EOA_HUNTERS_ON_CHAIN_FUND =
        T_EOA_BLACKPASS + P_EOA_HUNTERS_ON_CHAIN_FUND;
    uint256 public constant TOTAL = T_EOA_HUNTERS_ON_CHAIN_FUND;

    function runAll() public {
        // Uncomment the code below to check that the numbers are all increasing.
        console.logUint(T_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT);
        console.logUint(T_PASSPORT_GEM_GAME);
        console.logUint(T_PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME);
        console.logUint(T_PASSPORT_HUNTERS_ON_CHAIN_RECIPE);
        console.logUint(T_PASSPORT_HUNTERS_ON_CHAIN_BITGEM);
        console.logUint(T_PASSPORT_GUILD_OF_GUARDIANS_CLAIM);
        console.logUint(T_PASSPORT_SPACETREK_CLAIM);
        console.logUint(T_PASSPORT_SPACENATION_COIN);
        console.logUint(T_PASSPORT_SEAPORT);
        console.logUint(T_EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM);
        console.logUint(T_EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT);
        console.logUint(T_EOA_GEM_GAME);
        console.logUint(T_EOA_VALUE_TRANSFER);
        console.logUint(T_EOA_BABY_SHARK_UNIVERSE_PROXY);
        console.logUint(T_EOA_BABY_SHARK_UNIVERSE);
        console.logUint(T_EOA_BLACKPASS);
        console.logUint(T_EOA_HUNTERS_ON_CHAIN_FUND);

        // Call everything once, just to make sure it doesn't blow up.
        // callGemGameFromUsersPassport(true);
        // callGemGameFromUsersPassport(false);
        // callHuntersOnChainClaimGamePassport(false);
        // callHuntersOnChainRecipeOpenChestPassport(false);
        // callHuntersOnChainBGemClaimPassport(false);
        // callGuildOfGuardiansClaimGamePassport(false);
        // callHuntersOnChainBGemClaimEOA();
        // callHuntersOnChainBGemMintERC20(false);
        // callShardsERC1155SafeMintBatch(false);
        // callGemGameFromUserEOA();
        // callValueTransferEOAtoEOA();
        // callHuntersOnChainFund();


        // // Create some initial passport wallets.
        // for (uint256 j=0; j < 10; j++) {
        //     getNewPassportMagic();
        // }

       // If the system loops around about 79346 times, it runs out of EVM memory space.
       for (uint256 i = 0; i < 1; i++) {
            uint256 drbg = getNextDrbgOutput();
            if (true){
                callValueTransferEOAtoEOA();
            }
            else if (drbg < T_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT) {
                callGemGameFromUsersPassport(true);
            } else if (drbg < T_PASSPORT_GEM_GAME) {
                callGemGameFromUsersPassport(false);
            } else if (drbg < T_PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME) {
                callHuntersOnChainClaimGamePassport(false);
            } else if (drbg < T_PASSPORT_HUNTERS_ON_CHAIN_RECIPE) {
                callHuntersOnChainRecipeOpenChestPassport(false);
            } else if (drbg < T_PASSPORT_HUNTERS_ON_CHAIN_BITGEM) {
                callHuntersOnChainBGemClaimPassport(false);
            } else if (drbg < T_PASSPORT_GUILD_OF_GUARDIANS_CLAIM) {
                callGuildOfGuardiansClaimGamePassport(false);
            } else if (drbg < T_PASSPORT_SPACETREK_CLAIM) {
                console.log("TODO");
            } else if (drbg < T_PASSPORT_SPACENATION_COIN) {
                console.log("TODO");
            } else if (drbg < T_PASSPORT_SEAPORT) {
                console.log("TODO");
            } else if (drbg < T_EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM) {
                callHuntersOnChainBGemClaimEOA();
            } else if (drbg < T_EOA_HUNTERS_ON_CHAIN_RELAYER_MINT) {
                callHuntersOnChainBGemMintERC20(false);
            } else if (drbg < T_EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT) {
                callShardsERC1155SafeMintBatch(false);
            } else if (drbg < T_EOA_GEM_GAME) {
                callGemGameFromUserEOA();
            } else if (drbg < T_EOA_VALUE_TRANSFER) {
                callValueTransferEOAtoEOA();
            } else if (drbg < T_EOA_BABY_SHARK_UNIVERSE_PROXY) {
                console.log("TODO: EOA_BABY_SHARK_UNIVERSE_PROXY");
            } else if (drbg < T_EOA_BABY_SHARK_UNIVERSE) {
                console.log("TODO: EOA_BABY_SHARK_UNIVERSE");
            } else if (drbg < T_EOA_BLACKPASS) {
                console.log("TODO: EOA_BLACKPASS");
            } else if (drbg < T_EOA_HUNTERS_ON_CHAIN_FUND) {
                // NOTE: This sends multiple transactions all in one go.
                callHuntersOnChainFund();
            }
        }
    }

    function getNextDrbgOutput() internal returns (uint256) {
        uint256 output = getNextDrbgOutputUnfiltered() % TOTAL;
        console.log("DRBG output: %i, %i", output, drbgCounter);
        return output;
    }
}
