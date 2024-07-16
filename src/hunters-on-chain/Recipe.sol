// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

interface IBoom {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IBgem {
    function mint(address to, uint256 amount) external;

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IMintable1155 {
    function safeMint(address account, uint256 id, uint256 amount, bytes memory data) external;

    function safeMintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function burn(address account, uint256 id, uint256 value) external;

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) external;
}

import "./StudioSignature.sol";

struct RecipeSignature {
    uint32 chainId; // To prevent crosschain signature attacks
    bytes32 request; // Hash of the request name
    bytes payload; // Data that is actually signed
    bytes signature; // Signature
}

bytes32 constant UPGRADE_REQUEST = keccak256("Upgrade");
bytes32 constant APPLY_ARTIFACT_REQUEST = keccak256("ApplyArtifact");

/// @title Recipe
/// @notice Handles batch transfers (recipes) specified by the owner
/// @dev This way we can ensure each recipe happens atomatically (All or nothing)
/// @dev Recipes use user on the signed data so they can be executed by
///      someone else if needed
contract Recipe is Ownable, StudioSignature {
    uint32 private immutable chainId;
    IBgem public bgem;
    IBoom public boom;
    IMintable1155 public perks;
    IMintable1155 public shards;
    IMintable1155 public equipments;
    address private studio;
    address private paymentReceiver;

    struct IChestConfig {
        uint256 estimatedGas;
        uint256 multiplier;
        uint256 bgemPrice;
        bool enabled;
    }

    /// @notice Chest configs
    mapping(uint256 => IChestConfig) public chestConfig;

    function setBgem(address newBgem) external onlyOwner {
        bgem = IBgem(newBgem);
    }

    function setBoom(address newBoom) external onlyOwner {
        boom = IBoom(newBoom);
    }

    function setPerks(address newPerks) external onlyOwner {
        perks = IMintable1155(newPerks);
    }

    function setShards(address newShards) external onlyOwner {
        shards = IMintable1155(newShards);
    }

    function setEquipments(address newEquipments) external onlyOwner {
        equipments = IMintable1155(newEquipments);
    }

    event ChestOpened(uint256 chestId, address indexed account);
    event UpgradeSuccess(address indexed account, uint256 hunterId, uint256 level);
    event ApplyArtifactSuccess(
        address indexed account,
        uint256 artifactId,
        uint256 hunterId,
        uint256 slot
    );

    ////////////////////////////////////////////////////////////////////////////
    // Constructor
    ////////////////////////////////////////////////////////////////////////////

    constructor(
        uint32 _chainId,
        address _studio,
        address _paymentReceiver,
        IBgem _bgem,
        IBoom _boom,
        IMintable1155 _perks,
        IMintable1155 _equipments,
        IMintable1155 _shards
    ) {
        require(_studio != address(0), "Invalid studio");
        studio = _studio;

        chainId = _chainId;
        bgem = _bgem;
        boom = _boom;
        perks = _perks;
        shards = _shards;
        equipments = _equipments;
        paymentReceiver = _paymentReceiver;
        // Set deployer trusted for signing packets
        _setTrusted(_studio, true);
    }


    ////////////////////////////////////////////////////////////////////////////
    // Setters
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Sets a new studio
    function setStudio(address newStudio) external onlyOwner {
        require(newStudio != address(0), "Invalid studio");
        studio = newStudio;
    }

    function setTrusted(address account, bool isTrusted) external onlyOwner {
        _setTrusted(account, isTrusted);
    }

    function setChestConfig(uint256 chestId, IChestConfig calldata config) external onlyOwner {
        chestConfig[chestId] = config;
    }

    function setPaymentReceiver(address _receiver) external onlyOwner {
        paymentReceiver = _receiver;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Recipes
    ////////////////////////////////////////////////////////////////////////////

    function openChest(
        uint256 chestId
    ) external payable  {
        
        IChestConfig memory config = chestConfig[chestId];

        require(config.enabled, "Chest does not exist");
        require(msg.value >= (config.estimatedGas * tx.gasprice * config.multiplier), "Matic amount lower than expected");

        (bool sent,) = paymentReceiver.call{value: msg.value}("");

        require(sent, "Failed to send Ether");
        require(bgem.transferFrom(msg.sender, studio, config.bgemPrice), "Bgem transfer failed");

        emit ChestOpened(chestId, msg.sender);
    }

    /// @notice Takes Boom and Shards from user, emits Event to trigger an upgrade
    /// @param packet Packet signed by the owner
    /// @dev packet has these information
    ///      user           address
    ///      nftId          uint256
    ///      inBoom         uint256
    ///      inShardIds     uint256[]
    ///      inShardAmounts uint256[]
    ///      expiresAt      uint256
    ///      nonce          uint32
    ///
    /// @dev For example if user has to pay 100 BOOMs and 5 of SHARDs with ID 3,
    ///      we'd have the packet:
    ///      (user, 100, [3], [5])
    /// @dev Emits {UpgradeSuccess}
    function upgrade(RecipeSignature calldata packet) external {
        require(packet.chainId == chainId, "Invalid chain ID");
        require(packet.request == UPGRADE_REQUEST, "Invalid request");
        require(_useSignature(studio, packet.payload, packet.signature), "Invalid signature");

        bytes memory decodedPayload = _xorBytes(packet.payload, address(this));

        (
            address user,
            uint256 nftId,
            uint256 inBoom,
            uint256[] memory inShardIds,
            uint256[] memory inShardAmounts,
            uint256 expiresAt,
            uint256 level,

        ) = abi.decode(
                decodedPayload,
                (address, uint256, uint256, uint256[], uint256[], uint256, uint256, uint32)
            );

        require((expiresAt == 0) || block.timestamp > expiresAt, "Signature expired");

        emit UpgradeSuccess(user, nftId, level);

        // IN - Booms
        if(inBoom > 0){
            boom.transferFrom(user, studio, inBoom);    
        }

        // IN - Shards
        shards.burnBatch(user, inShardIds, inShardAmounts);
    }

    /// @notice Applies artifact to hunter
    /// @param packet Packet signed by the owner
    /// @dev packet has these information
    ///      user         address
    ///      hunterId     uint256
    ///      artifactId   uint256
    ///      slot         uint256
    ///      expiresAt    uint256
    ///      nonce        uint32
    /// @dev Emits {ApplyArtifactSuccess}
    /// @dev Function burns the provided artifact
    function applyArtifact(RecipeSignature calldata packet) external {
        require(packet.chainId == chainId, "Invalid chain ID");
        require(packet.request == APPLY_ARTIFACT_REQUEST, "Invalid request");
        require(_useSignature(studio, packet.payload, packet.signature), "Invalid signature");

        bytes memory decodedPayload = _xorBytes(packet.payload, address(this));

        (
            address user,
            uint256 hunterId,
            uint256 artifactId,
            uint256 slot,
            uint256 expiresAt,

        ) = abi.decode(decodedPayload, (address, uint256, uint256, uint256, uint256, uint32));

        require((expiresAt == 0) || block.timestamp > expiresAt, "Signature expired");

        emit ApplyArtifactSuccess(user, artifactId, hunterId, slot);

        // IN - Burn artifacts
        perks.burn(user, artifactId, 1);
    }

    /// @notice XOR bytes with address
    /// @param target Target bytes
    /// @param caller Caller address
    /// @dev Caller address is converted to bytes32 and XORed with target bytes
    function _xorBytes(
        bytes memory target,
        address caller
    ) internal pure returns (bytes memory out) {
        bytes32 caller_bytes32 = bytes32(uint256(uint160(caller)));

        out = new bytes(target.length);
        for (uint256 i = 0; i < target.length; i += 32) {
            bytes32 m;

            assembly {
                m := xor(mload(add(add(i, 32), target)), caller_bytes32)
            }

            uint256 chunk = target.length - i > 32 ? 32 : target.length - i;
            for (uint256 j = 0; j < chunk; j++) {
                out[i + j] = m[j];
            }
        }
    }

    function xorBytes(
        bytes memory target,
        address caller
    ) external pure returns (bytes memory out) {
        out = _xorBytes(target, caller);
    }
}
