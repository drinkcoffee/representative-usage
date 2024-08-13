pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract SpaceTrekClaim is Ownable {
    using ECDSA for bytes32;
    uint256 expireTime = 5 minutes;
    address signer = 0xDa801D3cCE8626Bd55387554Bb3BE500681Cb49C;
    mapping(uint64 => bool) private _sigvalue;
    mapping(address => uint256) private lotteries;
    error InvalidSigParameters();

    event userOperation(
        address indexed sender,
        uint256 indexed types,
        uint256 indexed signId
    );

    modifier onlySigner() {
        require(_msgSender() == signer, "ONLY_MANAGER_ROLE");
        _;
    }

    constructor() {}

    //A player could receive one ticket with a valid signature
    function recprize(
        uint256[] memory ids,
        uint256[] memory values,
        uint64 timestamp,
        uint64 uuid,
        uint64 signId,
        bytes memory sig
    ) external {
        assertValidCosign(0, ids, values, timestamp, uuid, signId, sig);
        bool res = ids.length == 1 && ids[0] == 0 && values[0] != 0;
        if (!res) {
            revert InvalidSigParameters();
        }
        lotteries[_msgSender()] += values[0];
        emit userOperation(_msgSender(), 0, signId);
    }

    // A player could consume one ticket with a valid signature
    function raffle(
        uint256[] memory ids,
        uint256[] memory values,
        uint64 timestamp,
        uint64 uuid,
        uint64 signId,
        bytes memory sig
    ) external {
        assertValidCosign(1, ids, values, timestamp, uuid, signId, sig);
        bool res = ids.length == 1 && ids[0] == 0 && values[0] != 0;
        if (!res) {
            revert InvalidSigParameters();
        }
        lotteries[_msgSender()] -= values[0];
        emit userOperation(_msgSender(), 1, signId);
    }

    function updateSigner(address newSigner) external onlyOwner {
        signer = newSigner;
    }

    function updateExpiration(uint256 newexpireTime) external onlyOwner {
        expireTime = newexpireTime;
    }

    /**
     * @dev Returns chain id.
     */
    function _chainID() private view returns (uint32) {
        uint32 chainID;
        assembly {
            chainID := chainid()
        }
        return chainID;
    }

    function assertValidCosign(
        uint32 types,
        uint256[] memory ids,
        uint256[] memory values,
        uint64 timestamp,
        uint64 uuid,
        uint64 signId,
        bytes memory sig
    ) private returns (bool) {
        require(ids.length == values.length, "Invalid_array");
        bytes32 hash = keccak256(
            abi.encodePacked(
                types,
                _chainID(),
                timestamp,
                uuid,
                signId,
                _msgSender(),
                address(this),
                ids,
                values
            )
        );
        require(matchSigner(hash, sig), "Invalid_Signature");
        if (timestamp != 0) {
            require((expireTime + timestamp >= block.timestamp), "HAS_Expired");
        }
        require((!_sigvalue[uuid]), "HAS_USED");
        _sigvalue[uuid] = true;
        return true;
    }

    function matchSigner(bytes32 hash, bytes memory signature)
        private
        view
        returns (bool)
    {
        return signer == hash.toEthSignedMessageHash().recover(signature);
    }

    function getLotteris() external view returns (uint256) {
        return lotteries[_msgSender()];
    }

    function getLotteris(address addr)
        external
        view
        onlySigner
        returns (uint256)
    {
        return lotteries[addr];
    }
}
