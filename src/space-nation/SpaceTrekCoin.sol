pragma solidity ^0.8;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ImmutableERC1155} from "../im-contracts/token/erc1155/preset/ImmutableERC1155.sol";

contract SpaceTrekCoin is ImmutableERC1155 {
    using ECDSA for bytes32;
    uint256 expireTime = 5 minutes;
    uint256 endTime;
    address signer = 0xDa801D3cCE8626Bd55387554Bb3BE500681Cb49C;
    string _name;
    mapping(uint64 => bool) private _sigvalue;
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

    constructor(
        address owner,
        string memory name_,
        string memory baseURI_,
        string memory contractURI_,
        address _operatorAllowlist,
        address _receiver,
        uint96 _feeNumerator
    )
        ImmutableERC1155(
            owner,
            name_,
            baseURI_,
            contractURI_,
            _operatorAllowlist,
            _receiver,
            _feeNumerator
        )
    {
        grantMinterRole(0xbb7ee21AAaF65a1ba9B05dEe234c5603C498939E);
        _name = name_;
    }

    function uri(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return
            bytes(baseURI()).length != 0
                ? string(abi.encodePacked(baseURI(), _toString(id)))
                : "";
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function _toString(uint256 value) private pure returns (string memory str) {
        assembly {
            let m := add(mload(0x40), 0xa0)
            mstore(0x40, m)
            str := sub(m, 0x20)
            mstore(str, 0)
            let end := str
            for {
                let temp := value
            } 1 {

            } {
                str := sub(str, 1)
                mstore8(str, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                if iszero(temp) {
                    break
                }
            }
            let length := sub(end, str)
            str := sub(str, 0x20)
            mstore(str, length)
        }
    }

    // The player could mint one/more nfts through their passport with a valid signature
    function usermint(
        uint256[] memory ids,
        uint256[] memory values,
        uint64 timestamp,
        uint64 uuid,
        uint64 signId,
        bytes memory sig
    ) external {
        assertValidCosign(2, ids, values, timestamp, uuid, signId, sig);
        super._mintBatch(_msgSender(), ids, values, "");
        emit userOperation(_msgSender(), 2, signId);
    }

    //  The player can exchange rewards by combining various types of NFTs with a valid signature.
    function redeem(
        uint256[] memory ids,
        uint256[] memory values,
        uint64 timestamp,
        uint64 uuid,
        uint64 signId,
        bytes memory sig
    ) external {
        assertValidCosign(3, ids, values, timestamp, uuid, signId, sig);
        burnBatch(_msgSender(), ids, values);
        emit userOperation(_msgSender(), 3, signId);
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(block.timestamp < endTime, "Activity has ended");
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function updateSigner(address newSigner)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        signer = newSigner;
    }

    function updateExpiration(uint256 newexpireTime)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        expireTime = newexpireTime;
    }

    function updateEndts(uint256 newEndts)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        endTime = newEndts;
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
}