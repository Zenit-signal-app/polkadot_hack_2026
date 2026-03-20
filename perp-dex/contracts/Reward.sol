// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// openzeppelin contract imports
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// user defined interface imports
import "./interface/IReward.sol";

/**
 * @title Reward contract.
 * @author https://github.com/omerharuncetin
 * @notice This contract is used for handling reward calculations depending on trading activity on perptual dex.
 */
contract RewardContract is Ownable, IRewardContract, ReentrancyGuard {
    // Holds the reward token
    IERC20 private rewardToken;

    // Reward period start timestamp, will be initialized in constructor
    uint256 public immutable REWARD_PERIOD_START;
    // Reward period in seconds
    uint64 public constant REWARD_PERIOD = 30 days;
    // 387 means 0.387 because this there is no float value in solidity,
    // therefore this variable will be divided by 1000000 for more precise calculations.
    uint256 public constant REWARD_RATE = 387;
    // Reward rate divisor for calculations
    uint256 public constant REWARD_RATE_DIVISOR = 1000;

    // Hold the current reward season
    uint256 public currentRewardSeason;
    // Holds the dex contract address, will be initialized in constructor
    // Will be used for onlyDexContract modifier
    address public dexContractAddress;

    // Holds the cumulative trader volume for each market
    mapping(uint256 => mapping(address => uint256))
        public cumulativeTraderVolumeForMarket;
    // Holds the cumulative market volume for each season
    mapping(uint256 => uint256) public cumulativeMarketVolume;
    // Holds the current total claimable reward for each user
    mapping(address => uint256) public totalClaimableRewardForUser;
    // Holds the last active season that user did trade
    mapping(address => uint256) public lastActiveSeasonForUser;
    // Holds the cumulative reward for each user by season
    mapping(address => mapping(uint256 => uint256))
        public cumulativeRewardForUserBySeason;
    // Holds the last season that user total reward updated
    // This will be used for calculating total claimable reward
    mapping(address => uint256) public totalRewardUpdatedAtSeason;

    // Prevents a function from being called by anyone except the dex contract
    modifier onlyDexContract() {
        require(msg.sender == dexContractAddress, "Only DEX contract");
        _;
    }

    constructor(
        address tokenAddress // Address of the reward token
    ) Ownable(msg.sender) {
        rewardToken = IERC20(tokenAddress);
        REWARD_PERIOD_START = block.timestamp;
        currentRewardSeason = 1;
    }

    /**
     * @inheritdoc IRewardContract
     */
    function claimReward() external override nonReentrant {
        _setRewardSeasonIfNecessary();
        _calculateEstimatedRewardForUser(msg.sender);

        uint256 reward = totalClaimableRewardForUser[msg.sender];

        require(reward > 0, "No reward to claim");

        require(rewardToken.transfer(msg.sender, reward), "Transfer failed");

        totalClaimableRewardForUser[msg.sender] = 0;

        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @inheritdoc IRewardContract
     */
    function setUserReward(
        uint256 _amount,
        address user
    ) external override onlyDexContract {
        _setRewardSeasonIfNecessary();

        cumulativeTraderVolumeForMarket[currentRewardSeason][user] += _amount;
        cumulativeMarketVolume[currentRewardSeason] += _amount;

        _calculateEstimatedRewardForUser(user);

        emit RewardSet(user, _amount);
    }

    /**
     * @inheritdoc IRewardContract
     */
    function getCumulativeTraderVolumeByMarket(
        uint256 marketSeason,
        address user
    ) external view override returns (uint256) {
        return cumulativeTraderVolumeForMarket[marketSeason][user];
    }

    /**
     * @inheritdoc IRewardContract
     */
    function getCumulativeVolumeByMarket(
        uint256 marketSeason
    ) external view override returns (uint256) {
        return cumulativeMarketVolume[marketSeason];
    }

    /**
     * @inheritdoc IRewardContract
     */
    function setDEXContractAddress(
        address _dexContractAddress
    ) external onlyOwner {
        dexContractAddress = _dexContractAddress;
        emit DEXContractAddressSet(_dexContractAddress);
    }

    /**
     * @dev Sets the current reward season based on the block timestamp. This function is private.
     * It calculates the current reward season based on the start time and period of the reward.
     */
    function _setRewardSeasonIfNecessary() private {
        if (
            block.timestamp >=
            REWARD_PERIOD_START + (REWARD_PERIOD * currentRewardSeason)
        ) {
            currentRewardSeason =
                (block.timestamp - REWARD_PERIOD_START) /
                REWARD_PERIOD +
                1;
        }
    }

    /**
     * @dev Calculates the estimated reward for a user. This function is private.
     * It updates the user's reward based on their last active season and the current season.
     * @param user The address of the user for whom to calculate the reward.
     */
    function _calculateEstimatedRewardForUser(address user) private {
        if (
            lastActiveSeasonForUser[user] == 0 ||
            lastActiveSeasonForUser[user] == currentRewardSeason
        ) {
            _calculateEstimatedRewardForCurrentSeason(user);
        } else if (lastActiveSeasonForUser[user] != currentRewardSeason) {
            _updateUserClaimableReward(user);
            _calculateEstimatedRewardForCurrentSeason(user);
        }
    }

    /**
     * @dev Calculates the estimated reward for the current season for a given user. This function is private.
     * It uses the user's trading volume for the current season to calculate their reward.
     * @param user The address of the user for whom to calculate the reward.
     */
    function _calculateEstimatedRewardForCurrentSeason(address user) private {
        uint cumulativeTraderVolumeForSeason = cumulativeTraderVolumeForMarket[
            currentRewardSeason
        ][user];

        // return if the user has no trading volume for the current season
        // or the market has no volume for the current season
        if (
            cumulativeTraderVolumeForSeason == 0 ||
            cumulativeMarketVolume[currentRewardSeason] == 0
        ) {
            return;
        }

        uint256 reward = _calculateReward(
            cumulativeTraderVolumeForSeason,
            cumulativeMarketVolume[currentRewardSeason]
        );

        cumulativeRewardForUserBySeason[user][currentRewardSeason] = reward;
        lastActiveSeasonForUser[user] = currentRewardSeason;
    }

    /**
     * @dev Updates the claimable reward for a user. This function is private.
     * It calculates and updates the reward for the user based on their last active season.
     * @param user The address of the user whose claimable reward needs updating.
     */
    function _updateUserClaimableReward(address user) private {
        uint256 marketSeason = lastActiveSeasonForUser[user];

        uint cumulativeTraderVolumeForSeason = cumulativeTraderVolumeForMarket[
            marketSeason
        ][user];
        uint256 reward = _calculateReward(
            cumulativeTraderVolumeForSeason,
            cumulativeMarketVolume[marketSeason]
        );

        cumulativeRewardForUserBySeason[user][marketSeason] = reward;

        if (totalRewardUpdatedAtSeason[user] != marketSeason) {
            totalClaimableRewardForUser[user] += reward;
            totalRewardUpdatedAtSeason[user] = marketSeason;
        }
    }

    /**
     * @dev Calculates the reward amount based on the trader's volume and the market volume. This function is private and pure.
     * It returns the calculated reward.
     * @param traderVolume The trading volume of the trader.
     * @param marketVolume The total market volume.
     * @return uint256 The calculated reward amount.
     */
    function _calculateReward(
        uint256 traderVolume,
        uint256 marketVolume
    ) private pure returns (uint256) {
        // multiplied by 1e18 for precision
        uint256 reward = ((traderVolume * REWARD_RATE * 1e18) /
            REWARD_RATE_DIVISOR) / marketVolume;

        return reward;
    }
}
