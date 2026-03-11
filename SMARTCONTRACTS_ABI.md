# Zenit Perpetual DEX Smart Contract ABIs

The deployed contracts expose the following core Application Binary Interface (ABI) items. Use these definitions when interacting with the contracts from scripts, a frontend, or a relayer. Addresses are listed in `frontend/.env`.

## `PerpetualDEX` (DEX contract)

- **Events**
  - `Deposit(address indexed user, uint256 amount)` — emitted after a successful deposit.
  - `Withdraw(address indexed user, uint256 amount)` — emitted after a withdrawal.
  - `PositionOpened(address indexed user, uint256 amount, PositionType position, uint8 leverage)` — fired when a new position is created.
  - `PositionIncreased(address indexed user, uint256 amount)` — fired when an existing position receives more margin.
  - `PositionClosed(address indexed user, uint256 amount)` — fired when some or all of a position is closed.

- **Functions**
  - `deposit(uint256 _amount)` — transfer `_amount` of zUSDC into the DEX. Requires prior `approve`.
  - `withdraw(uint256 _amount)` (nonReentrant) — remove collateral from the DEX back to the caller; `_amount` must be ≤ balance.
  - `openPosition(uint256 _amount, PositionType _positionType, uint8 _leverage)` — create a new long/short position using `_amount` collateral and leverage up to 25.
  - `increasePosition(uint256 _amount)` — add `_amount` collateral to an existing position (same leverage).
  - `closePosition(uint256 _amount)` — decrease/close the active position and refund `_amount` collateral.
  - `getCurrentPosition(address user) -> Position` — view a user’s current `Position` struct (`amount`, `position`, `leverage`).
  - `balanceOf(address _account) -> uint256` — read the on-chain zUSDC balance managed by the DEX.
  - `getTokenAddress() -> address` — returns the zUSDC ERC20 address.
  - `getRewardContractAddress() -> address` — reward contract associated with this DEX.

## `RewardContract`

- **Events**
  - `RewardClaimed(address indexed user, uint256 amount)`
  - `RewardSet(address indexed user, uint256 amount)`
  - `DEXContractAddressSet(address indexed dexContractAddress)`

- **Functions**
  - `claimReward()` — claim the currently available reward balance in the current season.
  - `setUserReward(uint256 _amount, address user)` — callable only by the DEX to increment a user’s volume-based reward.
  - `setDEXContractAddress(address _dexContractAddress)` — owner-only setter for linking the reward owner.
  - `getCumulativeTraderVolumeByMarket(uint256 marketSeason, address user) -> uint256`
  - `getCumulativeVolumeByMarket(uint256 marketSeason) -> uint256`

## `RewardToken` (`zUSDC`)

- ERC20 standard ABI (from OpenZeppelin).
  - Standard functions: `name()`, `symbol()`, `decimals()`, `totalSupply()`, `balanceOf(address)`, `transfer(address,uint256)`, `allowance(address,address)`, `approve(address,uint256)`, `transferFrom(address,address,uint256)`
  - `_mint` is executed only during deployment (500M tokens to deployer).

## Deployment Addresses (per `frontend/.env`)

- `zUSDC_Smartcontract` / `VITE_TOKEN_ADDRESS`: `0x277E42B9454fB36A7Eaa52D4cE332bEF71dd017a`
- `VITE_DEX_ADDRESS`: `0xfDb613715EAc5a908Dc50d6c517a4044F243a71b`
- `VITE_REWARD_ADDRESS`: `0x6fAbdA09fa1FB9e3087Db3De8D3b71E26bE15CA0`

Use these ABI fragments alongside the addresses when configuring SDKs, contract wrappers, or manual `ethers.js`/`viem` calls.
