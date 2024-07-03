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

// Gem Game
import {GemGame} from "../src/im-contracts/games/gems/GemGame.sol";


contract CounterTest is Test {
    // Have one admin account for everything: In the real deployment these are multisigs, with different
    // multisigs used for different adminstration groups.
    address public admin;

    // TODO: Might need to create a multitude of users.
    address public userEOA;

    // Used as part of passport relayer
    address public relayerEOA;

    address public passportSigner;

    // Passport wallet.
    Factory public walletFactory;
    MultiCallDeploy public multiCallDeploy;
    LatestWalletImplLocator public latestWalletImplLocator;
    StartupWalletImpl public startupWalletImpl;
    MainModuleDynamicAuth public mainModuleDynamicAuth;
    ImmutableSigner public immutableSigner;

    // Gem game
    GemGame public gemGame;


    function setUp() public {
        admin = makeAddr("admin");
        relayerEOA = makeAddr("relayerEOA");
        passportSigner = makeAddr("passportSigner");


        installPassportWallet();
        installGemGame();
    }

    function installPassportWallet() private {
        multiCallDeploy = new MultiCallDeploy(admin, relayerEOA);
        walletFactory = new Factory(admin, address(multiCallDeploy));
        latestWalletImplLocator = new LatestWalletImplLocator(admin, admin);
        startupWalletImpl = new StartupWalletImpl(address(latestWalletImplLocator));
        mainModuleDynamicAuth = new MainModuleDynamicAuth(address(walletFactory), address(startupWalletImpl));
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
    }


    function callGemGameFromUserEOA() public {
        vm.prank(userEOA);
        gemGame.earnGem();
    }


}
