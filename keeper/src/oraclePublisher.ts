import { ethers } from "ethers";
import { config } from "./config.js";
import { symbolToBytes32 } from "./abi.js";
import { log } from "./logger.js";
import type { PriceTick } from "./types.js";

const TAG = "oracle";

const provider = new ethers.JsonRpcProvider(config.rpcUrl, {
  chainId: config.chainId,
  name: "polkadot-hub-testnet",
});

const wallet = new ethers.Wallet(config.keeperPrivateKey, provider);

const ORACLE_ABI = [
  "function setPrices(bytes32[] markets, uint256[] prices) external",
  "function updater() view returns (address)",
];

export async function publishOraclePrices(prices: PriceTick[]): Promise<void> {
  if (!config.oracleAddress) return;
  if (prices.length === 0) return;

  const oracle = new ethers.Contract(config.oracleAddress, ORACLE_ABI, wallet);
  const markets: string[] = [];
  const values: bigint[] = [];

  for (const p of prices) {
    markets.push(symbolToBytes32(p.market));
    // Convert number USD price to 1e18
    values.push(ethers.parseUnits(p.price.toFixed(8), 18));
  }

  try {
    const tx = await oracle.setPrices(markets, values);
    log.info(TAG, "Oracle prices tx sent", { txHash: tx.hash, count: prices.length });
    await tx.wait();
    log.info(TAG, "Oracle prices updated", { txHash: tx.hash });
  } catch (err) {
    log.warn(TAG, "Failed to publish oracle prices", {
      error: err instanceof Error ? err.message : String(err),
    });
  }
}

