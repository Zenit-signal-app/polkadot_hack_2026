# Zenit Perpetual DEX - Frontend

React + Vite trading interface for Zenit Perpetual DEX (Polkadot EVM testnet).

## Requirements

- Node.js 20+
- Wallet extension (MetaMask / RainbowKit-supported wallet)
- Keeper service reachable from browser (`VITE_KEEPER_URL`)

## Install

```bash
cd frontend
npm install
```

## Run

```bash
npm run dev
```

Default local URL is shown by Vite in terminal.

## Build

```bash
npm run build
```

## Environment (`frontend/.env`)

Required:

```
VITE_RPC_URL=https://...
VITE_PERP_DEX_ADDRESS=0x...
VITE_TOKEN_ADDRESS=0x...
VITE_ORACLE_ADDRESS=0x...
VITE_KEEPER_URL=http://127.0.0.1:3100
```

## Key features

- Multi-market trading (BTCUSD / ETHUSD / DOTUSD): open, increase, close.
- UI + keeper synchronization for TP/SL/Liquidation status.
- Auto reconciliation of local history with keeper `/orders` data.
- Cache reset signal from keeper (`/cache/reset`) without deleting user history.
- Rich order confirmation notice with copyable tx/order information.
- Closed PnL rendering is reconciled against keeper close data (close price + timestamps), including legacy-history fallbacks.
- Equity and available margin display align with on-chain accounting (`dexBalance + openMargin + unrealizedPnL`).
- Better transaction UX:
  - conservative gas estimation
  - soft-timeout receipt waiting (UI unblocks quickly; receipt is still awaited in background)
  - applies to `approve` (deposit flow) and `openPosition`/`increasePosition`
  - clearer tx error messages from RPC/wallet

## Tech Stack

- React 18 + TypeScript
- Vite
- wagmi + RainbowKit
- Tailwind CSS
- viem + ethers
