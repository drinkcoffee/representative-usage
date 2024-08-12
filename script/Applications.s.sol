// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

import {ChainInfrastructure} from "./ChainInfrastructure.s.sol";

// Open Zeppelin contracts
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
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

contract Applications is ChainInfrastructure {
    // Gem game
    GemGame public gemGame;

    // ERC20
    ImmutableERC20MinterBurnerPermit public erc20;
    address public minter;
    string name;
    string symbol;
    uint256 maxSupply;
    // Always transfer the same amount
    uint256 public constant AMOUNT = 1;

    // Hunters on Chain
    ImmutableERC20MinterBurnerPermit public bgemErc20;
    address huntersOnChainMinter;
    uint256 huntersOnChainMinterPKey;
    Relayer huntersOnChainRelayer;
    // Deployed to: https://explorer.immutable.com/address/0x5E850613Cb4b3010C166A79b2E0d5f6fAE265230
    Shards huntersOnChainShards;
    address huntersOnChainOffchainSigner; // Used to verify off-chain signing requests for claiming BGems
    uint256 huntersOnChainOffchainSignerPKey; // Used to sign off-chain signing requests for claiming BGems
    BgemClaim huntersOnChainClaim;
    mapping(address => uint256) bgemClaimNonces;
    EIP712WithChanges huntersOnChainEIP712;
    HuntersOnChainClaimGame huntersOnChainClaimGame;
    Equipments huntersOnChainEquipments;
    Artifacts huntersOnChainArtifacts;
    Recipe huntersOnChainRecipe;
    uint256 public constant HUNTERS_ON_CHAIN_CHEST1 = 1;
    uint256 public constant HUNTERS_ON_CHAIN_COST = 1000 gwei;
    Fund huntersOnChainFund;
    uint256 public constant HUNTERS_ON_CHAIN_NEW_USERS_PER_TX = 500;
    uint256 public constant HUNTERS_ON_CHAIN_SEQUENTIAL_TXES = 15;

    // Guild of Guardians
    GuildOfGuardiansClaimGame guildOfGuardiansClaimGame;
}
