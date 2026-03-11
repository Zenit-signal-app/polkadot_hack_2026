// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// openzeppelin contract imports
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// user defined interface imports
import "./interface/IPerpDEX.sol";
import "./interface/IReward.sol";

/**
 * @title Perpetual DEX contract.
 * @author https://github.com/omerharuncetin
 * @notice This contract is used for handling trading positions and balances.
 */
contract PerpetualDEX is IPerpDEX, IPosition, Ownable, ReentrancyGuard {
    // Holds the trading token
    IERC20 private tradingToken;
    // Holds the reward contract
    IRewardContract private rewardContract;

    // Holds the user balances
    mapping(address => uint256) public balances;
    // Holds the user positions per market: user => market (bytes32) => Position
    mapping(address => mapping(bytes32 => Position)) public positions;

    constructor(
        address tokenAddress, // Address of the trading token
        address rewardContractAddress // Address of the reward contract
    ) Ownable(msg.sender) {
        tradingToken = IERC20(tokenAddress);
        rewardContract = IRewardContract(rewardContractAddress);
    }

    /**
     * @inheritdoc IPerpDEX
     */
    function deposit(uint256 _amount) external {
        require(
            tradingToken.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );
        require(_amount > 0, "Amount must be greater than 0");
        balances[msg.sender] += _amount;
        emit Deposit(msg.sender, _amount);
    }

    /**
     * @inheritdoc IPerpDEX
     */
    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        balances[msg.sender] -= _amount;

        require(tradingToken.transfer(msg.sender, _amount), "Transfer failed");

        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @inheritdoc IPosition
     */
    function openPosition(
        bytes32 _market,
        uint256 _amount,
        PositionType _positionType,
        uint8 _leverage
    ) external override {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        require(_leverage > 0, "Leverage must be greater than 0");
        require(_amount > 0, "Amount must be greater than 0");
        require(positions[msg.sender][_market].amount == 0, "Position already open for this market");

        _openPosition(_market, _amount, _positionType, _leverage);
    }

    /**
     * @inheritdoc IPosition
     */
    function increasePosition(bytes32 _market, uint256 _amount) external override {
        Position storage position = positions[msg.sender][_market];

        require(position.amount > 0, "No position open for this market");
        require(_amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        _increasePosition(_market, _amount, position);
    }

    /**
     * @inheritdoc IPosition
     */
    function closePosition(bytes32 _market, uint256 _amount) external override {
        Position storage position = positions[msg.sender][_market];

        require(position.amount > 0, "No position open for this market");
        require(_amount > 0, "Amount must be greater than 0");
        require(position.amount >= _amount, "Insufficient balance");

        _decreasePosition(_market, _amount, position);
    }

    /**
     * @inheritdoc IPerpDEX
     */
    function getTokenAddress() external view override returns (address) {
        return address(tradingToken);
    }

    /**
     * @inheritdoc IPerpDEX
     */
    function getRewardContractAddress()
        external
        view
        override
        returns (address)
    {
        return address(rewardContract);
    }

    /**
     * @inheritdoc IPerpDEX
     */
    function balanceOf(
        address _account
    ) external view override returns (uint256) {
        return balances[_account];
    }

    /**
     * @inheritdoc IPosition
     */
    function getCurrentPosition(
        address user,
        bytes32 market
    ) external view override returns (Position memory) {
        return positions[user][market];
    }

    /**
     * @dev Opens a trading position for the caller. The function is private and can only be called within the contract.
     * @param _market The market symbol.
     * @param _amount The amount for the new position.
     * @param _position The type of the position (Long/Short).
     * @param _leverage The leverage for the new position.
     * Deducts the position amount from the caller's balance, sets the new position,
     * updates the reward based on the leveraged amount, and emits a PositionOpened event.
     */
    function _openPosition(
        bytes32 _market,
        uint256 _amount,
        PositionType _position,
        uint8 _leverage
    ) private {
        balances[msg.sender] -= _amount;

        positions[msg.sender][_market] = Position(_amount, _position, _leverage);

        _setReward(_amount * _leverage);

        emit PositionOpened(msg.sender, _market, _amount, _position, _leverage);
    }

    /**
     * @dev Increases an existing trading position for the caller. The function is private and can only be called within the contract.
     * @param _market The market symbol.
     * @param _amount The additional amount to increase the position by.
     * @param position The storage reference to the caller's current position.
     * Deducts the additional amount from the caller's balance, updates the position amount,
     * updates the reward based on the leveraged amount, and emits a PositionIncreased event.
     */
    function _increasePosition(
        bytes32 _market,
        uint256 _amount,
        Position storage position
    ) private {
        balances[msg.sender] -= _amount;

        position.amount += _amount;

        _setReward(_amount * position.leverage);

        emit PositionIncreased(msg.sender, _market, _amount);
    }

    /**
     * @dev Decreases an existing trading position for the caller. The function is private and can only be called within the contract.
     * @param _market The market symbol.
     * @param _amount The amount by which the position should be decreased.
     * @param position The storage reference to the caller's current position.
     * Updates the reward based on the leveraged amount, adjusts the position amount or deletes it if the entire position is closed,
     * credits the amount back to the caller's balance, and emits a PositionClosed event.
     */
    function _decreasePosition(
        bytes32 _market,
        uint256 _amount,
        Position storage position
    ) private {
        _setReward(_amount * position.leverage);

        if (position.amount == _amount) {
            delete positions[msg.sender][_market];
        } else {
            position.amount -= _amount;
        }

        balances[msg.sender] += _amount;

        emit PositionClosed(msg.sender, _market, _amount);
    }

    /**
     * @dev Sets the reward for the caller based on a given amount. The function is private and can only be called within the contract.
     * @param _amount The leveraged amount of position.
     * Calls the reward contract to update the user's reward based on the passed amount.
     */
    function _setReward(uint256 _amount) private {
        rewardContract.setUserReward(_amount, msg.sender);
    }
}
