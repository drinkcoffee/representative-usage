// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";

// Passport Wallet
import {Factory} from "../src/wallet/Factory.sol";
import {MultiCallDeploy} from "../src/wallet/MultiCallDeploy.sol";
import {LatestWalletImplLocator} from "../src/wallet/startup/LatestWalletImplLocator.sol";
import {StartupWalletImpl} from "../src/wallet/startup/StartupWalletImpl.sol";
import {MainModuleDynamicAuth} from "../src/wallet/modules/MainModuleDynamicAuth.sol";
import {ImmutableSigner} from "../src/wallet/signer/ImmutableSigner.sol";
import {IModuleCalls} from "../src/wallet/modules/commons/interfaces/IModuleCalls.sol";

// Gem Game
import {GemGame} from "../src/im-contracts/games/gems/GemGame.sol";

// ERC20
import {ImmutableERC20MinterBurnerPermit} from "../src/im-contracts/token/erc20/preset/ImmutableERC20MinterBurnerPermit.sol";

// Hunters on Chain
import {Relayer} from "../src/hunters-on-chain/Relayer.sol";

contract CounterTest is Test {
    // Have one admin account for everything: In the real deployment these are multisigs, with different
    // multisigs used for different adminstration groups.
    address public admin;

    // TODO: Might need to create a multitude of users.
    address public userEOA;
    uint256 public userEOAPKey;

    // Used as part of passport relayer
    address public relayerEOA;

    address public passportSigner;
    uint256 public passportSignerPKey;
    // Passport wallet nonces, based on the counter factual address.
    mapping (address => uint256) nonces;

    // Passport wallet.
    Factory public walletFactory;
    MultiCallDeploy public multiCallDeploy;
    LatestWalletImplLocator public latestWalletImplLocator;
    StartupWalletImpl public startupWallet;
    MainModuleDynamicAuth public mainModuleDynamicAuth;
    ImmutableSigner public immutableSigner;

    // Accounts for use in testing.
    uint256 public constant NUM_PLAYERS = 100;
    uint256 public currentPlayer;
    address[] players;

    uint256 public constant NUM_PASSPORT_PLAYERS = 100;
    uint256 public currentPassportPlayer;
    address[] passportPlayersUserEOA;

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
    Relayer huntersOnChainRelayer;




    function setUp() public {
        admin = makeAddr("admin");
        relayerEOA = makeAddr("relayerEOA");
        (passportSigner, passportSignerPKey) = makeAddrAndKey("passportSigner");
        (userEOA, userEOAPKey) = makeAddrAndKey("userEOA");

        distributeNativeToken();

        installPassportWallet();
        installGemGame();
        installERC20();

        createPassportPlayers();

        installHuntersOnChain();
    }

    function distributeNativeToken() private {
        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            bytes memory userStr = abi.encodePacked("player", i);
            address user = makeAddr(string(userStr));
            deal(user, 1000000);
            players.push(user);
        }

        // Give a lot of value to this address, given EOA value transfer needs to be faked.
        deal(address(this), 1000000000000);
    }

    function createPassportPlayers() private {
        for (uint256 i = 0; i < NUM_PASSPORT_PLAYERS; i++) {
            bytes memory userStr = abi.encodePacked("passport player", i);
            address user = makeAddr(string(userStr));
            passportPlayersUserEOA.push(user);
        }
    }

    function installPassportWallet() private {
        multiCallDeploy = new MultiCallDeploy(admin, relayerEOA);
        walletFactory = new Factory(admin, address(multiCallDeploy));
        latestWalletImplLocator = new LatestWalletImplLocator(admin, admin);
        startupWallet = new StartupWalletImpl(address(latestWalletImplLocator));
        mainModuleDynamicAuth = new MainModuleDynamicAuth(address(walletFactory), address(startupWallet));
        immutableSigner = new ImmutableSigner(admin, admin, passportSigner);

        vm.prank(admin);
        latestWalletImplLocator.changeWalletImplementation(address(mainModuleDynamicAuth));
    }

    function installGemGame() private {
        gemGame = new GemGame(admin, admin, admin);
    }

    function installERC20() private {
        minter = makeAddr("minterRole");
        name = "HappyToken";
        symbol = "HPY";
        maxSupply = 1000000000;
        erc20 = new ImmutableERC20MinterBurnerPermit(admin, minter, admin, name, symbol, maxSupply);
    }

    function installHuntersOnChain() private {
        huntersOnChainMinter = makeAddr("huntersOnChainMinter");
        address[] memory whiteListedMinters = new address[](1);
        whiteListedMinters[0] = huntersOnChainMinter;
        huntersOnChainRelayer = new Relayer(whiteListedMinters);

        name = "BitGem";
        symbol = "BGEM";
        maxSupply = 1000000000000000000;
        bgemErc20 = new ImmutableERC20MinterBurnerPermit(admin, address(huntersOnChainRelayer), admin, name, symbol, maxSupply);
    }


    // Run each function once. See README.md to see the proportion of transactions 
    // that each function should be executed.
    function testAll() public {
        uint256 notRand = 0;
        for (uint256 i = 0; i < 1000; i++) {
            notRand = (notRand + 7) % 100;

            if (notRand < 12) {
                callValueTransferEOAtoEOA();
            }

        }



        callGemGameFromUserEOA();
        callGemGameFromUsersPassport();
        callMintERC20();
        callHuntersOnChainBGemMintERC20();
    }


    // Run each function separately and add some test code to ensure the function is running correctly.
    function testCallValueTransfertoEOA() public {
        // This should be an EOA value transfer.
        uint256 theNextPlayer = (currentPlayer + 1) % NUM_PLAYERS;
        address playerTo = players[theNextPlayer];

        uint256 balToBefore = playerTo.balance;
        callValueTransferEOAtoEOA();
        uint256 balToAfter = playerTo.balance;
        assertEq(balToBefore + AMOUNT, balToAfter);
    }

    event GemEarned(address indexed account, uint256 timestamp);
    function testCallGemGameFromUserEOA() public {
        vm.expectEmit(true, true, false, false);
        emit GemEarned(userEOA, block.timestamp);
        callGemGameFromUserEOA();
    }
    function testCallGemGameFromUsersPassport() public {
        vm.expectEmit(true, true, false, false);
        emit GemEarned(cfa(userEOA), block.timestamp);
        callGemGameFromUsersPassport();
    }
    function testCallMintERC20() public {
        callMintERC20();
        assertEq(erc20.balanceOf(userEOA), AMOUNT);
    }

    function testCallHuntersOnChainBGemMintERC20() public {
        callHuntersOnChainBGemMintERC20();
    }


    // In this test system, it is impossible to actually do an EOA value transfer.
    function callValueTransferEOAtoEOA() public {
        address playerFrom = players[currentPlayer];
        currentPlayer = (currentPlayer + 1) % NUM_PLAYERS;
        address playerTo = players[currentPlayer];
        // Set 1 Wei from playerFrom to playerTo
        payable(playerTo).transfer(AMOUNT);
    }

    // In this test system, it is impossible to actually do an EOA value transfer.
    function callGemGameFromUserEOA() public {
        vm.prank(userEOA);
        gemGame.earnGem();
    }

    function callGemGameFromUsersPassport() public {
        passportCall(userEOA, userEOAPKey, address(gemGame), abi.encodeWithSelector(GemGame.earnGem.selector));
    }

    function callMintERC20() public {
        vm.prank(minter);
        erc20.mint(userEOA, AMOUNT);
    }

    function callHuntersOnChainBGemMintERC20() public {
        currentPassportPlayer = (currentPassportPlayer + 1) % NUM_PASSPORT_PLAYERS;
        address player = passportPlayersUserEOA[currentPassportPlayer];
        address playerCfa = cfa(player);

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
        vm.prank(huntersOnChainMinter);
        huntersOnChainRelayer.execute(requests);
    }





    // ****************************************************
    // Code below is to construct a passport transaction.
    // ****************************************************

    uint16 private constant THRESHOLD = 2;
    uint8 private constant WEIGHT = 1;

    uint8 private constant FLAG_SIGNATURE = 0;
    uint8 private constant FLAG_ADDRESS = 1;
    uint8 private constant FLAG_DYNAMIC_SIGNATURE = 2;

    uint8 private constant SIG_TYPE_EIP712 = 1;
    uint8 private constant SIG_TYPE_ETH_SIGN = 2;
    uint8 private constant SIG_TYPE_WALLET_BYTES32 = 3;

    function passportCall(address _userEOA, uint256 _userPKey,address _contract, bytes memory _data) public {
      passportCall(_userEOA, _userPKey, _contract, _data, 1000000, 0);
    }

    function passportCall(address _userEOA, uint256 _userPKey, address _contract, bytes memory _data, uint256 _gas, uint256 _value) public {
        IModuleCalls.Transaction memory transaction = IModuleCalls.Transaction({
            delegateCall: false,
            revertOnError: true,
            gasLimit: _gas,
            target: _contract,
            value: _value,
            data: _data
        });
        IModuleCalls.Transaction[] memory txs = new IModuleCalls.Transaction[](1);
        txs[0] = transaction;
        bytes32 walletSalt = encodeImageHash(_userEOA, address(immutableSigner));
        address walletCounterFactualAddress = addressOf(address(walletFactory), address(startupWallet), walletSalt);
        uint256 nonce = getNextNonce(walletCounterFactualAddress);
        bytes32 hashToBeSigned = encodeMetaTransactionsData(walletCounterFactualAddress, txs, nonce);

        bytes memory signature = walletMultiSign(_userEOA, _userPKey, hashToBeSigned);

        vm.prank(relayerEOA);
        multiCallDeploy.deployAndExecute(walletCounterFactualAddress, 
            address(startupWallet), walletSalt, address(walletFactory), txs, nonce, signature);
    }

    // Image hash can handle an aribtrary number of signers, with arbitrary weights and a threshold. 
    // Simplify this to the usage we have: two signers, threshold two, equal weight.
    function encodeImageHash(address addrA, address addrB) private view returns(bytes32) {
        address addr1;
        address addr2;
        // Sort addresses so that we have a canonical form.
        if (uint160(addrA) > uint160(addrB)) {
            addr1 = addrA;
            addr2 = addrB;
        }
        else {
            addr2 = addrA;
            addr1 = addrB;
        }
        
        bytes32 imageHash = bytes32(uint256(THRESHOLD));

        imageHash = keccak256(abi.encode(imageHash, uint256(WEIGHT), addr1));
        imageHash = keccak256(abi.encode(imageHash, uint256(WEIGHT), addr2));
        return imageHash;
    }


    function cfa(address _userEOA) private view returns (address) {
        bytes32 walletSalt = encodeImageHash(_userEOA, address(immutableSigner));
        return addressOf(address(walletFactory), address(startupWallet), walletSalt);
    }


    // This bytecode must precisely match that in src/contracts/Wallet.sol
    // Yul wallet proxy with PROXY_getImplementation
    bytes public constant WALLET_CODE = hex'6054600f3d396034805130553df3fe63906111273d3560e01c14602b57363d3d373d3d3d3d369030545af43d82803e156027573d90f35b3d90fd5b30543d5260203df3';

    function addressOf(address _factory, address _mainModule, bytes32 _imageHash) private view returns (address) {
        bytes32 aHash = keccak256(
            abi.encodePacked(
                bytes1(0xff), 
                _factory, 
                _imageHash, 
                keccak256(abi.encodePacked(WALLET_CODE, uint256(uint160(_mainModule))))));
        return address(uint160(uint256(aHash)));
    }

    function getNextNonce(address _cfa) private returns(uint256) {
        uint256 nonce = nonces[_cfa];
        nonces[_cfa] = nonce + 1;
        return nonce;
    }

    function encodeMetaTransactionsData(address _owner, IModuleCalls.Transaction[] memory _txs, uint256 _nonce) private view returns(bytes32) {
        return _subDigest(_owner, keccak256(abi.encode(_nonce, _txs)));
    }

    function _subDigest(address _walletAddress, bytes32 _digest) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", block.chainid, _walletAddress, _digest));
    }

    function walletMultiSign(address _userEOA, uint256 _userPKey, bytes32 _toBeSigned) private returns(bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(passportSignerPKey, _toBeSigned);
        bytes memory encodedSigPassportSigner = abi.encodePacked(r, s, v, SIG_TYPE_EIP712, SIG_TYPE_WALLET_BYTES32);

        (v, r, s) = vm.sign(_userPKey, _toBeSigned);
        bytes memory encodedSigUser = abi.encodePacked(r, s, v, SIG_TYPE_EIP712);

        // Sort addresses so that we have a canonical form.
        if (uint160(_userEOA) > uint160(address(immutableSigner))) {
            return abi.encodePacked(THRESHOLD, 
                FLAG_SIGNATURE, WEIGHT, encodedSigUser,
                FLAG_DYNAMIC_SIGNATURE, WEIGHT, address(immutableSigner), uint16(encodedSigPassportSigner.length), encodedSigPassportSigner);
        }
        else {
            return abi.encodePacked(THRESHOLD, 
                FLAG_DYNAMIC_SIGNATURE, WEIGHT, address(immutableSigner), uint16(encodedSigPassportSigner.length), encodedSigPassportSigner,
                FLAG_SIGNATURE, WEIGHT, encodedSigUser);
        }
    }
}