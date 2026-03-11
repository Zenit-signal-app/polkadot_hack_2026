# Zenit Perpetual DEX

## Overview

Zenit Perpetual DEX is a minimal perpetual trading stack built around a single tradable collateral token (`zUSDC`). From the Solidity layer that tracks per-user long/short exposures in multiple markets to the React-based trading terminal, the project demonstrates how users can deposit collateral, open/increase/close leveraged positions across BTCUSD/ETHUSD/DOTUSD, and steadily earn rewards based on trading volume. The frontend mirrors a real-time trading dashboard, while the Solidity contracts maintain balances, positions, and reward accounting in constant time.

## Smart Contracts

- `RewardToken.sol` — ERC20 contract that mints `zUSDC` (500M supply) used for depositing, trading, and claiming rewards.
- `RewardContract.sol` — Tracks per-season trading volume, enforces that only the DEX can set rewards, and lets traders claim their share of reward token payouts.
- `PerpetualDEX.sol` — Manages deposits/withdrawals, stores each user’s long or short exposure per market (BTCUSD, ETHUSD, DOTUSD), routes leveraged volume to the reward contract, and emits position lifecycle events (`PositionOpened`, `PositionIncreased`, `PositionClosed`).
- Interface files (`IPerpDEX.sol`, `IPosition`, `IReward.sol`) document the available methods and hooks between DEX ↔ Reward logic.

## Frontend

- React + Vite UI (`frontend/src/pages/Trade.tsx`) replicates a trading terminal with a chart, tabs for order history, leverage controls (now up to 25x), and order size previews that mirror on-chain volume logic across BTCUSD, ETHUSD, and DOTUSD.
- The trade history list keeps each row inside a scrollable container, shows status, and surfaces a close button that launches a confirmation modal wired to the same close logic as the trade panel.
- Core utilities format timestamps, currency, and position math to align with the Solidity state exported by the contracts.
- The `Position (zUSDC)` summary aggregates collateral across every symbol, refetches data immediately after successful transactions, and shows “Multiple” when both long and short exposures exist.

## Recent updates

- **Multi-market positions** — Users can long or short BTCUSD, ETHUSD, and DOTUSD simultaneously while the contracts store exposures per symbol so each market stays independent.
- **Live dashboard sync** — `Trade.tsx` refetches every position slot and collateral amount immediately after successful trades so the `Position (zUSDC)` widget is always current after deposit/open/increase/close actions.
- **Current deployments** — The frontend now targets `VITE_PERP_DEX_ADDRESS` (`0xa8de3e548054417e4d918FAC46E990aF623AC7BA`) and `VITE_REWARD_ADDRESS` (`0x5b218Bf85172a3df8017A3f29322B93B05a4C3C9`) by default.

## Development

### Prerequisites
- Node.js 18+
- npm (project already installs dependencies from `package-lock.json`)
- Hardhat for compiling/testing contracts

### Install

```bash
npm install
```

### Compile Contracts

```bash
npx hardhat compile
# or
npm run compile
```

### Run Tests

```bash
npx hardhat test
# or
npm run test
```

### Start Frontend

```bash
cd frontend
npm install
npm run dev
```

## Usage Flow

1. Deploy `RewardToken` and `RewardContract`, then set the DEX address on the reward contract.
2. Deploy `PerpetualDEX` with the reward contract and `zUSDC` addresses.
3. Users approve `zUSDC`, deposit it into the DEX, set leverage (1–25x), and open positions.
4. Each open/increase/close operation deducts or refunds collateral while notifying the reward contract of leveraged volume.
5. Traders claim their rewards from `RewardContract.claimReward`, which pays ERC20 tokens proportional to their seasonal volume share.

## Getting Started with Zenit Perpetual DEX

1. Make sure `zUSDC` is deployed (or use the provided `RewardToken.sol`) and that your wallet holds some tokens.
2. Deploy `RewardContract.sol` and call `setDEXContractAddress` once the DEX contract address exists.
3. Deploy `PerpetualDEX.sol` passing the token and reward contract addresses, then set the returned address inside `frontend/.env` (`VITE_PERP_DEX_ADDRESS`, `VITE_TOKEN_ADDRESS`, `VITE_REWARD_ADDRESS`).
4. Run the frontend (`cd frontend && npm run dev`) and connect a wallet; you will be prompted to approve `zUSDC` before depositing.
5. Deposit zUSDC, choose long or short, slide the leverage up to 25x, and enter an Amount to open or increase positions; see the history tab for status and the close button for confirmations.
6. Claim rewards by visiting the Rewards tab when you want to harvest accrued ERC20 payouts.

## Notes

- `RewardContract` enforces reward seasons lasting 30 days (`REWARD_PERIOD`), calculates rewards by dividing a user’s volume by the season’s total, and scales the result for precision.
- Solidity functions guard against bad inputs (`require`) and use `ReentrancyGuard` to avoid reentrancy on withdraws and claims.
- Frontend-exclusive PnL figures interpolate on-chain data with price feeds and do not impact the smart contract state.

## Frontend .env values

When running locally (see `frontend/.env`), the UI expects:

- `VITE_PERP_DEX_ADDRESS` – the deployed Perpetual DEX contract (`0xa8de3e548054417e4d918FAC46E990aF623AC7BA`).
- `VITE_TOKEN_ADDRESS` – the `zUSDC` ERC20 contract (`0x277E42B9454fB36A7Eaa52D4cE332bEF71dd017a`).
- `VITE_REWARD_ADDRESS` – the reward contract address (`0x5b218Bf85172a3df8017A3f29322B93B05a4C3C9`).
- `VITE_WALLETCONNECT_PROJECT_ID` – WalletConnect Cloud project ID (required for WalletConnect modal).
