// Contract code copied from: https://explorer.immutable.com/address/0x04Eb90B9AE5Be1a0130B2239bE735F916064a810?tab=contract

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract StudioSignature {
  using ECDSA for bytes32; 

  /// @dev Holds used signatures
  mapping(bytes => bool) private _usedSignatures;
  
  /// @dev Holds addresses that can sign messages
  mapping(address => bool) internal _trustedAddresses;

  /// @notice Changes if an account is trusted
  /// @param account Address of the user
  /// @param isTrusted If user is truested
  function _setTrusted(address account, bool isTrusted) internal {
    _trustedAddresses[account] = isTrusted;
  }

  /// @notice Verifies a signature, if it's right uses it
  ///   otherwise returns false
  /// @param signer Signing address
  /// @param message Signed message
  /// @param signature Signature
  /// @return Success
  function _useSignature(
    address signer,
    bytes memory message,
    bytes memory signature
  ) internal returns(bool) 
  {
    require(_trustedAddresses[signer], "SIGNER_NOT_TRUSTED");
    require(!_usedSignatures[signature], "SIGNATURE_ALREADY_USED");
    
    bytes32 messagehash =  keccak256(message);
    address recoveredAddress = messagehash.toEthSignedMessageHash().recover(signature);
              
    // If signature is not valid return false
    if (recoveredAddress != signer) {
      return false;
    }

    // Else, mark signature as used and return true
    _usedSignatures[signature] = true;
    return true;
  }
}