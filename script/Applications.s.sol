// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

import {ChainInfrastructure} from "./ChainInfrastructure.s.sol";

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
import {Recipe, IBoom, IBgem as IBgem2, IMintable1155} from "../src/hunters-on-chain/Recipe.sol";
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



    function setupApplicationAccounts() internal {
        (huntersOnChainMinter, huntersOnChainMinterPKey) = makeAddrAndKey(
            string(
                abi.encodePacked(
                    RUN_NAME,
                    "huntersOnChainMinter"
                )
            )
        );
        vm.writeLine(path, "HuntersOnChainMinter Address");
        vm.writeLine(path, Strings.toHexString(huntersOnChainMinter));
        vm.writeLine(path, "HuntersOnChainMinter PKey");
        vm.writeLine(path, Strings.toHexString(huntersOnChainMinterPKey));
        vm.startBroadcast(rootPKey);
        payable(huntersOnChainMinter).transfer(10 ether);
        vm.stopBroadcast();

        // Off-chain signing, so no native tokens needed.
        (
            huntersOnChainOffchainSigner,
            huntersOnChainOffchainSignerPKey
        ) = makeAddrAndKey(
            string(
                abi.encodePacked(
                    RUN_NAME,
                    "huntersOnChainOffchainSigner"
                )
            )
        );
        vm.writeLine(path, "HuntersOnChainOffchainSigner Address");
        vm.writeLine(path, Strings.toHexString(huntersOnChainOffchainSigner));
        vm.writeLine(path, "HuntersOnChainOffchainSigner PKey");
        vm.writeLine(
            path,
            Strings.toHexString(huntersOnChainOffchainSignerPKey)
        );
    }


    function installGemGame() internal {
        vm.startBroadcast(deployerPKey);
        gemGame = new GemGame(admin, admin, admin);
        vm.writeLine(path, "GemGame deployed to address");
        vm.writeLine(path, Strings.toHexString(address(gemGame)));
        vm.stopBroadcast();
    }

    function installHuntersOnChain() internal {
        address[] memory whiteListedMinters = new address[](1);
        whiteListedMinters[0] = huntersOnChainMinter;
        vm.startBroadcast(deployerPKey);
        huntersOnChainRelayer = new Relayer(whiteListedMinters);
        vm.stopBroadcast();
        vm.writeLine(path, "HuntersOnChainRelayer deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainRelayer)));

        name = "BitGem";
        symbol = "BGEM";
        maxSupply = 1000000000000000000 ether;
        vm.startBroadcast(deployerPKey);
        bgemErc20 = new ImmutableERC20MinterBurnerPermit(
            admin,
            address(huntersOnChainRelayer),
            admin,
            name,
            symbol,
            maxSupply
        );
        vm.stopBroadcast();
        vm.startBroadcast(adminPKey);
        bgemErc20.grantMinterRole(huntersOnChainMinter);
        vm.stopBroadcast();
        vm.writeLine(path, "bgemErc20 deployed to address");
        vm.writeLine(path, Strings.toHexString(address(bgemErc20)));

        string memory baseURIe = "https://api-imx.boomland.io/api/e/";
        string memory contractURIe = "https://api-imx.boomland.io";
        vm.startBroadcast(deployerPKey);
        huntersOnChainEquipments = new Equipments(
            admin,
            admin,
            admin,
            admin,
            1000,
            baseURIe,
            contractURIe,
            address(royaltyAllowlist)
        );
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainEquipments deployed to address");
        vm.writeLine(
            path,
            Strings.toHexString(address(huntersOnChainEquipments))
        );

        string memory baseURIa = "https://api-imx.boomland.io/api/s/";
        string memory contractURIa = "https://api-imx.boomland.io";
        vm.startBroadcast(deployerPKey);
        huntersOnChainArtifacts = new Artifacts(
            admin,
            admin,
            admin,
            admin,
            1000,
            baseURIa,
            contractURIa,
            address(royaltyAllowlist)
        );
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainArtifacts deployed to address");
        vm.writeLine(
            path,
            Strings.toHexString(address(huntersOnChainArtifacts))
        );

        string memory baseURIs = "https://api-imx.boomland.io/api/s/{id}";
        string memory contractURIs = "https://api-imx.boomland.io/api/v1/shard";
        vm.startBroadcast(deployerPKey);
        huntersOnChainShards = new Shards(
            admin,
            address(huntersOnChainRelayer),
            admin,
            admin,
            1000,
            baseURIs,
            contractURIs,
            address(royaltyAllowlist)
        );
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainShards deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainShards)));

        vm.startBroadcast(deployerPKey);
        huntersOnChainClaim = new BgemClaim(
            admin,
            IBgem(address(bgemErc20)),
            huntersOnChainOffchainSigner
        );
        huntersOnChainEIP712 = new EIP712WithChanges(
            "Boomland Claim",
            "1",
            address(huntersOnChainClaim)
        );
        vm.stopBroadcast();
        vm.startBroadcast(huntersOnChainMinterPKey);
        bgemErc20.mint(address(huntersOnChainClaim), 1000000 ether);
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainClaim deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainClaim)));
        vm.writeLine(path, "huntersOnChainEIP712 deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainEIP712)));

        vm.startBroadcast(deployerPKey);
        huntersOnChainClaimGame = new HuntersOnChainClaimGame(
            admin,
            admin,
            admin
        );
        vm.writeLine(path, "huntersOnChainClaimGame deployed to address");
        vm.writeLine(
            path,
            Strings.toHexString(address(huntersOnChainClaimGame))
        );
        vm.stopBroadcast();

        Recipe.IChestConfig memory chestOneConfig = Recipe.IChestConfig(
            170000,
            0,
            HUNTERS_ON_CHAIN_COST,
            true
        );
        vm.startBroadcast(deployerPKey);
        huntersOnChainRecipe = new Recipe(
            uint32(block.chainid),
            huntersOnChainOffchainSigner,
            admin,
            IBgem2(address(bgemErc20)),
            IBoom(address(0)),
            IMintable1155(address(huntersOnChainArtifacts)),
            IMintable1155(address(huntersOnChainEquipments)),
            IMintable1155(address(huntersOnChainShards))
        );
        huntersOnChainRecipe.setChestConfig(
            HUNTERS_ON_CHAIN_CHEST1,
            chestOneConfig
        );
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainRecipe deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainRecipe)));

        vm.startBroadcast(deployerPKey);
        huntersOnChainFund = new Fund(huntersOnChainMinter);
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainFund deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainFund)));
    }

    function installGuildOfGuardians() internal {
        vm.startBroadcast(deployerPKey);
        guildOfGuardiansClaimGame = new GuildOfGuardiansClaimGame(
            admin,
            admin,
            admin
        );
        vm.writeLine(path, "guildOfGuardiansClaimGame deployed to address");
        vm.writeLine(
            path,
            Strings.toHexString(address(guildOfGuardiansClaimGame))
        );
        vm.stopBroadcast();
    }


    // ******************* Call functions ********************

    function callValueTransferEOAtoEOA() internal {
        console.logString("callValueTransferEOAtoEOA");
        if (fountain.balance == 0) {
            console.logString("ERROR: Fountain has 0 native gas token");
            revert("Fountain has 0 native gas token");
        }
        vm.startBroadcast(fountainPKey);
        address playerTo = getEOAWithNoNativeTokens();
        // Set 1 Wei from fountain to playerTo
        payable(playerTo).transfer(1);
        vm.stopBroadcast();
    }

    function callGemGameFromUserEOA() internal {
        console.logString("callGemGameFromUserEOA");
        uint256 userPKey;
        (, userPKey) = getEOAWithNativeTokens();
        vm.startBroadcast(userPKey);
        gemGame.earnGem();
        vm.stopBroadcast();
    }

    function callGemGameFromUsersPassport(bool _useNewPassport) internal {
        console.logString("callGemGameFromUsersPassport");
        (address playerMagic, uint256 playerMagicPKey) = _useNewPassport
            ? getNewPassportMagic()
            : getDeployedPassportMagic();
        passportCall(
            playerMagic,
            playerMagicPKey,
            address(gemGame),
            abi.encodeWithSelector(GemGame.earnGem.selector),
            5000,
            0
        );
    }

    function callHuntersOnChainBGemMintERC20(bool _useNewPassport) internal {
        console.logString("callHuntersOnChainBGemMintERC20");
        address playerMagic;
        (playerMagic /*playerMagicPKey*/, ) = _useNewPassport
            ? getNewPassportMagic()
            : getDeployedPassportMagic();
        address playerCfa = cfa(playerMagic);

        bytes memory toCall = abi.encodeWithSelector(
            ImmutableERC20MinterBurnerPermit.mint.selector,
            playerCfa,
            1001 gwei
        );
        Relayer.ForwardRequest memory request0 = Relayer.ForwardRequest(
            /* from   */ address(0),
            /* to     */ address(bgemErc20),
            /* value  */ 0,
            /* gas    */ 1000000,
            /* nonce  */ 0,
            /* data   */ toCall
        );
        Relayer.ForwardRequest[] memory requests = new Relayer.ForwardRequest[](
            1
        );
        requests[0] = request0;
        vm.startBroadcast(huntersOnChainMinterPKey);
        huntersOnChainRelayer.execute(requests);
        vm.stopBroadcast();
    }

    function callShardsERC1155SafeMintBatch(bool _useNewPassport) internal {
        console.logString("callShardsERC1155SafeMintBatch");
        address playerMagic;
        (playerMagic /*playerMagicPKey*/, ) = _useNewPassport
            ? getNewPassportMagic()
            : getDeployedPassportMagic();
        address playerCfa = cfa(playerMagic);

        // safeMintBatch
        // address to: The address that will receive the minted tokens
        // uint256[] calldata ids: The ids of the tokens to mint
        // uint256[] calldata values: The amounts of tokens to mint
        // bytes memory data: Additional data
        // Using values from: https://explorer.immutable.com/tx/0x835c193db1a4893a291e92d87459f8b22e60a43da4ad7feaaa88d8983d4173c4?tab=token_transfers
        uint256[] memory ids = new uint256[](1);
        ids[0] = 61;
        uint256[] memory values = new uint256[](1);
        values[0] = 5;
        bytes memory data = "";
        bytes memory toCall = abi.encodeWithSelector(
            ImmutableERC1155.safeMintBatch.selector,
            playerCfa,
            ids,
            values,
            data
        );
        Relayer.ForwardRequest memory request0 = Relayer.ForwardRequest(
            /* from   */ address(0),
            /* to     */ address(huntersOnChainShards),
            /* value  */ 0,
            /* gas    */ 1000000,
            /* nonce  */ 0,
            /* data   */ toCall
        );
        Relayer.ForwardRequest[] memory requests = new Relayer.ForwardRequest[](
            1
        );
        requests[0] = request0;
        vm.startBroadcast(huntersOnChainMinterPKey);
        huntersOnChainRelayer.execute(requests);
        vm.stopBroadcast();
    }

    function callHuntersOnChainBGemClaimEOA() public {
        console.logString("callHuntersOnChainBGemClaimEOA");
        (address user, uint256 userPKey) = getEOAWithNativeTokens();
        (
            BgemClaim.EIP712Claim memory claim,
            bytes memory sig
        ) = createSignedBGemClaim(user);
        vm.startBroadcast(userPKey);
        huntersOnChainClaim.claim(claim, sig);
        vm.stopBroadcast();
        // console.logString("HuntersOnChainBGemClaimEOA: Contract: huntersOnChainClaim, signed by: EOA. Data:");
        // console.logString(string(abi.encodeWithSelector(BgemClaim.claim.selector, claim, sig)));
    }

    function callHuntersOnChainBGemClaimPassport(bool _useNewPassport) internal {
        console.logString("callHuntersOnChainBGemClaimPassport");
        (address playerMagic, uint256 playerMagicPKey) = _useNewPassport
            ? getNewPassportMagic()
            : getDeployedPassportMagic();
        address playerCfa = cfa(playerMagic);
        (
            BgemClaim.EIP712Claim memory claim,
            bytes memory sig
        ) = createSignedBGemClaim(playerCfa);
        passportCall(
            playerMagic,
            playerMagicPKey,
            address(huntersOnChainClaim),
            abi.encodeWithSelector(BgemClaim.claim.selector, claim, sig),
            80000,
            0
        );
    }

    bytes32 constant EIP712_CLAIM_TYPEHASH =
        keccak256(
            "EIP712Claim(uint256 amount,address wallet,uint48 gameId,uint256 nonce)"
        );

    function createSignedBGemClaim(
        address _wallet
    ) private returns (BgemClaim.EIP712Claim memory, bytes memory) {
        uint256 nonce = bgemClaimNonces[_wallet];
        bgemClaimNonces[_wallet] = nonce + 1;
        BgemClaim.EIP712Claim memory claim = createBGemClaim(_wallet, nonce);

        bytes32 structHash = huntersOnChainEIP712._hashTypedDataV4(
            keccak256(
                abi.encode(
                    EIP712_CLAIM_TYPEHASH,
                    claim.amount,
                    claim.wallet,
                    claim.gameId,
                    claim.nonce
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            huntersOnChainOffchainSignerPKey,
            structHash
        );
        bytes memory encodedSig = abi.encodePacked(r, s, v);
        return (claim, encodedSig);
    }

    function createBGemClaim(
        address _wallet,
        uint256 _nonce
    ) private pure returns (BgemClaim.EIP712Claim memory) {
        BgemClaim.EIP712Claim memory claim = BgemClaim.EIP712Claim(
            /* amount */ 1002 gwei,
            /* wallet */ _wallet,
            /* gameId */ 1,
            /* nonce */ _nonce
        );
        return claim;
    }

    function callHuntersOnChainClaimGamePassport(bool _useNewPassport) internal {
        console.logString("callHuntersOnChainClaimGamePassport");
        (address playerMagic, uint256 playerMagicPKey) = _useNewPassport
            ? getNewPassportMagic()
            : getDeployedPassportMagic();
        passportCall(
            playerMagic,
            playerMagicPKey,
            address(huntersOnChainClaimGame),
            abi.encodeWithSelector(HuntersOnChainClaimGame.claim.selector),
            5000,
            0
        );
    }

    function callHuntersOnChainRecipeOpenChestPassport(
        bool _useNewPassport
    ) internal {
        console.logString("callHuntersOnChainRecipeOpenChestPassport");
        // Check the user's balance.
        (address playerMagic, uint256 playerMagicPKey) = _useNewPassport
            ? getNewPassportMagic()
            : getDeployedPassportMagic();
        address playerCfa = cfa(playerMagic);
        //console.log("Before call1: Balanace of %s is %i", playerCfa, bgemErc20.balanceOf(playerCfa));
        // For some non-obvious reason, the simlation fails with this conditional logic.
        //if (bgemErc20.balanceOf(playerCfa) < 1000 gwei) {
        vm.startBroadcast(huntersOnChainMinter);
        bgemErc20.mint(playerCfa, 1003 gwei);
        vm.stopBroadcast();
        //}
        //console.log("Before call2: Balanace of %s is %i", playerCfa, bgemErc20.balanceOf(playerCfa));

        address[] memory contracts = new address[](2);
        contracts[0] = address(bgemErc20);
        contracts[1] = address(huntersOnChainRecipe);
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(
            IERC20.approve.selector,
            address(huntersOnChainRecipe),
            HUNTERS_ON_CHAIN_COST
        );
        data[1] = abi.encodeWithSelector(
            Recipe.openChest.selector,
            HUNTERS_ON_CHAIN_CHEST1
        );
        uint256[] memory gas = new uint256[](2);
        gas[0] = 30000;
        gas[1] = 60000;
        uint256[] memory value = new uint256[](2);
        value[0] = 0;
        value[1] = 0;

        passportMultiCall(
            playerMagic,
            playerMagicPKey,
            contracts,
            data,
            gas,
            value
        );
        //console.log("After call: Balanace of %s is %i", playerCfa, bgemErc20.balanceOf(playerCfa));
    }

    // Fund thousands of new wallets with some value, in batches of 500.
    // This will result in transactions of about 17M gas.
    function callHuntersOnChainFund() internal {
        console.logString("callHuntersOnChainFund");
        uint256[] memory amounts = new uint256[](
            HUNTERS_ON_CHAIN_NEW_USERS_PER_TX
        );
        for (uint256 i = 0; i < HUNTERS_ON_CHAIN_NEW_USERS_PER_TX; i++) {
            amounts[i] = 0.00001 ether;
        }
        uint256 totalAmount = HUNTERS_ON_CHAIN_NEW_USERS_PER_TX * 0.00001 ether;

        address payable[] memory recipients = new address payable[](
            HUNTERS_ON_CHAIN_NEW_USERS_PER_TX
        );
        for (uint256 j = 0; j < HUNTERS_ON_CHAIN_SEQUENTIAL_TXES; j++) {
            uint256 val = getNextDrbgOutputUnfiltered();
            for (uint256 i = 0; i < HUNTERS_ON_CHAIN_NEW_USERS_PER_TX; i++) {
                recipients[i] = payable(address(uint160(val + i)));
            }
            vm.startBroadcast(huntersOnChainMinter);
            huntersOnChainFund.fund{value: totalAmount}(recipients, amounts);
            vm.stopBroadcast();
        }
    }

    function callGuildOfGuardiansClaimGamePassport(
        bool _useNewPassport
    ) internal {
        console.logString("callGuildOfGuardiansClaimGamePassport");
        (address playerMagic, uint256 playerMagicPKey) = _useNewPassport
            ? getNewPassportMagic()
            : getDeployedPassportMagic();
        passportCall(
            playerMagic,
            playerMagicPKey,
            address(guildOfGuardiansClaimGame),
            abi.encodeWithSelector(GuildOfGuardiansClaimGame.claim.selector),
            5000,
            0
        );
    }

    // Deterministic Random Sequence Generator.
    uint256 drbgCounter = 0;
    function getNextDrbgOutputUnfiltered() internal returns (uint256) {
        bytes32 hashOfCounter = keccak256(abi.encodePacked(drbgCounter++));
        return uint256(hashOfCounter);
    }
}
