pragma solidity ^0.8;

import "openzeppelin-contracts-upgradeable-4.9.3/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable-4.9.3/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable-4.9.3/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable-4.9.3/security/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";



contract BSUStaking is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    address private masterSigner;
    address public contractAddress;
    bool public activeStake;

    struct Category {
        uint256 unlockTime;
        uint256 minimumStakeAmount;
        uint256 maxStakes;
    }

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 unlockTime;
    }

    mapping(address => mapping(uint256 => uint256)) public userStakeCount;

    mapping(address => mapping(uint256 => StakeInfo[])) public userStakes;
    mapping(address => mapping(uint256 => StakeInfo[])) public userUnstaked;

    mapping(uint256 => Category) public categories;

    mapping(address => mapping(uint256 => bool)) public dailyBoosts;
    mapping(address => mapping(uint256 => uint256)) public dailyBoostPoint;

    mapping(uint256 => mapping(address => uint256)) public totalStakes;

    event MasterSignerUpdated(address masterSigner);
    event CategoryAdded(uint256 indexed categoryIndex);
    event CategoryUpdated(uint256 indexed categoryIndex);
    event Staked(
        address indexed user,
        uint256 indexed categoryIndex,
        uint256 amount
    );
    event Unstaked(
        address indexed user,
        uint256 indexed categoryIndex,
        uint256 amount
    );
    event Withdrawn(address indexed to, uint256 amount);
    event ERC20Withdrawn(
        address indexed token,
        address indexed to,
        uint256 amount
    );
    event ActiveStakeUpdated(bool activeStake);
    event DailyBoosted(address indexed user);

    function initialize(address _masterSigner, address _contractAddress)
        public
        initializer
    {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        masterSigner = _masterSigner;
        contractAddress = _contractAddress;

        activeStake = true;
    }

    function setMasterSigner(address _masterSigner) external onlyOwner {
        masterSigner = _masterSigner;
        emit MasterSignerUpdated(_masterSigner);
    }

    function addCategory(
        uint256 categoryIndex,
        uint256 unlockTime,
        uint256 minimumStakeAmount,
        uint256 maxStakes
    ) external onlyOwner {
        categories[categoryIndex] = Category(
            unlockTime,
            minimumStakeAmount,
            maxStakes
        );
        emit CategoryAdded(categoryIndex);
    }

    function editCategory(
        uint256 categoryIndex,
        uint256 unlockTime,
        uint256 minimumStakeAmount,
        uint256 maxStakes
    ) external onlyOwner {
        categories[categoryIndex].unlockTime = unlockTime;
        categories[categoryIndex].minimumStakeAmount = minimumStakeAmount;
        categories[categoryIndex].maxStakes = maxStakes;
        emit CategoryUpdated(categoryIndex);
    }

    function setActiveStake(bool _activeStake) external onlyOwner {
        activeStake = _activeStake;
        emit ActiveStakeUpdated(_activeStake);
    }

    function stake(uint256 categoryIndex, uint256 amount, bytes calldata signature)
        external
        whenNotPaused
        nonReentrant
    {
        require(activeStake, "Staking is not active");
        require(
            amount >= categories[categoryIndex].minimumStakeAmount,
            "Amount less than minimum stake amount"
        );
        require(
            userStakeCount[msg.sender][categoryIndex] <
                categories[categoryIndex].maxStakes,
            "Stake limit reached for this category"
        );

        require(
            verifySignatureStake(categoryIndex, amount, signature, msg.sender),
            "Invalid signature"
        );

        IERC20(contractAddress).transferFrom(msg.sender, address(this), amount);

        StakeInfo memory newStake = StakeInfo(
            amount,
            block.timestamp,
            block.timestamp + categories[categoryIndex].unlockTime
        );
        userStakes[msg.sender][categoryIndex].push(newStake);

        totalStakes[categoryIndex][msg.sender] += amount;
        userStakeCount[msg.sender][categoryIndex] += 1;
        emit Staked(msg.sender, categoryIndex, amount);
    }

    function unstake(
        uint256 categoryIndex,
        uint256 expectedTotalUnstakedAmount,
        uint256 seasonBlockEndTime,
        bytes calldata signature
    ) external whenNotPaused nonReentrant {
        StakeInfo[] storage stakes = userStakes[msg.sender][categoryIndex];
        uint256 totalUnstakedAmount = 0;
        uint256 i = 0;

        require(
            verifySignatureUnstake(categoryIndex, expectedTotalUnstakedAmount, seasonBlockEndTime, signature, msg.sender),
            "Invalid signature"
        );

        while (i < stakes.length) {
            if (
                block.timestamp >= stakes[i].unlockTime && stakes[i].amount > 0
            ) {
                totalUnstakedAmount += stakes[i].amount;

                userUnstaked[msg.sender][categoryIndex].push(
                    StakeInfo({
                        amount: stakes[i].amount,
                        startTime: stakes[i].startTime,
                        unlockTime: block.timestamp
                    })
                );

                userStakeCount[msg.sender][categoryIndex] -= 1;

                stakes[i] = stakes[stakes.length - 1];
                stakes.pop();                
            } else {
                i++;
            }
        }

        require(
            totalUnstakedAmount > 0,
            "No staked amount available for unstaking"
        );
        require(
            totalUnstakedAmount == expectedTotalUnstakedAmount,
            "Unstaked amount does not match expected amount"
        );

        IERC20(contractAddress).transfer(msg.sender, totalUnstakedAmount);
        totalStakes[categoryIndex][msg.sender] -= totalUnstakedAmount;

        emit Unstaked(msg.sender, categoryIndex, totalUnstakedAmount);

        // After unstaking, remove items from the unstaking list that are before the reference block time (if not removed, the unstaking list will grow indefinitely).
        StakeInfo[] storage unstaked = userUnstaked[msg.sender][categoryIndex];
        i = 0;
        while (i < unstaked.length) {
            if (unstaked[i].unlockTime < seasonBlockEndTime) {
                unstaked[i] = unstaked[unstaked.length - 1];
                unstaked.pop();
            } else {
                i++;
            }
        }
    }

    function dailyBoost(uint256 dayIndex, uint256 points, bytes calldata signature) external whenNotPaused
    {
        require(
            !dailyBoosts[msg.sender][dayIndex],
            "Already boosted for this day"
        );

        require(
            verifySignatureDailyBoost(dayIndex, points, signature, msg.sender),
            "Invalid signature"
        );

        dailyBoosts[msg.sender][dayIndex] = true;
        dailyBoostPoint[msg.sender][dayIndex] = points;

        emit DailyBoosted(msg.sender);
    }

    function verifySignatureStake(
        uint256 categoryIndex,
        uint256 amount,
        bytes calldata signature,
        address user
    ) private view returns (bool) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                categoryIndex,
                amount,
                user,
                address(this),
                "STAKE"
            )
        );
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(hash);
        return ECDSA.recover(ethSignedMessageHash, signature) == masterSigner;
    }

    function verifySignatureUnstake(
        uint256 categoryIndex,
        uint256 expectedTotalUnstakedAmount,
        uint256 seasonBlockEndTime,
        bytes calldata signature,
        address user
    ) private view returns (bool) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                categoryIndex,
                expectedTotalUnstakedAmount,
                seasonBlockEndTime,
                user,
                address(this),
                "UNSTAKE"
            )
        );
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(hash);
        return ECDSA.recover(ethSignedMessageHash, signature) == masterSigner;
    }

    function verifySignatureDailyBoost(
        uint256 dayIndex,
        uint256 points,
        bytes calldata signature,
        address user
    ) private view returns (bool) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                dayIndex,
                points,
                user,
                address(this),
                "DAILY_BOOST"
            )
        );
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(hash);
        return ECDSA.recover(ethSignedMessageHash, signature) == masterSigner;
    }

    function getMasterSigner() external view returns (address) {
        return masterSigner;
    }

    function getCategory(uint256 categoryIndex)
        external
        view
        returns (Category memory)
    {
        return categories[categoryIndex];
    }

    function getStakeInfo(address user, uint256 categoryIndex)
        external
        view
        returns (StakeInfo[] memory)
    {
        return userStakes[user][categoryIndex];
    }

    function getTotalStakes(address user, uint256 categoryIndex)
        external
        view
        returns (uint256)
    {
        return totalStakes[categoryIndex][user];
    }

    function getUnstakeEntries(address user, uint256 categoryIndex)
        external
        view
        returns (StakeInfo[] memory)
    {
        return userUnstaked[user][categoryIndex];
    }

    function getUnstakableAmount(address user, uint256 categoryIndex)
        external
        view
        returns (uint256)
    {
        StakeInfo[] storage stakes = userStakes[user][categoryIndex];
        uint256 totalUnstakableAmount = 0;

        for (uint256 i = 0; i < stakes.length; i++) {
            if (
                block.timestamp >= stakes[i].unlockTime && stakes[i].amount > 0
            ) {
                totalUnstakableAmount += stakes[i].amount;
            }
        }

        return totalUnstakableAmount;
    }

    function getUserStakeCount(address user, uint256 categoryIndex)
        external
        view
        returns (uint256)
    {
        return userStakeCount[user][categoryIndex];
    }

    function getDailyBoostPoint(address user, uint256 dayIndex)
        external
        view
        returns (uint256)
    {
        return dailyBoostPoint[user][dayIndex];
    }

    function isDailyBoost(address user, uint256 dayIndex)
        external
        view
        returns (bool)
    {
        return dailyBoosts[user][dayIndex];
    }

    function getTotalDailyBoostPointRange(
        address user,
        uint256 startDayIndex,
        uint256 endDayIndex
    ) external view returns (uint256) {
        require(startDayIndex <= endDayIndex, "Invalid day index range");

        uint256 totalPoints = 0;

        for (
            uint256 dayIndex = startDayIndex;
            dayIndex <= endDayIndex;
            dayIndex++
        ) {
            totalPoints += dailyBoostPoint[user][dayIndex];
        }

        return totalPoints;
    }

    function getDailyBoostPointsInRange(
        address user,
        uint256 startDayIndex,
        uint256 endDayIndex
    ) external view returns (uint256[] memory) {
        require(startDayIndex < endDayIndex, "Invalid range");

        uint256 length = endDayIndex - startDayIndex + 1;
        uint256[] memory points = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            points[i] = dailyBoostPoint[user][startDayIndex + i];
        }

        return points;
    }

    function getDailyBoostStatusInRange(
        address user,
        uint256 startDayIndex,
        uint256 endDayIndex
    ) external view returns (bool[] memory) {
        require(startDayIndex < endDayIndex, "Invalid range");

        uint256 length = endDayIndex - startDayIndex + 1;
        bool[] memory statuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            statuses[i] = dailyBoosts[user][startDayIndex + i];
        }

        return statuses;
    }

    function withdrawETH(address payable to, uint256 amount)
        external
        onlyOwner
    {
        require(amount <= address(this).balance, "Insufficient balance");
        to.transfer(amount);
        emit Withdrawn(to, amount);
    }

    function withdrawERC20(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Insufficient token balance"
        );
        IERC20(token).transfer(to, amount);
        emit ERC20Withdrawn(token, to, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
