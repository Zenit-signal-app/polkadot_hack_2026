# Zenit Perpetual DEX

## Overview

Zenit Perpetual DEX is a minimal perpetual trading stack built around a single collateral token (`zUSDC`). It includes smart contracts (DEX + on-chain oracle), a React trading terminal, and a keeper service that automatically closes positions when Take Profit / Stop Loss / Liquidation conditions are met. Closures are executed **on-chain** and PnL settlement is handled by the DEX contract.

## Smart Contracts

- `Token.sol` (zUSDC) — ERC20 collateral used for deposits and margin.
- `PerpetualDEX.sol` — deposit/withdraw, open/increase/close positions per market (BTCUSD/ETHUSD/DOTUSD), emits lifecycle events (`PositionOpened`, `PositionClosed`, `PositionLiquidated`) and settles PnL on close.
- `ZenitOracle.sol` — on-chain price store used for settlement prices (keeper publishes prices each cycle; best-effort).

## Frontend

- React + Vite UI (`frontend/src/pages/Trade.tsx`) provides a trading terminal with chart, open/closed positions, and local order history.
- The UI polls the keeper for authoritative TP/SL/Liq and closure timestamps via `GET /orders`.
- When the keeper auto-closes a position, the UI listens to `GET /cache/reset?wallet=0x...` and refreshes caches **without deleting trade history**.
- Closed-order PnL uses keeper close data (with safe fallbacks) to avoid historical entries showing `0` when local close price is missing.
- Close reason classification is code-driven and persisted in the keeper DB:
  - `closeReasonCode=0` = `Manual close`
  - `closeReasonCode=1` = `CloseReason: TP`
  - `closeReasonCode=2` = `CloseReason: SL`
  - `closeReasonCode=3` = `CloseReason: Liquidated`
- Collateral equity display follows on-chain semantics (`dexBalance + openMargin + unrealizedPnL`) to avoid double-counting realized PnL.

## Keeper service

- Node.js service in `keeper/` that:
  - fetches prices (DIA, with fallbacks)
  - publishes on-chain oracle prices (best-effort) and supports an optional dedicated `ORACLE_PRIVATE_KEY` (must be authorized as updater in `ZenitOracle`)
  - monitors open orders stored in SQLite (Prisma)
  - executes on-chain closes when TP/SL/Liq triggers
  - serves zUSDC faucet claims via dedicated signer key (recommended)
  - exposes a REST API on port `3100`:
    - `GET /health`
    - `GET /orders` (supports `status=Open`)
    - `GET /logs/recent`
    - `GET /cache/reset?wallet=0x...` (UI refresh signal)
    - `GET /faucet/status?wallet=0x...`
    - `POST /faucet/zusdc`

## Development

### Prerequisites
- Node.js 20+
- npm
- Hardhat (included in devDependencies)

### Install

```bash
npm install
```

### Compile contracts

```bash
npx hardhat compile
```

### Start frontend (local dev)

```bash
cd frontend
npm install
npm run dev
```

### Start keeper (local dev)

```bash
cd keeper
npm install
npx prisma generate
npm run build
npm run start
```

### Environment variables

- Frontend: `frontend/.env`
  - `VITE_RPC_URL`
  - `VITE_PERP_DEX_ADDRESS`
  - `VITE_TOKEN_ADDRESS`
  - `VITE_KEEPER_URL` (default local: `http://127.0.0.1:3100`)
- Keeper: `keeper/.env`
  - `RPC_URL`, `CHAIN_ID`
  - `PERP_DEX_ADDRESS`, `TOKEN_ADDRESS`, `ORACLE_ADDRESS`
  - `KEEPER_PRIVATE_KEY`
  - `FAUCET_PRIVATE_KEY` (should be different from `KEEPER_PRIVATE_KEY`)
  - `ORACLE_PRIVATE_KEY` (optional, dedicated updater key)
  - `API_PORT=3100`

## Deployment

See `Deployment_Guide.md`.

## Notes

- Keep only **one** keeper instance running for a given keeper wallet to avoid nonce/tx-pool issues.
- Use a **separate faucet wallet** (`FAUCET_PRIVATE_KEY`) to avoid nonce contention with keeper close/oracle transactions.
- Keep DB schema up to date when you change keeper Prisma models (`close_reason`, `final_pnl`, `closed_at`).
  - If `prisma generate` fails on Windows with EPERM rename errors, use `prisma db push --skip-generate` (or `npx prisma db push --skip-generate`) and then restart keeper.
- On Polkadot EVM RPCs, legacy transactions are enforced by default in the keeper for stability; only enable EIP-1559 if your RPC supports it reliably.
- Frontend order actions include receipt timeout handling to avoid long "Processing..." states when RPC confirmation is delayed.
- If `GET /orders` returns closed rows with `closePrice: null` (older records), the UI falls back to TP/SL/Liq and timestamp-matched keeper rows for PnL rendering.
