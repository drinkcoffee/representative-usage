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

    // Gem game
    GemGame public gemGame;


    function setUp() public {
        admin = makeAddr("admin");
        relayerEOA = makeAddr("relayerEOA");
        (passportSigner, passportSignerPKey) = makeAddrAndKey("passportSigner");
        (userEOA, userEOAPKey) = makeAddrAndKey("userEOA");

        installPassportWallet();
        installGemGame();
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



    // Run each function once. See README.md to see the proportion of transactions 
    // that each function should be executed.
    function testAll() public {
        callGemGameFromUserEOA();
        callGemGameFromUsersPassport();
    }


    function callGemGameFromUserEOA() public {
        vm.prank(userEOA);
        gemGame.earnGem();
    }


    function callGemGameFromUsersPassport() public {
        passportCall(userEOA, userEOAPKey, address(gemGame), abi.encodeWithSelector(GemGame.earnGem.selector));
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
