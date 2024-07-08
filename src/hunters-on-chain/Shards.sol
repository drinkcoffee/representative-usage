// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import '../im-contracts/token/erc1155/preset/ImmutableERC1155.sol';
import "@openzeppelin/contracts/utils/Strings.sol";

//	███████╗██╗  ██╗ █████╗ ██████╗ ██████╗ ███████╗
//	██╔════╝██║  ██║██╔══██╗██╔══██╗██╔══██╗██╔════╝
//	███████╗███████║███████║██████╔╝██║  ██║███████╗
//	╚════██║██╔══██║██╔══██║██╔══██╗██║  ██║╚════██║
//	███████║██║  ██║██║  ██║██║  ██║██████╔╝███████║
//	╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝

/// @notice Contract for Hunters OnChain hunter shards
/// @author zetsub0ii.eth
contract Shards is ImmutableERC1155 {
    using Strings for uint256;

    ////////////////////////////////////////////////////////////////////////////
    // Constants
    ////////////////////////////////////////////////////////////////////////////

    bytes32 constant LOCKER_ROLE = keccak256("LOCKER_ROLE");
    bytes32 constant METADATA_ROLE = keccak256("METADATA_ROLE");

    ////////////////////////////////////////////////////////////////////////////
    // Storage
    ////////////////////////////////////////////////////////////////////////////

    address private defaultAdmin;
    address private assignedDefaultAdmin = address(0x0);

    // ID -> Account -> Locked Amount
    mapping(uint256 => mapping(address => uint256)) public lockedShards;

    ////////////////////////////////////////////////////////////////////////////
    // Constants
    ////////////////////////////////////////////////////////////////////////////

    event ShardLocked(address account, uint256 id, uint256 amount);
    event ShardUnlocked(address account, uint256 id, uint256 amount);

    event DefaultAdminTransferStarted(address oldAdmin, address newAdmin);
    event DefaultAdminTransferred(address oldAdmin, address newAdmin);

    ////////////////////////////////////////////////////////////////////////////
    // Constructor
    ////////////////////////////////////////////////////////////////////////////

    constructor(address admin, address minter, address locker, address _royaltyReceiver,
     uint96 _royaltyPercentage,
     string memory baseURI,
     string memory contractURI, 
     address royaltyAllowlist)
            ImmutableERC1155(
            admin,
            "Shard",
            baseURI,
            contractURI,
            royaltyAllowlist,
            _royaltyReceiver,
            _royaltyPercentage
        ) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);

        _setupRole(MINTER_ROLE, minter);
        _setupRole(LOCKER_ROLE, locker);
        _setupRole(METADATA_ROLE, admin);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Locking logic
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Locks given amount of shards
    /// @dev Requires LOCKER_ROLE
    /// @param account   Owner of the shards
    /// @param id        ID of shard
    /// @param amount    Amount to lock
    function increaseLocked(address account, uint256 id, uint256 amount) external onlyRole(LOCKER_ROLE) {
        // Check if user has enough items to lock
        require(balanceOf(account, id) >= amount, "Not enough shards");

        _increaseLocked(account, id, amount);
    }

    /// @notice Locks shards in batch
    /// @dev Requires LOCKER_ROLE
    /// @param account   Owner of the shards
    /// @param ids       ID list
    /// @param amounts   Amount list
    function increaseLockedBatch(address account, uint256[] calldata ids, uint256[] calldata amounts)
        external
        onlyRole(LOCKER_ROLE)
    {
        require(ids.length == amounts.length, "Length mismatch");

        uint256 length = amounts.length;
        for (uint256 i = 0; i < length;) {
            require(balanceOf(account, ids[i]) >= amounts[i], "Not enough shards");

            _increaseLocked(account, ids[i], amounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Unlocks given amount of shards
    /// @dev Requires LOCKER_ROLE
    /// @param account   Owner of the shards
    /// @param id        ID of shard
    /// @param amount    Amount to unlock
    function decreaseLocked(address account, uint256 id, uint256 amount) external onlyRole(LOCKER_ROLE) {
        _decreaseLocked(account, id, amount);
    }

    /// @notice Unlocks shards in batch
    /// @dev Requires LOCKER_ROLE
    /// @param account   Owner of the shards
    /// @param ids       ID list
    /// @param amounts   Amount list
    function decreaseLockedBatch(address account, uint256[] calldata ids, uint256[] calldata amounts)
        external
        onlyRole(LOCKER_ROLE)
    {
        require(ids.length == amounts.length, "Length mismatch");

        uint256 length = amounts.length;
        for (uint256 i = 0; i < length;) {
            require(balanceOf(account, ids[i]) >= amounts[i], "Not enough shards");

            _decreaseLocked(account, ids[i], amounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Internal method for locking
    function _increaseLocked(address account, uint256 id, uint256 amount) private {
        lockedShards[id][account] += amount;
        emit ShardLocked(account, id, amount);
    }

    /// @dev Internal method for unlocking
    function _decreaseLocked(address account, uint256 id, uint256 amount) private {
        lockedShards[id][account] -= amount;
        emit ShardUnlocked(account, id, amount);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Overrides
    ////////////////////////////////////////////////////////////////////////////

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        // If we're not minting
        if (from != address(0x0)) {
            // Check available balance, then make transfer
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];
                uint256 amount = amounts[i];

                uint256 availableBalance = balanceOf(from, id) - lockedShards[id][from];
                require(availableBalance >= amount, "Not enough unlocked");
            }
        }

        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
   
    ////////////////////////////////////////////////////////////////////////////
    // Default admin transfer logic
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Initiates a request to transfer DEFAULT_ADMIN_ROLE
    /// @param _newAdmin New admin
    /// @dev This won't be used unless one of the default admins is compromised
    function transferDefaultAdmin(address _newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newAdmin != address(0x0), "New admin cannot be 0x0");
        require(_newAdmin != assignedDefaultAdmin, "New admin cannot be the same as the old one");

        assignedDefaultAdmin = _newAdmin;
        defaultAdmin = msg.sender;
        emit DefaultAdminTransferStarted(msg.sender, _newAdmin);
    }

    /// @notice Cancels a request to transfer DEFAULT_ADMIN_ROLE
    function cancelDefaultAdminTransfer() external onlyRole(DEFAULT_ADMIN_ROLE) {
        assignedDefaultAdmin = address(0x0);
    }

    /// @notice Claims DEFAULT_ADMIN_ROLE
    /// @dev If user doesn't claim the role, default admin doesn't change
    function claimDefaultAdmin() external {
        require(msg.sender == assignedDefaultAdmin, "You are not assigned to be the new default admin");

        _grantRole(DEFAULT_ADMIN_ROLE, assignedDefaultAdmin);
        _revokeRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        emit DefaultAdminTransferred(defaultAdmin, assignedDefaultAdmin);

        assignedDefaultAdmin = address(0x0);
        defaultAdmin = msg.sender;
    }
}
