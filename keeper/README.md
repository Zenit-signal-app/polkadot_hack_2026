# Zenit Keeper Service

Off-chain service for Zenit Perpetual DEX. It handles:
- automatic TP/SL/Liquidation closes on-chain
- on-chain oracle price publishing (best-effort)
- zUSDC faucet claims with cooldown
- REST endpoints consumed by frontend (`/orders`, `/logs/recent`, `/cache/reset`, `/faucet/*`)
- cache-reset notifications per wallet after keeper auto-close

## Architecture

```
 ┌─────────────┐      ┌──────────┐      ┌───────────────┐
 │ Price Feeds │─────▶│  Watcher │─────▶│  Executor     │
 │ (DIA/Pyth/…)│      │ (tick)   │      │ (ethers tx)   │
 └─────────────┘      └────┬─────┘      └───────┬───────┘
                           │                     │
                      ┌────▼─────┐          ┌────▼─────┐
                      │  Prisma  │          │ Polkadot │
                      │  SQLite  │          │ EVM RPC  │
                      └──────────┘          └──────────┘

                     + separate Faucet signer
```

`txManager` serializes transactions per private key, so each signer has its own nonce queue.
Recommended setup:
- `KEEPER_PRIVATE_KEY`: only for close tx
- `FAUCET_PRIVATE_KEY`: separate wallet for faucet tx
- `ORACLE_PRIVATE_KEY` (optional): separate updater key for `ZenitOracle` oracle publishing

## Quick start

```bash
cd keeper
npm install
cp .env.example .env        # fill in KEEPER_PRIVATE_KEY + FAUCET_PRIVATE_KEY
npx prisma generate
npx prisma db push           # creates/updates SQLite file
npm run build
npm run start
```

Windows note: nếu `npx prisma generate` lỗi EPERM rename (query-engine dll), hãy dùng `npx prisma db push --skip-generate` rồi khởi động lại keeper.

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Run with hot-reload |
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start` | Run compiled JS |
| `npm run db:generate` | Regenerate Prisma client |
| `npm run db:push` | Push schema to database |
| `npm run db:migrate` | Create migration |
| `npm run db:studio` | Open Prisma Studio GUI |

## Project structure

```
keeper/
├── prisma/
│   └── schema.prisma       # Order model + enums
├── src/
│   ├── abi.ts              # PerpetualDEX ABI + helpers
│   ├── config.ts           # Env var loader
│   ├── db.ts               # Prisma CRUD operations
│   ├── executor.ts         # On-chain close tx
│   ├── faucet.ts           # zUSDC faucet transfer logic
│   ├── txManager.ts        # Per-key tx queue + nonce coordination
│   ├── nonceManager.ts     # Nonce sync/reset/rollback helper
│   ├── index.ts            # Entry point + main loop
│   ├── price.ts            # Pyth price feed client
│   ├── oraclePublisher.ts  # Push prices to ZenitOracle
│   ├── types.ts            # TypeScript interfaces
│   └── watcher.ts          # TP/SL/liquidation logic
├── .env.example
├── .gitignore
├── package.json
└── tsconfig.json
```

## Order lifecycle

1. Frontend opens a position → calls keeper API (or keeper listens to on-chain events) → row inserted with status `Open`
2. Watcher polls Pyth prices every `POLL_INTERVAL_MS`
3. For each open order, checks:
   - **Liquidation**: price crossed liquidation threshold → status `Liquidated`
   - **Take Profit**: price reached TP target → status `Filled`
   - **Stop Loss**: price reached SL target → status `Closed`
4. Executor submits `closePosition` on-chain, stores tx hash

Close reason codes persisted in DB (and used by the frontend UI):
- `closeReasonCode=0` = Manual close (user initiated)
- `closeReasonCode=1` = TP (keeper-triggered Take profit)
- `closeReasonCode=2` = SL (keeper-triggered Stop loss)
- `closeReasonCode=3` = Liquidated (forced liquidation)

In the database, keeper writes `status='Closed'` for all terminal outcomes; `close_reason` stores the detailed reason code.

## API endpoints (default `:3100`)

- `GET /health`
- `GET /diagnostic`
- `GET /orders?status=Open&limit=500`
- `GET /orders/:id`
- `PUT /orders/:id/tp-sl`
- `POST /orders/sync`
- `POST /orders/tp-sl`
- `GET /logs/recent?limit=200`
- `GET /cache/reset?wallet=0x...`
- `GET /faucet/status?wallet=0x...`
- `POST /faucet/zusdc`

## Environment variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | Prisma connection string | `file:./dev.db` |
| `RPC_URL` | Polkadot EVM RPC | `https://eth-rpc-testnet.polkadot.io/` |
| `CHAIN_ID` | Chain ID | `420420417` |
| `PERP_DEX_ADDRESS` | DEX contract address | — |
| `TOKEN_ADDRESS` | zUSDC token address | — |
| `KEEPER_PRIVATE_KEY` | Wallet private key for close/oracle txs | — |
| `FAUCET_PRIVATE_KEY` | Wallet private key for faucet txs (recommended separate) | falls back to `KEEPER_PRIVATE_KEY` |
| `ORACLE_PRIVATE_KEY` | Optional dedicated updater key for `ZenitOracle` | falls back to `KEEPER_PRIVATE_KEY` |
| `PYTH_ENDPOINT` | Pyth Hermes API | `https://hermes.pyth.network` |
| `POLL_INTERVAL_MS` | Polling interval in ms | `5000` |
| `API_PORT` | REST API listen port | `3100` |

## Operational notes

- Run only one keeper instance per signer wallet.
- Keep faucet wallet funded with both PAS (gas) and zUSDC.
- If RPC is strict, keep legacy transactions enabled for stability.
