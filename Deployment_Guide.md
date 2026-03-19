# Deployment Guide for Zenit Perp DEX

## Overview
This repository includes:
- **Smart contracts (Hardhat)** — `PerpetualDEX` + on-chain `ZenitOracle`.
- **Frontend (React + Vite)** — trading UI + history + keeper sync.
- **Keeper service (Node.js)** — monitors TP/SL/Liquidation and closes positions **on-chain** (PnL settlement happens in the DEX contract).
- **Keeper REST API** — exposes `/orders`, `/logs/recent`, and cache-reset signals for UI.
- **Keeper database (Prisma + SQLite)** — persists orders and dedupes open positions.

To avoid issues like TP/SL not triggering or faucet transfers failing, make sure every component is deployed and configured together with the correct RPC and env vars.

---

## 1. Server Requirements
- Node.js 20+
- No external DB required for development (keeper uses SQLite via Prisma)
- An Ethereum-compatible RPC (e.g., Polkadot EVM testnet)
- Wallets funded with PAS / zUSDC for faucet and keeper rewards
- PM2/systemd for managed services (optional but recommended)

---

## 2. Environment Setup

### Frontend (`frontend/`)
1. Copy `frontend/.env.example` → `frontend/.env` (or edit `frontend/.env`) and set:
   - `VITE_RPC_URL` — Polkadot EVM RPC URL for the browser wallet.
   - `VITE_PERP_DEX_ADDRESS` — deployed `PerpetualDEX` contract.
   - `VITE_TOKEN_ADDRESS` — deployed collateral token (zUSDC).
   - `VITE_KEEPER_URL` — **required for TP/SL/Liq UI sync**. Must be reachable from the user's browser (CORS enabled). Example: `https://keeper.yourdomain.com` (local: `http://127.0.0.1:3100`).
2. Install deps: `npm install` (or `pnpm`/`yarn`)
3. Dev: `npm run dev`
4. Production build: `npm run build` → serve `frontend/dist` via Nginx/Vercel/Cloudflare Pages/etc.

### Keeper Service
1. Copy `keeper/.env.example` → `keeper/.env` (or edit `keeper/.env`) and set:
   - `RPC_URL` — Polkadot EVM RPC URL for keeper
   - `CHAIN_ID`
   - `PERP_DEX_ADDRESS`
   - `TOKEN_ADDRESS`
   - `ORACLE_ADDRESS` — deployed `ZenitOracle` used for on-chain settlement prices
   - `KEEPER_PRIVATE_KEY` — keeper signer (must have enough PAS for gas)
   - `API_PORT=3100`
2. Install & build:
   - `cd keeper && npm install`
   - `npx prisma generate`
   - `npm run build`
3. Start: `cd keeper && npm run start`
4. Verify:
   - `GET http://127.0.0.1:3100/health`
   - `GET http://127.0.0.1:3100/orders?status=Open&limit=500`
   - `GET http://127.0.0.1:3100/logs/recent?limit=200`

### Faucet Logic
- Confirm faucet wallet (env key) holds zUSDC.
- Ensure frontend uses `ethers` to send ERC20 transfer with that key.
- Implement cooldown (localStorage) so each wallet can claim once every 24h.

---

## 3. Contract: Enable Keeper (Required for TP/SL)
The `PerpetualDEX` contract must authorize the keeper wallet. After deploying:

1. Get the keeper wallet address (derived from `KEEPER_PRIVATE_KEY`).
2. As contract **owner**, call `setKeeperAddress(keeperWalletAddress)` on the `PerpetualDEX`.
3. Or use the provided script (owner key from `PRIVATE_KEY`, keeper address derived from `KEEPER_PRIVATE_KEY`):
   ```bash
   # Ensure frontend/.env has the new DEX/reward addresses, PRIVATE_KEY (owner), and KEEPER_PRIVATE_KEY
   npx hardhat run scripts/setKeeper.ts --network polkadotTestnet
   ```

Without this, the keeper cannot close positions on-chain and TP/SL will not execute.

---

## 4. Running the Stack
1. Start the keeper service and monitor logs:
   - Verify it publishes oracle prices (best-effort) and triggers closures when price crosses TP/SL/Liq.
   - Keep **only one keeper instance** listening on port `3100` to avoid nonce / tx-pool issues.
2. Build & serve the frontend with the same contract address.
3. Test the faucet form: fill wallet, click “Get 1000 zUSDC”, confirm transaction hash & receipt.

---

## 5. Debugging Tips
| Issue | Cause | Fix |
| --- | --- | --- |
| TP/SL/Liq never fires | Keeper not running, keeper not authorized, or TP/SL not registered | Start keeper, call `setKeeperAddress`, ensure frontend can reach `VITE_KEEPER_URL`. Check `GET /diagnostic`. |
| Keeper closes on-chain but UI still shows Open | Browser cached history or keeper sync lag | UI now reconciles open entries with keeper `/orders` and also listens to `GET /cache/reset?wallet=0x...` to refresh caches without deleting trade history. |
| Keeper fails to close (Invalid Transaction / banned / priority too low) | RPC tx-pool policies + nonce mismatch | Use one keeper instance, keep legacy tx enforced by default, and ensure keeper has enough PAS. Try switching RPC_URL. |
| Faucet transactions not seen | Faucet key lacks tokens or RPC mismatch | Check faucet wallet balance, ensure RPC is correct, resend transfer manually |
| History resets after reload | Browser cache cleared or keys removed | Trade history is stored wallet-scoped in localStorage (`zenit:tradeHistory:<wallet>`) |

---

## 6. Recommended Process
- Use PM2/systemd to keep keeper + faucet (if separate) alive.
- Enable monitoring/alerting for keeper errors.
- Keep `.env` files out of git (add to `.gitignore`).
- Document any on-chain parameters for future contributors.