// Code from: https://explorer.immutable.com/address/0x3A4064059CE41975400f9307339628D94aB9DF89?tab=contract

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./Nonces.sol";

interface IBgem {
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @author gfialho
/// @title Claim contract
contract BgemClaim is Ownable, Nonces, EIP712 {
    IBgem public bgem;
    address private studio;

    bytes32 constant EIP712_CLAIM_TYPEHASH = keccak256(
        "EIP712Claim(uint256 amount,address wallet,uint48 gameId,uint256 nonce)"
    );

    struct EIP712Claim {
        uint256 amount;
        address wallet;
        uint48 gameId;
        uint256 nonce;
    }

    event Claimed(address indexed account, uint256 amount, uint48 gameId);

    ////////////////////////////////////////////////////////////////////////////
    // Constructor
    ////////////////////////////////////////////////////////////////////////////
    constructor(address _owner, IBgem _bgem, address _studio) Ownable() EIP712("Boomland Claim", "1") {
        bgem = _bgem;
        studio = _studio;
        _transferOwnership(_owner);
    }

    function setBgem(address newBgem) external onlyOwner {
        bgem = IBgem(newBgem);
    }

    function setStudio(address _studio) external onlyOwner {
        studio = _studio;
    }

    function withdraw(uint256 amount) external payable onlyOwner {
        require(bgem.transfer(studio, amount), "Failed to transfer");
    }

    function claim(EIP712Claim calldata _data, bytes calldata _signature) external {
        require(verifyStudioSignature(_data, _signature), "Invalid signature");

        require(bgem.transfer(msg.sender, _data.amount), "Bgem transfer failed");
        _useCheckedNonce(msg.sender, _data.nonce);
    }

    function verifyStudioSignature(EIP712Claim calldata _data, bytes calldata _signature)
        internal
        view
        returns (bool)
    {

        bytes32 structHash = hashListingStruct(_data);

        return SignatureChecker.isValidSignatureNow(studio, structHash, _signature);
    }

    function hashListingStruct(EIP712Claim calldata _data) internal view returns (bytes32 structHash) {
        structHash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    EIP712_CLAIM_TYPEHASH,
                    _data.amount,
                    _data.wallet,
                    _data.gameId,
                    _data.nonce
                )
            )
        );
    }
}
