// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

import {DeployAll} from "./DeployAll.s.sol";

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

contract RunCustom is DeployAll {
    uint256 _treasuryPKey = vm.envUint("ACCOUNT_PVT_KEY");

    string public executionType = vm.envString("EXECUTION_TYPE");

    function run() public override {
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

        if (Strings.equal(executionType, "deploy")) {
            console.logString("Deploying contracts");
            deployAll();
        } else if (Strings.equal(executionType, "execute")) {
            console.logString("Executing transactions");
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
        } else if (Strings.equal(executionType, "deploy-execute")) {
            deployAll();
            _loadAddresses();
            callGemGameFromUsersPassport(true);
        } else {
            console.logString("Unknown execution type");
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
        uint256 userPKey;
        (, userPKey) = getEOAWithNativeTokens();
        vm.startBroadcast(userPKey);
        gemGame.earnGem();
        vm.stopBroadcast();
    }

    function callGemGameFromUsersPassport(bool _useNewPassport) public {
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

    function callHuntersOnChainBGemMintERC20(bool _useNewPassport) public {
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

    function callShardsERC1155SafeMintBatch(bool _useNewPassport) public {
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

    function callHuntersOnChainBGemClaimPassport(bool _useNewPassport) public {
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

    function _loadBGEMNonceFromFile(address _cfa) internal {
        string memory noncePath = string(
            abi.encodePacked(
                "./temp/bgemnonce-",
                Strings.toHexString(uint160(_cfa), 20),
                "-",
                RUN_NAME,
                "-",
                treasuryAddress,
                ".txt"
            )
        );
        string memory nonceStr = "0x0";
        if (vm.exists(noncePath)) {
            nonceStr = vm.readFile(noncePath);
        }
        if (bytes(nonceStr).length > 0) {
            bgemClaimNonces[_cfa] = uint256(vm.parseUint(nonceStr));
        }
    }

    function _writeBGEMNonceToFile(address _cfa) internal {
        string memory noncePath = string(
            abi.encodePacked(
                "./temp/bgemnonce-",
                Strings.toHexString(uint160(_cfa), 20),
                "-",
                RUN_NAME,
                "-",
                treasuryAddress,
                ".txt"
            )
        );
        vm.writeFile(noncePath, Strings.toHexString(bgemClaimNonces[_cfa]));
    }

    function createSignedBGemClaim(
        address _wallet
    ) private returns (BgemClaim.EIP712Claim memory, bytes memory) {
        _loadBGEMNonceFromFile(_wallet);
        uint256 nonce = bgemClaimNonces[_wallet];
        bgemClaimNonces[_wallet] = nonce + 1;
        _writeBGEMNonceToFile(_wallet);
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

    function callHuntersOnChainClaimGamePassport(bool _useNewPassport) private {
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
    ) private {
        console.logString("callHuntersOnChainRecipeOpenChestPassport");
        // Check the user's balance.
        (address playerMagic, uint256 playerMagicPKey) = _useNewPassport
            ? getNewPassportMagic()
            : getDeployedPassportMagic();
        address playerCfa = cfa(playerMagic);
        //console.log("Before call1: Balanace of %s is %i", playerCfa, bgemErc20.balanceOf(playerCfa));
        // For some non-obvious reason, the simlation fails with this conditional logic.
        //if (bgemErc20.balanceOf(playerCfa) < 1000 gwei) {
        vm.startBroadcast(huntersOnChainMinterPKey);
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
    function callHuntersOnChainFund() private {
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
            uint256 val = getNextDrbgOutput();
            for (uint256 i = 0; i < HUNTERS_ON_CHAIN_NEW_USERS_PER_TX; i++) {
                recipients[i] = payable(address(uint160(val + i)));
            }
            vm.startBroadcast(huntersOnChainMinterPKey);
            huntersOnChainFund.fund{value: totalAmount}(recipients, amounts);
            vm.stopBroadcast();
        }
    }

    function callGuildOfGuardiansClaimGamePassport(
        bool _useNewPassport
    ) private {
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

    uint256 drbgCounter = 0;
    function getNextDrbgOutput() private returns (uint256) {
        bytes32 hashOfCounter = keccak256(abi.encodePacked(drbgCounter++));
        uint256 output = uint256(hashOfCounter) % 500000;
        console.log("DRBG output: %i, %i", output, drbgCounter);
        return output;
    }
}
