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

contract RunCustom is RunBase {
    uint256 _treasuryPKey = vm.envUint("ACCOUNT_PVT_KEY");

    function run(string memory _executionType) public {
        require(bytes(_executionType).length != 0, "Specify execution type as a parameter");

        loadEnvironment();
        treasuryPKey = _treasuryPKey;
        treasuryAddress = Strings.toHexString(
            uint160(vm.addr(_treasuryPKey)),
            20
        );
        path = string(
            abi.encodePacked(
                "./temp/addresses-and-keys-",
                treasuryAddress,
                "-",
                RUN_NAME,
                ".txt"
            )
        );
        loadAddressNonces();
        loadPassportPlayerMagicFromFile();

        if (Strings.equal(_executionType, "check-treasury")) {
            console.logString("Checking Treasury Account");
            address treasury = vm.addr(_treasuryPKey);
            console.log("Treasury (%s) balance: %i", treasuryAddress, treasury.balance);
        }
        else if (Strings.equal(_executionType, "deploy")) {
            console.logString("Deploying contracts");
            deployAll();
        } 
        else if (Strings.equal(_executionType, "check-deploy")) {
            _loadAddresses();
            console.logString("Checking contracts deploy and accounts funded for execution");
            console.log("Relayer (%s) balance: %i, nonce: %i", relayer, relayer.balance, vm.getNonce(relayer));
        } 
        else if (Strings.equal(_executionType, "execute")) {
            console.logString("Executing transactions");
            executeAll();
        } 
        else if (Strings.equal(_executionType, "deploy-execute")) {
            deployAll();
            insertMarkerTransaction();
            executeAll();
        }
        else if (Strings.equal(_executionType, "fund-admin")) {
            // TODO remove this as there should be no scenario in which this needs to be done.
            console.logString("Funding Admin");
            vm.broadcast(treasuryPKey);
            payable(admin).transfer(1000 ether);

        }
        else {
            console.log("Unknown execution type: %s", _executionType);
        }

        saveAddressNonces();
        savePassportPlayerMagicToFile();
    }


    function _loadAddresses() internal {
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
    }


    function insertMarkerTransaction() private {
        console.logString("Insert into sendRawTransaction log file an easily findable transaction");
        address zero = address(0);
        vm.broadcast(treasuryPKey);
        payable(zero).transfer(0 ether);
    }


    function executeAll() internal {
        if (!vm.isFile(path)) {
            console.logString("ERROR: No addresses-and-keys file found");
            return;
        }
        _loadAddresses();

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
