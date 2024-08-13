pragma solidity ^0.8;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


contract BSUProxy is TransparentUpgradeableProxy {
    constructor(address _logic, address _admin, bytes memory _data)
        TransparentUpgradeableProxy(_logic, _admin, _data)
    {}
}
