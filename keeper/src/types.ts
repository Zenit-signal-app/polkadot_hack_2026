// ─── Enums ───────────────────────────────────────────────────────────────────

export type Side = "Long" | "Short";

export type OrderStatus =
  | "Open"
  | "Closed"
  | "Filled"
  | "Liquidated"
  | "Cancelled";

export type Market = "BTCUSD" | "ETHUSD" | "DOTUSD";

// ─── Core order interface (mirrors Prisma model) ─────────────────────────────

export interface Order {
  id: string;
  createdAt: Date;
  updatedAt: Date;

  walletAddress: string;
  market: Market;
  side: Side;

  /** Margin deposited (zUSDC) – string to preserve bigint precision */
  marginAmount: string;
  /** Leverage multiplier (1–25) */
  leverage: number;
  /** Effective size = margin × leverage */
  positionSize: string;

  /** Price when position was opened */
  entryPrice: number;
  /** Estimated liquidation price */
  liquidationPrice: number;

  /** Absolute take-profit price (null = no TP set) */
  takeProfitPrice: number | null;
  /** Absolute stop-loss price (null = no SL set) */
  stopLossPrice: number | null;

  status: OrderStatus;

  /** Price when closed/filled */
  closePrice: number | null;

  openTxHash: string | null;
  closeTxHash: string | null;

  openedAt: Date;
  closedAt: Date | null;
}

// ─── DTO for creating a new order ────────────────────────────────────────────

export interface CreateOrderInput {
  walletAddress: string;
  market: Market;
  side: Side;
  marginAmount: string;
  leverage: number;
  entryPrice: number;
  liquidationPrice: number;
  takeProfitPrice?: number | null;
  stopLossPrice?: number | null;
  openTxHash?: string;
  openEventId?: string;
  openLogIndex?: number;
}

// ─── Price tick from the feed ────────────────────────────────────────────────

export interface PriceTick {
  market: Market;
  price: number;
  timestamp: number;
}

// ─── On-chain event payloads ─────────────────────────────────────────────────

export interface PositionClosedEvent {
  user: `0x${string}`;
  market: `0x${string}`;
  amount: bigint;
  pnl: bigint;
  txHash: string;
  blockNumber: bigint;
  logIndex: number;
}

export interface ClosureStats {
  positionId: string;
  walletAddress: string;
  market: string;
  side: Side;
  entryPrice: number;
  closePrice: number | null;
  pnl: string;
  positionSize: string;
  leverage: number;
  durationMs: number;
  closeTxHash: string;
  closedAt: Date;
}

// ─── Gas estimation ──────────────────────────────────────────────────────────

export type GasEstimate =
  | {
      type: "eip1559";
      maxFeePerGas: bigint;
      maxPriorityFeePerGas: bigint;
      gasPrice?: never;
    }
  | {
      type: "legacy";
      gasPrice: bigint;
      maxFeePerGas?: never;
      maxPriorityFeePerGas?: never;
    };

// ─── Transaction result ──────────────────────────────────────────────────────

export interface TxResult {
  success: boolean;
  txHash: string | null;
  gasUsed: bigint | null;
  blockNumber: number | null;
  keeperReward: bigint | null;
  error: string | null;
  attempts: number;
}

// ─── Retry configuration ─────────────────────────────────────────────────────

export interface RetryConfig {
  maxAttempts: number;
  initialDelayMs: number;
  maxDelayMs: number;
  backoffMultiplier: number;
  gasBumpOnRetry: boolean;
  gasBumpPct: bigint;
  receiptTimeoutMs: number;
}

// ─── Keeper config ───────────────────────────────────────────────────────────

export interface KeeperConfig {
  rpcUrl: string;
  chainId: number;
  perpDexAddress: `0x${string}`;
  tokenAddress: `0x${string}`;
  keeperPrivateKey: `0x${string}`;
  pollIntervalMs: number;
  pythEndpoint: string;
  apiPort: number;
  /** Maintenance margin rate used for liquidation estimation (e.g. 0.01 = 1%) */
  liquidationMmr: number;
  /** Absolute path to sqlite db file (best-effort) */
  sqliteDbPath: string | null;
  /** Backup output directory */
  backupDir: string;
  /** Backup interval */
  backupIntervalMs: number;
  /** Keep at most N backup files */
  backupMaxFiles: number;
  oracleAddress: `0x${string}` | null;
}
