# Zenit Keeper Service

Off-chain keeper that monitors open orders and automatically executes **Take Profit**, **Stop Loss**, and **Liquidation** closes on the Zenit Perpetual DEX smart contract.

## Architecture

```
 ┌─────────────┐      ┌──────────┐      ┌───────────────┐
 │  Pyth Price  │─────▶│  Watcher │─────▶│  Executor     │
 │  Feed (HTTP) │      │ (tick)   │      │ (viem tx)     │
 └─────────────┘      └────┬─────┘      └───────┬───────┘
                           │                     │
                      ┌────▼─────┐          ┌────▼─────┐
                      │  Prisma  │          │ Polkadot │
                      │  SQLite  │          │ EVM RPC  │
                      └──────────┘          └──────────┘
```

**Watcher** polls prices every N seconds → compares against open orders in DB → if TP/SL/liquidation triggered → **Executor** submits `closePosition` on-chain.

## Quick start

```bash
cd keeper
npm install
cp .env.example .env        # fill in KEEPER_PRIVATE_KEY
npx prisma generate
npx prisma db push           # creates SQLite file
npm run dev                  # starts watcher with hot-reload
```

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Run with hot-reload (tsx watch) |
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
│   ├── executor.ts         # On-chain close tx via viem
│   ├── index.ts            # Entry point + main loop
│   ├── price.ts            # Pyth price feed client
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

## Environment variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | Prisma connection string | `file:./dev.db` |
| `RPC_URL` | Polkadot EVM RPC | `https://eth-rpc-testnet.polkadot.io/` |
| `CHAIN_ID` | Chain ID | `420420417` |
| `PERP_DEX_ADDRESS` | DEX contract address | — |
| `TOKEN_ADDRESS` | zUSDC token address | — |
| `KEEPER_PRIVATE_KEY` | Wallet private key for signing close txs | — |
| `PYTH_ENDPOINT` | Pyth Hermes API | `https://hermes.pyth.network` |
| `POLL_INTERVAL_MS` | Polling interval in ms | `5000` |
