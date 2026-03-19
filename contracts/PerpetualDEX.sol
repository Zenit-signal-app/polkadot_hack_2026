// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// openzeppelin contract imports
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// user defined interface imports
import "./interface/IPerpDEX.sol";
import "./interface/IReward.sol";
import "./ZenitOracle.sol";

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

    // Authorized keeper for TP/SL execution (set by owner)
    address public keeperAddress;

    // On-chain oracle for settlement (prices are 1e18 scaled)
    ZenitOracle public oracle;

    // maintenance margin rate (1e18 = 100%)
    uint256 public maintenanceMarginRateE18 = 1e16; // 1%

    // Holds the user balances
    mapping(address => uint256) public balances;
    // Holds the user positions per market: user => market (bytes32) => Position
    mapping(address => mapping(bytes32 => Position)) public positions;

    event KeeperRewardClaimed(address indexed keeper, uint256 amount);
    event OracleUpdated(address indexed oracle);
    event MaintenanceMarginRateUpdated(uint256 mmrE18);

    constructor(
        address tokenAddress, // Address of the trading token
        address rewardContractAddress, // Address of the reward contract
        address oracleAddress // Address of the oracle contract
    ) Ownable(msg.sender) {
        tradingToken = IERC20(tokenAddress);
        rewardContract = IRewardContract(rewardContractAddress);
        oracle = ZenitOracle(oracleAddress);
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
     * @dev Set the authorized keeper address. Only owner.
     */
    function setKeeperAddress(address _keeper) external onlyOwner {
        keeperAddress = _keeper;
    }

    function setOracle(address _oracle) external onlyOwner {
        oracle = ZenitOracle(_oracle);
        emit OracleUpdated(_oracle);
    }

    function setMaintenanceMarginRate(uint256 _mmrE18) external onlyOwner {
        require(_mmrE18 <= 5e17, "MMR too high"); // <= 50%
        maintenanceMarginRateE18 = _mmrE18;
        emit MaintenanceMarginRateUpdated(_mmrE18);
    }

    /**
     * @dev Keeper closes a user's position when TP/SL is hit. Only callable by keeperAddress.
     * @param _user The user whose position to close.
     * @param _market The market symbol.
     * @param _amount The margin amount to close.
     * @return keeperReward Amount of reward to keeper (0 if no reward pool).
     */
    function keeperClosePosition(
        address _user,
        bytes32 _market,
        uint256 _amount,
        uint256 _closePrice
    ) external nonReentrant returns (uint256 keeperReward) {
        _closePrice; // Reserved; settlement uses on-chain oracle
        require(keeperAddress != address(0), "Keeper not set");
        require(msg.sender == keeperAddress, "Only keeper");
        require(_amount > 0, "Amount must be greater than 0");

        Position storage position = positions[_user][_market];
        require(position.amount > 0, "No position open for this market");
        require(position.amount >= _amount, "Insufficient balance");

        _decreasePositionForUser(_user, _market, _amount, position);

        emit KeeperRewardClaimed(msg.sender, 0);
        return 0;
    }

    /**
     * @dev View: pending keeper reward (0 if no reward pool configured).
     */
    function pendingKeeperReward(address _keeper) external pure returns (uint256) {
        _keeper;
        return 0;
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

        uint256 entryPriceE18 = oracle.getPrice(_market);
        require(entryPriceE18 > 0, "Oracle price not set");
        positions[msg.sender][_market] = Position(_amount, _position, _leverage, entryPriceE18);

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

        (int256 pnl, bool liquidated) = _calcPnlAndLiquidation(position, _amount, oracle.getPrice(_market));

        if (position.amount == _amount) {
            delete positions[msg.sender][_market];
        } else {
            position.amount -= _amount;
        }

        uint256 credit = _settle(msg.sender, _amount, pnl);
        balances[msg.sender] += credit;

        if (liquidated) {
            emit PositionLiquidated(msg.sender, _market, _amount, pnl);
        } else {
            emit PositionClosed(msg.sender, _market, _amount, pnl);
        }
    }

    /**
     * @dev Decreases a user's position (used by keeper). Same logic as _decreasePosition but for arbitrary user.
     */
    function _decreasePositionForUser(
        address _user,
        bytes32 _market,
        uint256 _amount,
        Position storage position
    ) private {
        _setRewardForUser(_amount * position.leverage, _user);

        (int256 pnl, bool liquidated) = _calcPnlAndLiquidation(position, _amount, oracle.getPrice(_market));

        if (position.amount == _amount) {
            delete positions[_user][_market];
        } else {
            position.amount -= _amount;
        }

        uint256 credit = _settle(_user, _amount, pnl);
        balances[_user] += credit;

        if (liquidated) {
            emit PositionLiquidated(_user, _market, _amount, pnl);
        } else {
            emit PositionClosed(_user, _market, _amount, pnl);
        }
    }

    function _calcPnlAndLiquidation(
        Position storage position,
        uint256 marginToClose,
        uint256 closePriceE18
    ) private view returns (int256 pnl, bool liquidated) {
        require(closePriceE18 > 0, "Oracle price not set");
        uint256 entry = position.entryPriceE18;
        require(entry > 0, "Entry not set");

        // positionSize = margin * leverage (zUSDC units)
        uint256 positionSize = marginToClose * uint256(position.leverage);

        // pnlAbs = positionSize * abs(close-entry) / entry
        uint256 absDelta = closePriceE18 >= entry ? closePriceE18 - entry : entry - closePriceE18;
        uint256 pnlAbs = Math.mulDiv(positionSize, absDelta, entry);

        bool isProfit = (position.position == PositionType.Long)
            ? (closePriceE18 >= entry)
            : (closePriceE18 <= entry);

        pnl = isProfit ? int256(pnlAbs) : -int256(pnlAbs);

        // Liquidation check on the portion closed: if loss >= marginToClose * (1 - mmr)
        if (!isProfit) {
            uint256 maxLoss = Math.mulDiv(marginToClose, (1e18 - maintenanceMarginRateE18), 1e18);
            liquidated = pnlAbs >= maxLoss;
        }
    }

    function _settle(address user, uint256 marginToClose, int256 pnl) private pure returns (uint256 credit) {
        user; // reserved
        if (pnl >= 0) {
            return marginToClose + uint256(pnl);
        }
        uint256 loss = uint256(-pnl);
        if (loss >= marginToClose) return 0;
        return marginToClose - loss;
    }

    /**
     * @dev Sets the reward for the caller based on a given amount. The function is private and can only be called within the contract.
     * @param _amount The leveraged amount of position.
     * Calls the reward contract to update the user's reward based on the passed amount.
     */
    function _setReward(uint256 _amount) private {
        rewardContract.setUserReward(_amount, msg.sender);
    }

    /**
     * @dev Sets the reward for a specific user (used when keeper closes on behalf of user).
     */
    function _setRewardForUser(uint256 _amount, address _user) private {
        rewardContract.setUserReward(_amount, _user);
    }
}
