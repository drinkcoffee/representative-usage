// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import "./ModuleSelfAuth.sol";
import "./ModuleStorage.sol";
import "./ModuleERC165.sol";
import "./NonceKey.sol";

import "./interfaces/IModuleCalls.sol";
import "./interfaces/IModuleAuth.sol";


abstract contract ModuleCalls is IModuleCalls, IModuleAuth, ModuleERC165, ModuleSelfAuth {
  uint256 private constant NONCE_BITS = 96;
  bytes32 private constant NONCE_MASK = bytes32((1 << NONCE_BITS) - 1);

  /**
   * @notice Returns the next nonce of the default nonce space
   * @dev The default nonce space is 0x00
   * @return The next nonce
   */
  function nonce() external override virtual view returns (uint256) {
    return readNonce(0);
  }

  /**
   * @notice Returns the next nonce of the given nonce space
   * @param _space Nonce space, each space keeps an independent nonce count
   * @return The next nonce
   */
  function readNonce(uint256 _space) public override virtual view returns (uint256) {
    return uint256(ModuleStorage.readBytes32Map(NonceKey.NONCE_KEY, bytes32(_space)));
  }

  /**
   * @notice Changes the next nonce of the given nonce space
   * @param _space Nonce space, each space keeps an independent nonce count
   * @param _nonce Nonce to write on the space
   */
  function _writeNonce(uint256 _space, uint256 _nonce) private {
    ModuleStorage.writeBytes32Map(NonceKey.NONCE_KEY, bytes32(_space), bytes32(_nonce));
  }

  /**
   * @notice Allow wallet owner to execute an action
   * @dev Relayers must ensure that the gasLimit specified for each transaction
   *      is acceptable to them. A user could specify large enough that it could
   *      consume all the gas available.
   * @param _txs        Transactions to process
   * @param _nonce      Signature nonce (may contain an encoded space)
   * @param _signature  Encoded signature
   */
  function execute(
    Transaction[] memory _txs,
    uint256 _nonce,
    bytes memory _signature
  ) public override virtual {
    // Validate and update nonce
    _validateNonce(_nonce);

    // Hash transaction bundle
    bytes32 txHash = _subDigest(keccak256(abi.encode(_nonce, _txs)));

    // Verify that signatures are valid
    require(
      _signatureValidation(txHash, _signature),
      "ModuleCalls#execute: INVALID_SIGNATURE"
    );

    // Execute the transactions
    _execute(txHash, _txs);
  }

  /**
   * @notice Allow wallet to execute an action
   *   without signing the message
   * @param _txs  Transactions to execute
   */
  function selfExecute(
    Transaction[] memory _txs
  ) public override virtual onlySelf {
    // Hash transaction bundle
    bytes32 txHash = _subDigest(keccak256(abi.encode('self:', _txs)));

    // Execute the transactions
    _execute(txHash, _txs);
  }

// TODO NOTE Peter added code start
// Added some debug to help work out when the gas specified for the passport
// transaction is more than the remaining gas.

    bytes16 private constant HEX_DIGITS = "0123456789abcdef";

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, 32);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }
// TODO NOTE Peter added code end


  /**
   * @notice Executes a list of transactions
   * @param _txHash  Hash of the batch of transactions
   * @param _txs  Transactions to execute
   */
  function _execute(
    bytes32 _txHash,
    Transaction[] memory _txs
  ) private {
    // Execute transaction
    for (uint256 i = 0; i < _txs.length; i++) {
      Transaction memory transaction = _txs[i];

      bool success;
      bytes memory result;

// TODO NOTE Peter added code start

      if (gasleft() < transaction.gasLimit) {
        // Use this form of error throwing so that Anvil displays the error message.
        // Anvil is not compatible with new Solidity typed error messages.
        uint256 gasLeft = gasleft();
        string memory a = toHexString(gasLeft);
        string memory b = toHexString(transaction.gasLimit);
        revert (string(abi.encodePacked(
          "Passport ModuleCalls:_execute failing: gasleft < transaction.gasLimit: ",
          "gasleft ", a, 
          ", tx.gaslimit ", b)));
      }
// TODO NOTE Peter added code end

//      require(gasleft() >= transaction.gasLimit, "ModuleCalls#_execute: NOT_ENOUGH_GAS");

      if (transaction.delegateCall) {
        (success, result) = transaction.target.delegatecall{
          gas: transaction.gasLimit == 0 ? gasleft() : transaction.gasLimit
        }(transaction.data);
      } else {
        (success, result) = transaction.target.call{
          value: transaction.value,
          gas: transaction.gasLimit == 0 ? gasleft() : transaction.gasLimit
        }(transaction.data);
      }

      if (success) {
        emit TxExecuted(_txHash);
      } else {
        _revertBytes(transaction, _txHash, result);
      }
    }
  }

  /**
   * @notice Verify if a nonce is valid
   * @param _rawNonce Nonce to validate (may contain an encoded space)
   * @dev A valid nonce must be above the last one used
   *   with a maximum delta of 100
   */
  function _validateNonce(uint256 _rawNonce) private {
    // Retrieve current nonce for this wallet
    (uint256 space, uint256 providedNonce) = _decodeNonce(_rawNonce);
    uint256 currentNonce = readNonce(space);

    // Verify if nonce is valid
    require(
      providedNonce == currentNonce,
      "MainModule#_auth: INVALID_NONCE"
    );

    // Update signature nonce
    uint256 newNonce = providedNonce + 1;
    _writeNonce(space, newNonce);
    emit NonceChange(space, newNonce);
  }

  /**
   * @notice Logs a failed transaction, reverts if the transaction is not optional
   * @param _tx      Transaction that is reverting
   * @param _txHash  Hash of the transaction
   * @param _reason  Encoded revert message
   */
  function _revertBytes(
    Transaction memory _tx,
    bytes32 _txHash,
    bytes memory _reason
  ) internal {
    if (_tx.revertOnError) {
      assembly { revert(add(_reason, 0x20), mload(_reason)) }
    } else {
      emit TxFailed(_txHash, _reason);
    }
  }

  /**
   * @notice Decodes a raw nonce
   * @dev A raw nonce is encoded using the first 160 bits for the space
   *  and the last 96 bits for the nonce
   * @param _rawNonce Nonce to be decoded
   * @return _space The nonce space of the raw nonce
   * @return _nonce The nonce of the raw nonce
   */
  function _decodeNonce(uint256 _rawNonce) private pure returns (uint256 _space, uint256 _nonce) {
    _nonce = uint256(bytes32(_rawNonce) & NONCE_MASK);
    _space = _rawNonce >> NONCE_BITS;
  }

  /**
   * @notice Query if a contract implements an interface
   * @param _interfaceID The interface identifier, as specified in ERC-165
   * @return `true` if the contract implements `_interfaceID`
   */
  function supportsInterface(bytes4 _interfaceID) public override virtual pure returns (bool) {
    if (_interfaceID == type(IModuleCalls).interfaceId) {
      return true;
    }

    return super.supportsInterface(_interfaceID);
  }
}
