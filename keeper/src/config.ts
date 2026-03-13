import "dotenv/config";
import type { KeeperConfig } from "./types.js";

function env(key: string, fallback?: string): string {
  const value = process.env[key] ?? fallback;
  if (!value) throw new Error(`Missing env var: ${key}`);
  return value;
}

export const config: KeeperConfig = {
  rpcUrl: env("RPC_URL", "https://eth-rpc-testnet.polkadot.io/"),
  chainId: Number(env("CHAIN_ID", "420420417")),
  perpDexAddress: env("PERP_DEX_ADDRESS", "0xa8de3e548054417e4d918FAC46E990aF623AC7BA") as `0x${string}`,
  tokenAddress: env("TOKEN_ADDRESS", "0x277E42B9454fB36A7Eaa52D4cE332bEF71dd017a") as `0x${string}`,
  keeperPrivateKey: env("KEEPER_PRIVATE_KEY") as `0x${string}`,
  pollIntervalMs: Number(env("POLL_INTERVAL_MS", "5000")),
  pythEndpoint: env("PYTH_ENDPOINT", "https://hermes.pyth.network"),
  apiPort: Number(env("API_PORT", "3100")),
};
