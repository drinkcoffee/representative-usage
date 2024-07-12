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
    }



    uint256 public constant PERCENT_ValueTransferEOAtoEOA = 12;
    uint256 public constant PERCENT_GemGameFromUsersPassportNewPassport = 3;
    uint256 public constant PERCENT_GemGameFromUsersPassportExistingPassport = 10;
    uint256 public constant PERCENT_GemGameFromUserEOA = 20;
    uint256 public constant PERCENT_HuntersOnChainBGemMintERC20NewPassport = 1;
    uint256 public constant PERCENT_HuntersOnChainBGemMintERC20ExistingPassport = 1;

        // callShardsERC1155SafeMintBatch(true);
        // callShardsERC1155SafeMintBatch(false);
        // callHuntersOnChainBGemClaimPassport(true);
        // callHuntersOnChainBGemClaimPassport(false);




    function runAll() public {
        uint256 valueTransferEOAtoEOA = PERCENT_ValueTransferEOAtoEOA;
        uint256 gemGameFromUsersPassportNewPassport = valueTransferEOAtoEOA + PERCENT_GemGameFromUsersPassportNewPassport;
        uint256 gemGameFromUsersPassportExistingPassport = gemGameFromUsersPassportNewPassport + PERCENT_GemGameFromUsersPassportExistingPassport;



        uint256 notRand = 0;
        for (uint256 i = 0; i < 1000; i++) {
            notRand = (notRand + 7) % 100;

            if (notRand <= valueTransferEOAtoEOA) {
                callValueTransferEOAtoEOA();
            }
            else if (notRand <= gemGameFromUsersPassportNewPassport) {
                callGemGameFromUsersPassport(true);
            }
            else if (notRand <= gemGameFromUsersPassportExistingPassport) {
                callGemGameFromUsersPassport(false);
            }

            

        }
        callHuntersOnChainBGemMintERC20(true);
        callHuntersOnChainBGemMintERC20(false);
        callShardsERC1155SafeMintBatch(true);
        callShardsERC1155SafeMintBatch(false);
        callHuntersOnChainBGemClaimEOA();
        callHuntersOnChainBGemClaimPassport(true);
        callHuntersOnChainBGemClaimPassport(false);
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
}
