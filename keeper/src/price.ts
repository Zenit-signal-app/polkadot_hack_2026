import type { Market, PriceTick } from "./types.js";
import { config } from "./config.js";
import { log } from "./logger.js";

// ─── Pyth Hermes price IDs ──────────────────────────────────────────────────
const PYTH_PRICE_IDS: Record<Market, string> = {
  BTCUSD: "e62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43",
  ETHUSD: "ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace",
  DOTUSD: "ca3eed9b267293f6595a7585f9c67014571fbbeca9dd1f55dee3de6e3f8b7868",
};

// ─── Chainlink-style on-chain aggregator addresses (Ethereum mainnet) ────────
// Extend this map if you deploy on a chain with Chainlink feeds
const CHAINLINK_FEEDS: Record<Market, `0x${string}`> = {
  BTCUSD: "0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c",
  ETHUSD: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
  DOTUSD: "0x1C07AFb8E2B827c5A4739C6d59Ae3A5035f28734",
};

const CHAINLINK_AGG_ABI = [
  {
    inputs: [],
    name: "latestRoundData",
    outputs: [
      { name: "roundId", type: "uint80" },
      { name: "answer", type: "int256" },
      { name: "startedAt", type: "uint256" },
      { name: "updatedAt", type: "uint256" },
      { name: "answeredInRound", type: "uint80" },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "decimals",
    outputs: [{ type: "uint8" }],
    stateMutability: "view",
    type: "function",
  },
] as const;

// ─── Pyth fetch (primary – works on any chain) ──────────────────────────────

async function fetchPythPrices(): Promise<PriceTick[]> {
  const ids = Object.values(PYTH_PRICE_IDS);
  const markets = Object.keys(PYTH_PRICE_IDS) as Market[];
  const params = ids.map((id) => `ids[]=${id}`).join("&");

  const res = await fetch(
    `${config.pythEndpoint}/api/latest_price_feeds?${params}`,
  );
  if (!res.ok) throw new Error(`Pyth HTTP ${res.status}`);

  const feeds = (await res.json()) as Array<{
    price: { price: string; expo: number };
    id: string;
  }>;

  const ticks: PriceTick[] = feeds.map((feed, i) => {
    const raw = Number(feed.price.price);
    const expo = feed.price.expo;
    return {
      market: markets[i],
      price: raw * 10 ** expo,
      timestamp: Date.now(),
    };
  });

  return ticks;
}

// ─── Chainlink fetch (alternative – requires on-chain read) ─────────────────

let chainlinkClient: ReturnType<typeof import("viem").createPublicClient> | null = null;

async function getChainlinkClient() {
  if (chainlinkClient) return chainlinkClient;
  const { createPublicClient, http, defineChain } = await import("viem");
  const chain = defineChain({
    id: config.chainId,
    name: "Polkadot Hub TestNet",
    nativeCurrency: { name: "PAS", symbol: "PAS", decimals: 10 },
    rpcUrls: { default: { http: [config.rpcUrl] } },
  });
  chainlinkClient = createPublicClient({ chain, transport: http(config.rpcUrl) });
  return chainlinkClient;
}

async function fetchChainlinkPrices(): Promise<PriceTick[]> {
  const client = await getChainlinkClient();
  const markets = Object.keys(CHAINLINK_FEEDS) as Market[];
  const ticks: PriceTick[] = [];

  for (const market of markets) {
    try {
      const [, answer] = (await client.readContract({
        address: CHAINLINK_FEEDS[market],
        abi: CHAINLINK_AGG_ABI,
        functionName: "latestRoundData",
      })) as [bigint, bigint, bigint, bigint, bigint];

      const decimals = (await client.readContract({
        address: CHAINLINK_FEEDS[market],
        abi: CHAINLINK_AGG_ABI,
        functionName: "decimals",
      })) as number;

      const price = Number(answer) / 10 ** decimals;
      ticks.push({ market, price, timestamp: Date.now() });
    } catch (err) {
      log.warn("price", `Chainlink feed unavailable for ${market}`, {
        error: err instanceof Error ? err.message : String(err),
      });
    }
  }

  return ticks;
}

// ─── Public API: try Pyth first, fall back to Chainlink ─────────────────────

export async function fetchPrices(): Promise<PriceTick[]> {
  try {
    const ticks = await fetchPythPrices();
    if (ticks.length > 0) {
      log.info("price", `Pyth prices fetched`, {
        prices: Object.fromEntries(ticks.map((t) => [t.market, `$${t.price.toFixed(2)}`])),
      });
      return ticks;
    }
  } catch (err) {
    log.warn("price", "Pyth feed failed, falling back to Chainlink", {
      error: err instanceof Error ? err.message : String(err),
    });
  }

  try {
    const ticks = await fetchChainlinkPrices();
    log.info("price", `Chainlink prices fetched`, {
      prices: Object.fromEntries(ticks.map((t) => [t.market, `$${t.price.toFixed(2)}`])),
    });
    return ticks;
  } catch (err) {
    log.error("price", "All price feeds failed", {
      error: err instanceof Error ? err.message : String(err),
    });
    return [];
  }
}
