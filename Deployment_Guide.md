# Deployment Guide for Zenit Perp DEX

## Overview
This repository includes:
- **Frontend (React)** — serves the trading UI.
- **Keeper Service** — watches take-profit / stop-loss orders and closes them on-chain.
- **Faucet Logic** — dispenses zUSDC via the configured faucet wallet.
- **Keeper Database** — stores open orders and pricing metadata.

To avoid issues like TP/SL not triggering or faucet transfers failing, make sure every component is deployed and configured together with the correct RPC and env vars.

---

## 1. Server Requirements
- Node.js 20+
- PostgreSQL / MongoDB (depending on keeper implementation)
- An Ethereum-compatible RPC (e.g., Polkadot EVM testnet)
- Wallets funded with PAS / zUSDC for faucet and keeper rewards
- PM2/systemd for managed services (optional but recommended)

---

## 2. Environment Setup

### Frontend (`frontend/`)
1. Copy `.env.example` → `.env` and set:
   - `VITE_RPC_URL` (Polkadot EVM RPC)
   - `VITE_PERPETUAL_DEX_ADDRESS` (smart contract)
   - `VITE_FAUCET_PRIVATE_KEY`, `VITE_FAUCET_WALLET`, `VITE_FAUCET_TOKEN_ADDRESS`
   - `VITE_KEEPER_URL` — **Required for TP/SL.** In production, set to the public URL of your keeper (e.g. `https://keeper.yourdomain.com`). Defaults to `http://localhost:3100` if unset. The keeper must be reachable from the user's browser (CORS enabled).
   - `VITE_PERP_DEX_ADDRESS=0xBEADF3313680e24F2943337d1fD0304B72DE48C2`, `VITE_TOKEN_ADDRESS=0x277E42B9454fB36A7Eaa52D4cE332bEF71dd017a`, `VITE_REWARD_ADDRESS=0x79591db65Ae8212F15fbe30B35033d7F58631bE0` (these values are printed by `npx hardhat run scripts/deploy.ts --network polkadotTestnet`)
2. Install deps: `npm install` (or `pnpm`/`yarn`)
3. Build: `npm run build`
4. Serve `frontend/dist` via Nginx, Vercel, etc.

### Keeper Service
1. Create `.env` with:
   - `KEEPER_RPC_URL`, `DEX_CONTRACT_ADDRESS`, `KEEPER_PRIVATE_KEY`
   - `KEEPER_DB_URL` pointing to your database
   - `KEEPER_PORT=3100`
2. Run migrations (if Prisma): `npx prisma migrate deploy`
3. Start: `npm run start`
4. Ensure process listens on `/orders/tp-sl` and logs every TP/SL registration.

### Faucet Logic
- Confirm faucet wallet (env key) holds zUSDC.
- Ensure frontend uses `ethers` to send ERC20 transfer with that key.
- Implement cooldown (localStorage) so each wallet can claim once every 24h.

---

## 3. Contract: Enable Keeper (Required for TP/SL)
The PerpetualDEX contract must have `keeperClosePosition` and the keeper address set. After deploying the updated contract:

1. Get the keeper wallet address (derived from `KEEPER_PRIVATE_KEY`).
2. As contract **owner**, call `setKeeperAddress(keeperWalletAddress)` on the DEX contract (the new DEX address is `0xBEADF3313680e24F2943337d1fD0304B72DE48C2` once you deploy).
3. Or use the provided script (owner key from `PRIVATE_KEY`, keeper address derived from `KEEPER_PRIVATE_KEY`):
   ```bash
   # Ensure frontend/.env has the new DEX/reward addresses, PRIVATE_KEY (owner), and KEEPER_PRIVATE_KEY
   npx hardhat run scripts/setKeeper.ts --network polkadotTestnet
   ```

Without this, the keeper cannot close positions on-chain and TP/SL will not execute.

---

## 4. Running the Stack
1. Start the keeper service and monitor logs:
   - Check it receives POST `/orders/tp-sl`.
   - Verify price polling/Chainlink listener triggers `executeOnChainClose` when the mark price exceeds TP/SL.
2. Build & serve the frontend with the same contract address.
3. Test the faucet form: fill wallet, click “Get 1000 zUSDC”, confirm transaction hash & receipt.

---

## 5. Debugging Tips
| Issue | Cause | Fix |
| --- | --- | --- |
| TP/SL never fires | Keeper not running, keeper address not set, or order not in DB | Start keeper, call `setKeeperAddress` on contract, sync position via `POST /orders/sync` |
| Keeper fails to close | Gas nonce issues or wrong contract | Inspect keeper logs, add retry logic, confirm contract address |
| Faucet transactions not seen | Faucet key lacks tokens or RPC mismatch | Check faucet wallet balance, ensure RPC is correct, resend transfer manually |
| History resets after reload | LocalStorage keys not scoped by wallet | Confirm `storageKey` uses `address.toLowerCase()` and is persisted |

---

## 6. Recommended Process
- Use PM2/systemd to keep keeper + faucet (if separate) alive.
- Enable monitoring/alerting for keeper errors.
- Keep `.env` files out of git (add to `.gitignore`).
- Document any on-chain parameters for future contributors.

---

If you’d like me to turn this into a proper `README.md` file inside the repo, let me know and I can switch out of Ask mode to apply the changes directly.