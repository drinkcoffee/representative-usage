// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

//import {Applications} from "./Applications.s.sol";
import {DeployAll} from "./DeployAll.s.sol";

// Open Zeppelin contracts
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
// Slightly hacked Open Zeppelin contracts
import {EIP712WithChanges} from "./EIP712WithChanges.sol";

// Immutable Contracts repo
import {ImmutableERC20MinterBurnerPermit} from "../src/im-contracts/token/erc20/preset/ImmutableERC20MinterBurnerPermit.sol";
import {ImmutableERC1155} from '../src/im-contracts/token/erc1155/preset/ImmutableERC1155.sol';

// Gem Game
import {GemGame} from "../src/im-contracts/games/gems/GemGame.sol";

// Hunters on Chain
import {Relayer} from "../src/hunters-on-chain/Relayer.sol";
import {Shards} from "../src/hunters-on-chain/Shards.sol";
import {BgemClaim, IBgem} from "../src/hunters-on-chain/Claim.sol";
import {HuntersOnChainClaimGame} from "../src/hunters-on-chain/HuntersOnChainClaimGame.sol";
import {Equipments} from "../src/hunters-on-chain/Equipments.sol";
import {Artifacts} from "../src/hunters-on-chain/Artifacts.sol";

// Guild of Guardians
import {GuildOfGuardiansClaimGame} from "../src/guild-of-guardians/GuildOfGuardiansClaimGame.sol";

//contract RunAll is Applications {
contract RunAll is DeployAll {
    function run() public override {
        // Anvil is resetting between deploy and run all, so deploy before run.
        deployAll();

        // Have this different for each run.
        string memory runName = "0";
        console.logString("Start *********************************");
        console.logString(string(abi.encodePacked("Loading deployment address information from: ", path)));

        vm.readLine(path); // Discard line: Execution Start *********************************
        vm.readLine(path); // Discard line: Run Name
        vm.readLine(path); // Discard line: the run name

        loadAccounts(runName);
        loadDeployedContracts();

        runAll();
    }

    function loadAccounts(string memory /* _runName */) internal {
        vm.readLine(path); // Discard line: Root Address
        root = vm.parseAddress(vm.readLine(path));
        vm.readLine(path); // Discard line: Root PKey
        rootPKey = vm.parseUint(vm.readLine(path));
        console.logString("Loaded root as");
        console.logAddress(root);
        console.logString("Loaded rootPKey as");
        console.logUint(rootPKey);

        vm.readLine(path); // Discard line: Deployer Address
        deployer = vm.parseAddress(vm.readLine(path));
        vm.readLine(path); // Discard line: Deployer PKey
        deployerPKey = vm.parseUint(vm.readLine(path));
        console.logString("Loaded deployer as");
        console.logAddress(deployer);
        console.logString("Loaded deployerPKey as");
        console.logUint(deployerPKey);

        vm.readLine(path); // Discard line: Admin Address
        admin = vm.parseAddress(vm.readLine(path));
        vm.readLine(path); // Discard line: Admin PKey
        adminPKey = vm.parseUint(vm.readLine(path));
        console.logString("Loaded admin as");
        console.logAddress(admin);
        console.logString("Loaded adminPKey as");
        console.logUint(adminPKey);
        if (admin.balance == 0) {
            console.logString("ERROR: Admin has 0 native gas token");
            revert("Admin has 0 native gas token");
        }


        vm.readLine(path); // Discard line: Relayer Address
        relayer = vm.parseAddress(vm.readLine(path));
        vm.readLine(path); // Discard line: Relayer PKey
        relayerPKey = vm.parseUint(vm.readLine(path));
        console.logString("Loaded relayer as");
        console.logAddress(relayer);
        console.logString("Loaded relayerPKey as");
        console.logUint(relayerPKey);

        vm.readLine(path); // Discard line: PassportSigner Address
        passportSigner = vm.parseAddress(vm.readLine(path));
        vm.readLine(path); // Discard line: PassportSigner PKey
        passportSignerPKey = vm.parseUint(vm.readLine(path));
        console.logString("Loaded passportSigner as");
        console.logAddress(passportSigner);
        console.logString("Loaded passportSignerPKey as");
        console.logUint(passportSignerPKey);

        vm.readLine(path); // Discard line: HuntersOnChainMinter Address
        huntersOnChainMinter = vm.parseAddress(vm.readLine(path));
        vm.readLine(path); // Discard line: HuntersOnChainMinter PKey
        huntersOnChainMinterPKey = vm.parseUint(vm.readLine(path));
        console.logString("Loaded huntersOnChainMinter as");
        console.logAddress(huntersOnChainMinter);
        console.logString("Loaded huntersOnChainMinterPKey as");
        console.logUint(huntersOnChainMinterPKey);

        vm.readLine(path); // Discard line: HuntersOnChainOffchainSigner Address
        huntersOnChainOffchainSigner = vm.parseAddress(vm.readLine(path));
        vm.readLine(path); // Discard line: HuntersOnChainOffchainSigner PKey
        huntersOnChainOffchainSignerPKey = vm.parseUint(vm.readLine(path));
        console.logString("Loaded huntersOnChainOffchainSigner as");
        console.logAddress(huntersOnChainOffchainSigner);
        console.logString("Loaded huntersOnChainOffchainSignerPKey as");
        console.logUint(huntersOnChainOffchainSignerPKey);
    }


    function loadDeployedContracts() public {
        loadPassportWalletContracts();
        loadGemGame();
        // Applications don't directly interact with Royalty Allowlist at run time, so nothing to load.
        loadHuntersOnChain();
    }


    function loadGemGame() private {
        vm.readLine(path); // Discard line: GemGame deployed to address
        gemGame = GemGame(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded GemGame as");
        console.logAddress(address(gemGame));
    }

    function loadHuntersOnChain() private {
        vm.readLine(path); // Discard line: HuntersOnChainRelayer deployed to address
        huntersOnChainRelayer = Relayer(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded HuntersOnChainRelayer as");
        console.logAddress(address(huntersOnChainRelayer));

        vm.readLine(path); // Discard line: bgemErc20 deployed to address
        bgemErc20 = ImmutableERC20MinterBurnerPermit(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded bgemErc20 as");
        console.logAddress(address(bgemErc20));

        vm.readLine(path); // Discard line: huntersOnChainEquipment deployed to address
        huntersOnChainEquipments = Equipments(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded huntersOnChainEquipment as");
        console.logAddress(address(huntersOnChainEquipments));

        vm.readLine(path); // Discard line: huntersOnChainArtifacts deployed to address
        huntersOnChainArtifacts = Artifacts(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded huntersOnChainArtifacts as");
        console.logAddress(address(huntersOnChainArtifacts));

        vm.readLine(path); // Discard line: huntersOnChainShards deployed to address
        huntersOnChainShards = Shards(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded huntersOnChainShards as");
        console.logAddress(address(huntersOnChainShards));

        vm.readLine(path); // Discard line: huntersOnChainClaim deployed to address
        huntersOnChainClaim = BgemClaim(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded huntersOnChainClaim as");
        console.logAddress(address(huntersOnChainClaim));

        vm.readLine(path); // Discard line: huntersOnChainEIP712 deployed to address
        huntersOnChainEIP712 = EIP712WithChanges(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded huntersOnChainEIP712 as");
        console.logAddress(address(huntersOnChainEIP712));

        vm.readLine(path); // Discard line: huntersOnChainClaimGame deployed to address
        huntersOnChainClaimGame = HuntersOnChainClaimGame(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded huntersOnChainClaimGame as");
        console.logAddress(address(huntersOnChainClaimGame));
    }


    // Percentages to two decimal places of chain utilisation on Sunday July 14, 2024
    // NOTE that the numbers are not consistent: the Passport numbers appear to be slightly inflated.
    uint256 public constant P_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT = 83;
    uint256 public constant P_PASSPORT_GEM_GAME = 2627 - P_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT;
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

    uint256 public constant T_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT = P_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT;
    uint256 public constant T_PASSPORT_GEM_GAME = T_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT + P_PASSPORT_GEM_GAME;
    uint256 public constant T_PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME = T_PASSPORT_GEM_GAME + P_PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME;
    uint256 public constant T_PASSPORT_HUNTERS_ON_CHAIN_RECIPE = T_PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME + P_PASSPORT_HUNTERS_ON_CHAIN_RECIPE;
    uint256 public constant T_PASSPORT_HUNTERS_ON_CHAIN_BITGEM = T_PASSPORT_HUNTERS_ON_CHAIN_RECIPE + P_PASSPORT_HUNTERS_ON_CHAIN_BITGEM;
    uint256 public constant T_PASSPORT_GUILD_OF_GUARDIANS_CLAIM = T_PASSPORT_HUNTERS_ON_CHAIN_BITGEM + P_PASSPORT_GUILD_OF_GUARDIANS_CLAIM;
    uint256 public constant T_PASSPORT_SPACETREK_CLAIM = T_PASSPORT_GUILD_OF_GUARDIANS_CLAIM + P_PASSPORT_SPACETREK_CLAIM;
    uint256 public constant T_PASSPORT_SPACENATION_COIN = T_PASSPORT_SPACETREK_CLAIM + P_PASSPORT_SPACENATION_COIN;
    uint256 public constant T_PASSPORT_SEAPORT = T_PASSPORT_SPACENATION_COIN + P_PASSPORT_SEAPORT;
    uint256 public constant T_EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM = T_PASSPORT_SEAPORT + P_EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM;
    uint256 public constant T_EOA_HUNTERS_ON_CHAIN_RELAYER_MINT = T_EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM + P_EOA_HUNTERS_ON_CHAIN_RELAYER_MINT;
    uint256 public constant T_EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT = T_EOA_HUNTERS_ON_CHAIN_RELAYER_MINT + P_EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT;
    uint256 public constant T_EOA_GEM_GAME = T_EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT + P_EOA_GEM_GAME;
    uint256 public constant T_EOA_VALUE_TRANSFER = T_EOA_GEM_GAME + P_EOA_VALUE_TRANSFER;
    uint256 public constant T_EOA_BABY_SHARK_UNIVERSE_PROXY = T_EOA_VALUE_TRANSFER + P_EOA_BABY_SHARK_UNIVERSE_PROXY;
    uint256 public constant T_EOA_BABY_SHARK_UNIVERSE = T_EOA_BABY_SHARK_UNIVERSE_PROXY + P_EOA_BABY_SHARK_UNIVERSE;
    uint256 public constant T_EOA_BLACKPASS = T_EOA_BABY_SHARK_UNIVERSE + P_EOA_BLACKPASS;
    uint256 public constant T_EOA_HUNTERS_ON_CHAIN_FUND = T_EOA_BLACKPASS + P_EOA_HUNTERS_ON_CHAIN_FUND;
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



        for (uint256 i = 0; i < 1000; i++) {
            uint256 drbg = getNextDrbgOutput();

            if (drbg < T_PASSPORT_GEM_GAME_WITH_NEW_PASSPORT) {
                callGemGameFromUsersPassport(true);
            }
            else if (drbg < T_PASSPORT_GEM_GAME) {
                callGemGameFromUsersPassport(false);
            }
            else if (drbg < T_PASSPORT_HUNTERS_ON_CHAIN_CLAIM_GAME) {
                callHuntersOnChainClaimGamePassport(false);
            }
            else if (drbg < T_PASSPORT_HUNTERS_ON_CHAIN_RECIPE) {
                console.log("TODO");
            }
            else if (drbg < T_PASSPORT_HUNTERS_ON_CHAIN_BITGEM) {
                callHuntersOnChainBGemClaimPassport(false);
            }
            else if (drbg < T_PASSPORT_GUILD_OF_GUARDIANS_CLAIM) {
                callGuildOfGuardiansClaimGamePassport(false);
            }
            else if (drbg < T_PASSPORT_SPACETREK_CLAIM) {
                console.log("TODO");
            }
            else if (drbg < T_PASSPORT_SPACENATION_COIN) {
                console.log("TODO");
            }
            else if (drbg < T_PASSPORT_SEAPORT) {
                console.log("TODO");
            }
            else if (drbg < T_EOA_HUNTERS_ON_CHAIN_BGEM_CLAIM) {
                callHuntersOnChainBGemClaimEOA();
            }
            else if (drbg < T_EOA_HUNTERS_ON_CHAIN_RELAYER_MINT) {
                callHuntersOnChainBGemMintERC20(false);
            }
            else if (drbg < T_EOA_HUNTERS_ON_CHAIN_RELAYER_SHARD_MINT) {
                callShardsERC1155SafeMintBatch(false);
            }
            else if (drbg < T_EOA_GEM_GAME) {
                callGemGameFromUserEOA();
            }
            else if (drbg < T_EOA_VALUE_TRANSFER) {
                callValueTransferEOAtoEOA();
            }
            else if (drbg < T_EOA_BABY_SHARK_UNIVERSE_PROXY) {
                console.log("TODO");
            }
            else if (drbg < T_EOA_BABY_SHARK_UNIVERSE) {
                console.log("TODO");
            }
            else if (drbg < T_EOA_BLACKPASS) {
                console.log("TODO");
            }
            else if (drbg < T_EOA_HUNTERS_ON_CHAIN_FUND) {
                console.log("TODO");
            }
        }
    }

    // Deterministic Random Sequence Generator.
    uint256 drbgCounter = 0;
    function getNextDrbgOutput() private returns (uint256) {
        bytes32 hashOfCounter = keccak256(abi.encodePacked(drbgCounter++));
        uint256 output = uint256(hashOfCounter) % TOTAL;
        console.log("DRBG output: %i", output);
        return output;
    }



    function callValueTransferEOAtoEOA() public {
        console.logString("callValueTransferEOAtoEOA");
        if (admin.balance == 0) {
            console.logString("ERROR: Admin has 0 native gas token");
            revert("Admin has 0 native gas token");
        }
        vm.startBroadcast(adminPKey);
        address playerTo = getEOAWithNoNativeTokens();
        // Set 1 Wei from admin to playerTo
        payable(playerTo).transfer(1);
        vm.stopBroadcast();
    }



    // In this test system, it is impossible to actually do an EOA value transfer.
    function callGemGameFromUserEOA() public {
        console.logString("callGemGameFromUserEOA");
        vm.startBroadcast(getEOAWithNativeTokens());
        gemGame.earnGem();
        vm.stopBroadcast();
    }

    function callGemGameFromUsersPassport(bool _useNewPassport) public {
        console.logString("callGemGameFromUsersPassport");
        (address playerMagic, uint256 playerMagicPKey) = _useNewPassport ? getNewPassportMagic() : getDeployedPassportMagic();
        passportCall(playerMagic, playerMagicPKey, address(gemGame), abi.encodeWithSelector(GemGame.earnGem.selector));
    }

    function callHuntersOnChainBGemMintERC20(bool _useNewPassport) public {
        console.logString("callHuntersOnChainBGemMintERC20");
        address playerMagic;
        (playerMagic, /*playerMagicPKey*/) = _useNewPassport ? getNewPassportMagic() : getDeployedPassportMagic();
        address playerCfa = cfa(playerMagic);

        bytes memory toCall = abi.encodeWithSelector(ImmutableERC20MinterBurnerPermit.mint.selector, playerCfa, uint256(25));
        Relayer.ForwardRequest memory request0 = Relayer.ForwardRequest(
            /* from   */ address(0),
            /* to     */ address(bgemErc20),
            /* value  */ 0,
            /* gas    */ 1000000,
            /* nonce  */ 0,
            /* data   */ toCall
        );
        Relayer.ForwardRequest[] memory requests = new Relayer.ForwardRequest[](1);
        requests[0] = request0;
        vm.startBroadcast(huntersOnChainMinterPKey);
        huntersOnChainRelayer.execute(requests);
        vm.stopBroadcast();
    }

    function callShardsERC1155SafeMintBatch(bool _useNewPassport) public {
        console.logString("callShardsERC1155SafeMintBatch");
        address playerMagic;
        (playerMagic, /*playerMagicPKey*/) = _useNewPassport ? getNewPassportMagic() : getDeployedPassportMagic();
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
        bytes memory toCall = abi.encodeWithSelector(ImmutableERC1155.safeMintBatch.selector, playerCfa, ids, values, data);
        Relayer.ForwardRequest memory request0 = Relayer.ForwardRequest(
            /* from   */ address(0),
            /* to     */ address(huntersOnChainShards),
            /* value  */ 0,
            /* gas    */ 1000000,
            /* nonce  */ 0,
            /* data   */ toCall
        );
        Relayer.ForwardRequest[] memory requests = new Relayer.ForwardRequest[](1);
        requests[0] = request0;
        vm.startBroadcast(huntersOnChainMinterPKey);
        huntersOnChainRelayer.execute(requests);
        vm.stopBroadcast();
    }

    function callHuntersOnChainBGemClaimEOA() public {
        console.logString("callHuntersOnChainBGemClaimEOA");
        address user = getEOAWithNativeTokens();
        (BgemClaim.EIP712Claim memory claim, bytes memory sig) = createSignedBGemClaim(user);
        vm.startBroadcast(user);
        huntersOnChainClaim.claim(claim, sig);
        // console.logString("HuntersOnChainBGemClaimEOA: Contract: huntersOnChainClaim, signed by: EOA. Data:");
        // console.logString(string(abi.encodeWithSelector(BgemClaim.claim.selector, claim, sig)));
        vm.stopBroadcast();
    }

    function callHuntersOnChainBGemClaimPassport(bool _useNewPassport) public {
        console.logString("callHuntersOnChainBGemClaimPassport");
        (address playerMagic, uint256 playerMagicPKey) = _useNewPassport ? getNewPassportMagic() : getDeployedPassportMagic();
        address playerCfa = cfa(playerMagic);
        (BgemClaim.EIP712Claim memory claim, bytes memory sig) = createSignedBGemClaim(playerCfa);
        passportCall(playerMagic, playerMagicPKey, address(huntersOnChainClaim), 
            abi.encodeWithSelector(BgemClaim.claim.selector, claim, sig));
    }


    bytes32 constant EIP712_CLAIM_TYPEHASH = keccak256(
        "EIP712Claim(uint256 amount,address wallet,uint48 gameId,uint256 nonce)"
    );

    function createSignedBGemClaim(address _wallet) private returns(BgemClaim.EIP712Claim memory, bytes memory) {
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

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(huntersOnChainOffchainSignerPKey, structHash);
        bytes memory encodedSig = abi.encodePacked(r, s, v);
        return (claim, encodedSig);
    }

    function createBGemClaim(address _wallet, uint256 _nonce) private pure returns(BgemClaim.EIP712Claim memory) {
        BgemClaim.EIP712Claim memory claim = BgemClaim.EIP712Claim(
            /* amount */    10000000000000000000,
            /* wallet */    _wallet,
            /* gameId */    1,
            /* nonce */     _nonce
        );
        return claim;
    }

    function callHuntersOnChainClaimGamePassport(bool _useNewPassport) public {
        console.logString("callHuntersOnChainClaimGamePassport");
        (address playerMagic, uint256 playerMagicPKey) = _useNewPassport ? getNewPassportMagic() : getDeployedPassportMagic();
        passportCall(playerMagic, playerMagicPKey, address(huntersOnChainClaimGame), 
            abi.encodeWithSelector(HuntersOnChainClaimGame.claim.selector));
    }

    function callGuildOfGuardiansClaimGamePassport(bool _useNewPassport) public {
        console.logString("callGuildOfGuardiansClaimGamePassport");
        (address playerMagic, uint256 playerMagicPKey) = _useNewPassport ? getNewPassportMagic() : getDeployedPassportMagic();
        passportCall(playerMagic, playerMagicPKey, address(guildOfGuardiansClaimGame), 
            abi.encodeWithSelector(GuildOfGuardiansClaimGame.claim.selector));
    }

}
