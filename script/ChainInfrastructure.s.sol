// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

import {Globals} from "./Globals.s.sol";
import {ImmutableSeaportCreation} from "./generated/ImmutableSeaportCreation.sol";

// Open Zeppelin contracts
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Create3 Deployer
import {AccessControlledDeployer} from "../src/im-contracts/deployer/AccessControlledDeployer.sol";
import {OwnableCreate3Deployer} from "../src/im-contracts/deployer/create3/OwnableCreate3Deployer.sol";

// Passport Wallet
import {Factory} from "../src/wallet/Factory.sol";
import {MultiCallDeploy} from "../src/wallet/MultiCallDeploy.sol";
import {LatestWalletImplLocator} from "../src/wallet/startup/LatestWalletImplLocator.sol";
import {StartupWalletImpl} from "../src/wallet/startup/StartupWalletImpl.sol";
import {MainModuleDynamicAuth} from "../src/wallet/modules/MainModuleDynamicAuth.sol";
import {ImmutableSigner} from "../src/wallet/signer/ImmutableSigner.sol";
import {IModuleCalls} from "../src/wallet/modules/commons/interfaces/IModuleCalls.sol";

// Immutable contracts
import {OperatorAllowlistUpgradeable} from "../src/im-contracts/allowlist/OperatorAllowlistUpgradeable.sol";

// Seaprt
import {ImmutableSeaport} from "../src/im-contracts/trading/seaport/ImmutableSeaport.sol";
import {ConduitController} from "../src/im-contracts/trading/seaport/conduit/ConduitController.sol";

contract ChainInfrastructure is Globals, ImmutableSeaportCreation {
    // Royalty allowlist ******
    OperatorAllowlistUpgradeable royaltyAllowlist;

    // Passport *********
    // This bytecode must precisely match that in src/contracts/Wallet.sol
    // Yul wallet proxy with PROXY_getImplementation
    bytes public constant WALLET_DEPLOY_CODE =
        hex"6054600f3d396034805130553df3fe63906111273d3560e01c14602b57363d3d373d3d3d3d369030545af43d82803e156027573d90f35b3d90fd5b30543d5260203df3";

    // Create3 deployer
    AccessControlledDeployer accessControlledDeployer;
    OwnableCreate3Deployer create3DeployerFactory;

    // Passport relayer Ethereum transaction signing key.
    address public relayer;
    uint256 public relayerPKey;

    // Immutable signing key for blob.
    address public passportSigner;
    uint256 public passportSignerPKey;

    // Passport wallet nonces, based on the counter factual address.
    mapping(address => uint256) nonces;

    // Passport wallet nonces addresses to access all
    address[] public noncesAddresses;

    // Passport wallet.
    Factory private walletFactory;
    MultiCallDeploy private multiCallDeploy;
    LatestWalletImplLocator private latestWalletImplLocator;
    StartupWalletImpl private startupWallet;
    MainModuleDynamicAuth private mainModuleDynamicAuth;
    ImmutableSigner private immutableSigner;

    // Seaport
    ConduitController seaportConduitController;
    ImmutableSeaport seaport;

    function installCreate3Deployer() internal {
        vm.startBroadcast(deployerPKey);
        accessControlledDeployer = new AccessControlledDeployer(
            admin,
            admin,
            admin,
            admin
        );
        vm.writeLine(path, "AccessControlledDeployer deployed to address");
        vm.writeLine(
            path,
            Strings.toHexString(address(accessControlledDeployer))
        );

        create3DeployerFactory = new OwnableCreate3Deployer(
            address(accessControlledDeployer)
        );
        vm.writeLine(path, "OwnableCreate3Deployer deployed to address");
        vm.writeLine(
            path,
            Strings.toHexString(address(create3DeployerFactory))
        );
        vm.stopBroadcast();

        address[] memory deployers = new address[](1);
        deployers[0] = deployer;
        vm.startBroadcast(adminPKey);
        accessControlledDeployer.grantDeployerRole(deployers);
        vm.stopBroadcast();
    }

    function loadCreate3Deployer() internal {
        vm.readLine(path); // Discard line: AccessControlledDeployer deployed to address
        accessControlledDeployer = AccessControlledDeployer(
            vm.parseAddress(vm.readLine(path))
        );
        console.logString("Loaded accessControlledDeployer as");
        console.logAddress(address(accessControlledDeployer));

        vm.readLine(path); // Discard line: OwnableCreate3Deployer deployed to address
        create3DeployerFactory = OwnableCreate3Deployer(
            vm.parseAddress(vm.readLine(path))
        );
        console.logString("Loaded create3DeployerFactory as");
        console.logAddress(address(create3DeployerFactory));
    }

    function installPassportWallet() internal {
        vm.startBroadcast(deployerPKey);
        multiCallDeploy = new MultiCallDeploy(admin, relayer);
        vm.writeLine(path, "MultiCallDeploy deployed to address");
        vm.writeLine(path, Strings.toHexString(address(multiCallDeploy)));

        walletFactory = new Factory(admin, address(multiCallDeploy));
        vm.writeLine(path, "WalletFactory deployed to address");
        vm.writeLine(path, Strings.toHexString(address(walletFactory)));

        latestWalletImplLocator = new LatestWalletImplLocator(admin, admin);

        startupWallet = new StartupWalletImpl(address(latestWalletImplLocator));
        vm.writeLine(path, "StartupWallet deployed to address");
        vm.writeLine(path, Strings.toHexString(address(startupWallet)));

        mainModuleDynamicAuth = new MainModuleDynamicAuth(
            address(walletFactory),
            address(startupWallet)
        );
        vm.writeLine(path, "MainModuleDynamicAuth deployed to address");
        vm.writeLine(path, Strings.toHexString(address(mainModuleDynamicAuth)));

        immutableSigner = new ImmutableSigner(admin, admin, passportSigner);
        vm.writeLine(path, "ImmutableSigner deployed to address");
        vm.writeLine(path, Strings.toHexString(address(immutableSigner)));
        vm.stopBroadcast();

        vm.startBroadcast(adminPKey);
        latestWalletImplLocator.changeWalletImplementation(
            address(mainModuleDynamicAuth)
        );
        vm.stopBroadcast();
    }

    function loadPassportWalletContracts() internal {
        vm.readLine(path); // Discard line: MultiCallDeploy deployed to address
        multiCallDeploy = MultiCallDeploy(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded multiCallDeploy as");
        console.logAddress(address(multiCallDeploy));

        vm.readLine(path); // Discard line: WalletFactory deployed to address
        walletFactory = Factory(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded walletFactory as");
        console.logAddress(address(walletFactory));

        vm.readLine(path); // Discard line: StartupWallet deployed to address
        startupWallet = StartupWalletImpl(
            payable(vm.parseAddress(vm.readLine(path)))
        );
        console.logString("Loaded startupWallet as");
        console.logAddress(address(startupWallet));

        vm.readLine(path); // Discard line: MainModuleDynamicAuth deployed to address
        mainModuleDynamicAuth = MainModuleDynamicAuth(
            payable(vm.parseAddress(vm.readLine(path)))
        );
        console.logString("Loaded mainModuleDynamicAuth as");
        console.logAddress(address(mainModuleDynamicAuth));

        vm.readLine(path); // Discard line: ImmutableSigner deployed to address
        immutableSigner = ImmutableSigner(vm.parseAddress(vm.readLine(path)));
        console.logString("Loaded immutableSigner as");
        console.logAddress(address(immutableSigner));
    }

    function installSeaport() internal {
        vm.startBroadcast(deployerPKey);
        seaportConduitController = new ConduitController();
        vm.writeLine(path, "ConduitController deployed to address");
        vm.writeLine(
            path,
            Strings.toHexString(address(seaportConduitController))
        );

        bytes memory init = abi.encodePacked(
            WALLET_DEPLOY_CODE,
            uint256(uint160(address(seaportConduitController))),
            uint256(uint160(admin))
        );
        seaport = ImmutableSeaport(
            payable(
                accessControlledDeployer.deploy(
                    create3DeployerFactory,
                    init,
                    bytes32(0)
                )
            )
        );
        vm.writeLine(path, "ImmutableSeaper deployed to address");
        vm.writeLine(path, Strings.toHexString(address(seaport)));
        vm.stopBroadcast();
    }

    function loadSeaport() internal {
        vm.readLine(path); // Discard line: ConduitController deployed to address
        seaportConduitController = ConduitController(
            vm.parseAddress(vm.readLine(path))
        );
        console.logString("Loaded seaportConduitController as");
        console.logAddress(address(seaportConduitController));

        vm.readLine(path); // Discard line: ImmutableSeaport deployed to address
        seaport = ImmutableSeaport(payable(vm.parseAddress(vm.readLine(path))));
        console.logString("Loaded seaport as");
        console.logAddress(address(seaport));
    }

    // NOTE: Passport must be installed prior to calling this.
    function installRoyaltyAllowlist() internal {
        bytes memory initData = abi.encodeWithSelector(
            OperatorAllowlistUpgradeable.initialize.selector,
            admin,
            admin,
            admin
        );
        vm.startBroadcast(deployerPKey);
        OperatorAllowlistUpgradeable impl = new OperatorAllowlistUpgradeable();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        vm.stopBroadcast();
        royaltyAllowlist = OperatorAllowlistUpgradeable(address(proxy));

        // Execute a call which will cause a user's passport wallet to be deployed
        (address userMagic, uint256 userMagicPKey) = getNewPassportMagic();
        passportCall(
            userMagic,
            userMagicPKey,
            address(latestWalletImplLocator),
            abi.encodeWithSelector(
                latestWalletImplLocator.latestWalletImplementation.selector
            ),
            20000,
            0
        );
        address aWalletProxyContract = cfa(userMagic);

        // // Add all passport wallets to the royalty allowlist. That is, all contracts with the same
        // // bytecode as the passport wallet proxy contract deployed in the gem call above.
        vm.startBroadcast(adminPKey);
        royaltyAllowlist.addWalletToAllowlist(aWalletProxyContract);
        // TODO add seaport to allow list
        vm.stopBroadcast();
    }

    // ***************************************************
    // Code below manages accounts
    // ***************************************************
    uint256 public currentPassportPlayer;
    uint256 public newPassport; // Index for determining magic addresses for passport accounts that have not been deployed yet.
    address[] passportPlayersMagic; // Address is proxy for public key
    uint256[] passportPlayersMagicPKey; // Private key

    function getNewPassportMagic() internal returns (address, uint256) {
        // Deploye a new passport contract.
        bytes memory userStr = abi.encodePacked(
            "passport player",
            newPassport++
        );
        (address userMagic, uint256 userPKey) = makeAddrAndKey(string(userStr));
        passportPlayersMagic.push(userMagic);
        passportPlayersMagicPKey.push(userPKey);
        return (userMagic, userPKey);
    }

    function getDeployedPassportMagic() internal returns (address, uint256) {
        uint256 numDeployed = passportPlayersMagic.length;
        if (numDeployed == 0) {
            // If no passport wallets have been deployed yet, then a new passport
            // contract will need to be deployed.
            return getNewPassportMagic();
        }
        currentPassportPlayer = (currentPassportPlayer + 1) % numDeployed;
        return (
            passportPlayersMagic[currentPassportPlayer],
            passportPlayersMagicPKey[currentPassportPlayer]
        );
    }


    function savePassportPlayerMagicToFile() public{
        // string memory passportPlayerMagicPath = "./temp/passportPlayerMagic.txt";
        string memory passportPlayerMagicPath = string(abi.encodePacked(
            "./temp/passportPlayerMagic-",
            RUN_NAME,
            "-",
            treasuryAddress,
            ".txt"
        ));
        vm.writeFile(passportPlayerMagicPath, "");
        for (uint256 i = 0; i < passportPlayersMagic.length; i++) {
            vm.writeLine(passportPlayerMagicPath, Strings.toHexString(uint160(passportPlayersMagic[i])));
            vm.writeLine(passportPlayerMagicPath, Strings.toHexString(passportPlayersMagicPKey[i]));
        }
    }

    function loadPassportPlayerMagicFromFile() public{
        // string memory passportPlayerMagicPath = "./temp/passportPlayerMagic.txt";
        string memory passportPlayerMagicPath = string(abi.encodePacked(
            "./temp/passportPlayerMagic-",
            RUN_NAME,
            "-",
            treasuryAddress,
            ".txt"
        ));
        if (vm.exists(passportPlayerMagicPath)) {
            // read line by line and add to passportPlayersMagic
            string memory line = vm.readLine(passportPlayerMagicPath);
            while (bytes(line).length > 0) {
                address userMagic = vm.parseAddress(line);
                line = vm.readLine(passportPlayerMagicPath);
                uint256 userPKey = vm.parseUint(line);
                passportPlayersMagic.push(userMagic);
                passportPlayersMagicPKey.push(userPKey);
                line = vm.readLine(passportPlayerMagicPath);
            }
            newPassport = passportPlayersMagic.length;
            console.logString("Loaded passportPlayersMagic from file, newPassport: ");
            console.logUint(newPassport);
        }
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

    // How much gas should be given to passport transactions?
    uint256 private constant PASSPORT_TX_GAS = 100000;

    function passportMultiCall(
        address _userMagic,
        uint256 _userPKey,
        address[] memory _contracts,
        bytes[] memory _data
    ) internal {
        uint256 len = _contracts.length;
        uint256[] memory gas = new uint256[](len);
        uint256[] memory value = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            gas[i] = PASSPORT_TX_GAS;
            value[i] = 0;
        }
        passportMultiCall(_userMagic, _userPKey, _contracts, _data, gas, value);
    }

    function passportMultiCall(
        address _userMagic,
        uint256 _userPKey,
        address[] memory _contracts,
        bytes[] memory _data,
        uint256[] memory _gas,
        uint256[] memory _value
    ) internal {
        uint256 len = _contracts.length;
        require(len == _data.length, "Mismatched lengths");
        require(len == _gas.length, "Mismatched lengths");
        require(len == _value.length, "Mismatched lengths");
        IModuleCalls.Transaction[] memory txs = new IModuleCalls.Transaction[](
            _contracts.length
        );
        for (uint256 i = 0; i < len; i++) {
            IModuleCalls.Transaction memory transaction = IModuleCalls
                .Transaction({
                    delegateCall: false,
                    revertOnError: true,
                    gasLimit: _gas[i],
                    target: _contracts[i],
                    value: _value[i],
                    data: _data[i]
                });
            txs[i] = transaction;
        }

        bytes32 walletSalt = encodeImageHash(
            _userMagic,
            address(immutableSigner)
        );
        address walletCounterFactualAddress = addressOf(
            address(walletFactory),
            address(startupWallet),
            walletSalt
        );
        //here
        uint256 nonce = getNextNonce(walletCounterFactualAddress);
        bytes32 hashToBeSigned = encodeMetaTransactionsData(
            walletCounterFactualAddress,
            txs,
            nonce
        );

        bytes memory signature = walletMultiSign(
            _userMagic,
            _userPKey,
            hashToBeSigned
        );

        vm.startBroadcast(relayerPKey);
        multiCallDeploy.deployAndExecute(
            walletCounterFactualAddress,
            address(startupWallet),
            walletSalt,
            address(walletFactory),
            txs,
            nonce,
            signature
        );
        vm.stopBroadcast();
    }

    function passportCall(
        address _userMagic,
        uint256 _userPKey,
        address _contract,
        bytes memory _data
    ) internal {
        passportCall(
            _userMagic,
            _userPKey,
            _contract,
            _data,
            PASSPORT_TX_GAS,
            0
        );
    }

    function passportCall(
        address _userMagic,
        uint256 _userPKey,
        address _contract,
        bytes memory _data,
        uint256 _gas,
        uint256 _value
    ) internal {
        address[] memory contracts = new address[](1);
        contracts[0] = _contract;
        bytes[] memory data = new bytes[](1);
        data[0] = _data;
        uint256[] memory gas = new uint256[](1);
        gas[0] = _gas;
        uint256[] memory value = new uint256[](1);
        value[0] = _value;
        passportMultiCall(_userMagic, _userPKey, contracts, data, gas, value);
    }

    // Image hash can handle an aribtrary number of signers, with arbitrary weights and a threshold.
    // Simplify this to the usage we have: two signers, threshold two, equal weight.
    function encodeImageHash(
        address addrA,
        address addrB
    ) private pure returns (bytes32) {
        address addr1;
        address addr2;
        // Sort addresses so that we have a canonical form.
        if (uint160(addrA) > uint160(addrB)) {
            addr1 = addrA;
            addr2 = addrB;
        } else {
            addr2 = addrA;
            addr1 = addrB;
        }

        bytes32 imageHash = bytes32(uint256(THRESHOLD));

        imageHash = keccak256(abi.encode(imageHash, uint256(WEIGHT), addr1));
        imageHash = keccak256(abi.encode(imageHash, uint256(WEIGHT), addr2));
        return imageHash;
    }

    function cfa(address _userEOA) internal view returns (address) {
        bytes32 walletSalt = encodeImageHash(
            _userEOA,
            address(immutableSigner)
        );
        return
            addressOf(
                address(walletFactory),
                address(startupWallet),
                walletSalt
            );
    }

    function addressOf(
        address _factory,
        address _mainModule,
        bytes32 _imageHash
    ) private pure returns (address) {
        bytes32 aHash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                _factory,
                _imageHash,
                keccak256(
                    abi.encodePacked(
                        WALLET_DEPLOY_CODE,
                        uint256(uint160(_mainModule))
                    )
                )
            )
        );
        return address(uint160(uint256(aHash)));
    }

    function getNextNonce(address _cfa) private returns (uint256) {
        _addNonceAddressIfNotExists(_cfa);
        uint256 nonce = nonces[_cfa];
        nonces[_cfa] = nonce + 1;
        return nonce;
    }

    function _loadNonceFromFile(address _cfa) internal {
        string memory noncePath = string(
            abi.encodePacked(
                "./temp/nonce-",
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
            nonces[_cfa] = uint256(vm.parseUint(nonceStr));
        }
    }

    function loadAddressNonces() public {
        // string memory nonceAddressesPath = "./temp/noncesAddresses.txt";
        string memory nonceAddressesPath = string(abi.encodePacked(
            "./temp/noncesAddresses-",
            treasuryAddress,
            ".txt"
        ));
        if (vm.exists(nonceAddressesPath)) {
            // read line by line and add to noncesAddresses
            string memory line = vm.readLine(nonceAddressesPath);
            while (bytes(line).length > 0) {
                address cfa = vm.parseAddress(line);
                noncesAddresses.push(cfa);
                _loadNonceFromFile(cfa);
                line = vm.readLine(nonceAddressesPath);
            }
        }
    }

    function saveAddressNonces() public {
        string memory nonceAddressesPath = string(abi.encodePacked(
            "./temp/noncesAddresses-",
            treasuryAddress,
            ".txt"
        ));
        string memory noncePath;
        vm.writeFile(nonceAddressesPath, "");
        for (uint256 i = 0; i < noncesAddresses.length; i++) {
            noncePath = string(
                abi.encodePacked(
                    "./temp/nonce-",
                    Strings.toHexString(uint160(noncesAddresses[i]), 20),
                    "-",
                    RUN_NAME,
                    "-",
                    treasuryAddress,
                    ".txt"
                )
            );
            string memory line = Strings.toHexString(
                uint160(noncesAddresses[i]),
                20
            );
            vm.writeLine(nonceAddressesPath, line);
            vm.writeFile(
                noncePath,
                Strings.toHexString(nonces[noncesAddresses[i]])
            );
        }
    }

    function _addNonceAddressIfNotExists(address _cfa) internal {
        for (uint256 i = 0; i < noncesAddresses.length; i++) {
            if (noncesAddresses[i] == _cfa) {
                return;
            }
        }
        noncesAddresses.push(_cfa);
    }

    function encodeMetaTransactionsData(
        address _owner,
        IModuleCalls.Transaction[] memory _txs,
        uint256 _nonce
    ) private view returns (bytes32) {
        return _subDigest(_owner, keccak256(abi.encode(_nonce, _txs)));
    }

    function _subDigest(
        address _walletAddress,
        bytes32 _digest
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    block.chainid,
                    _walletAddress,
                    _digest
                )
            );
    }

    function walletMultiSign(
        address _userEOA,
        uint256 _userPKey,
        bytes32 _toBeSigned
    ) private view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            passportSignerPKey,
            _toBeSigned
        );
        bytes memory encodedSigPassportSigner = abi.encodePacked(
            r,
            s,
            v,
            SIG_TYPE_EIP712,
            SIG_TYPE_WALLET_BYTES32
        );

        (v, r, s) = vm.sign(_userPKey, _toBeSigned);
        bytes memory encodedSigUser = abi.encodePacked(
            r,
            s,
            v,
            SIG_TYPE_EIP712
        );

        // Sort addresses so that we have a canonical form.
        if (uint160(_userEOA) > uint160(address(immutableSigner))) {
            return
                abi.encodePacked(
                    THRESHOLD,
                    FLAG_SIGNATURE,
                    WEIGHT,
                    encodedSigUser,
                    FLAG_DYNAMIC_SIGNATURE,
                    WEIGHT,
                    address(immutableSigner),
                    uint16(encodedSigPassportSigner.length),
                    encodedSigPassportSigner
                );
        } else {
            return
                abi.encodePacked(
                    THRESHOLD,
                    FLAG_DYNAMIC_SIGNATURE,
                    WEIGHT,
                    address(immutableSigner),
                    uint16(encodedSigPassportSigner.length),
                    encodedSigPassportSigner,
                    FLAG_SIGNATURE,
                    WEIGHT,
                    encodedSigUser
                );
        }
    }
}
