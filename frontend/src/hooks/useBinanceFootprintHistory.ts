import { useState, useEffect, useRef } from "react";
import { FootprintBar } from "@/hooks/binanceFootprintTypes";
import { BinanceFootprintManager } from "@/hooks/useBinanceFootprint";

interface AggTrade {
  T: number;   // trade time ms
  p: string;   // price
  q: string;   // quantity
  m: boolean;  // isBuyerMaker → true = sell order hit bid
}

function aggregateToBars(
  trades: AggTrade[],
  barSeconds: number,
  priceBin: number
): FootprintBar[] {
  const barsMap = new Map<number, FootprintBar>();
  const decimals = Math.max(0, -Math.floor(Math.log10(priceBin)));

  for (const trade of trades) {
    const ts = trade.T / 1000;
    const barStart = Math.floor(ts / barSeconds) * barSeconds;
    const price = Number(trade.p);
    const qty = Number(trade.q);
    const levelPrice = Math.round(price / priceBin) * priceBin;
    const level = levelPrice.toFixed(decimals);

    if (!barsMap.has(barStart)) {
      barsMap.set(barStart, {
        barStart,
        barEnd: barStart + barSeconds,
        open: price,
        high: price,
        low: price,
        close: price,
        clusters: {},
      });
    }

    const bar = barsMap.get(barStart)!;
    bar.high = Math.max(bar.high, price);
    bar.low = Math.min(bar.low, price);
    bar.close = price;

    if (!bar.clusters[level]) {
      bar.clusters[level] = { buy_vol: 0, sell_vol: 0, total_vol: 0 };
    }
    const c = bar.clusters[level];
    if (trade.m) {
      c.sell_vol += qty;
    } else {
      c.buy_vol += qty;
    }
    c.total_vol += qty;
  }

  for (const bar of barsMap.values()) {
    let vpocLevel = "";
    let vpocVol = 0;
    for (const [level, c] of Object.entries(bar.clusters)) {
      if (c.total_vol > vpocVol) {
        vpocVol = c.total_vol;
        vpocLevel = level;
      }
    }
    bar.vpocPrice = vpocLevel;
  }

  return Array.from(barsMap.values()).sort((a, b) => a.barStart - b.barStart);
}

async function fetchAggTrades(
  symbol: string,
  startMs: number,
  endMs: number,
  maxRequests = 5
): Promise<AggTrade[]> {
  const all: AggTrade[] = [];
  let fromMs = startMs;
  let requests = 0;

  while (fromMs < endMs && requests < maxRequests) {
    const url =
      `https://fapi.binance.com/fapi/v1/aggTrades` +
      `?symbol=${symbol}&startTime=${fromMs}&endTime=${endMs}&limit=1000`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Binance API ${res.status}`);
    const batch: AggTrade[] = await res.json();
    requests++;
    if (batch.length === 0) break;
    all.push(...batch);
    if (batch.length < 1000) break;
    fromMs = batch[batch.length - 1].T + 1;
  }

  return all;
}

/** Convert TradingView resolution string to seconds */
export function tvResolutionToSeconds(resolution: string): number {
  const r = String(resolution ?? "1").trim().toUpperCase();
  if (r === "1D" || r === "D") return 86400;
  if (r === "1W" || r === "W") return 604800;
  if (r === "1M" || r === "M") return 2592000;
  const n = parseInt(r, 10);
  if (!isNaN(n)) return n * 60;
  return 60;
}

/** Max bars that can be accurately fetched given bar size and max API requests */
function adaptiveNumBars(barSeconds: number): { numBars: number; maxRequests: number } {
  if (barSeconds <= 60)   return { numBars: 10, maxRequests: 6 };
  if (barSeconds <= 300)  return { numBars: 8,  maxRequests: 6 };
  if (barSeconds <= 900)  return { numBars: 6,  maxRequests: 5 };
  if (barSeconds <= 1800) return { numBars: 4,  maxRequests: 4 };
  if (barSeconds <= 3600) return { numBars: 3,  maxRequests: 4 };
  // Daily or longer — return 1-2 bars with sampled data
  return { numBars: 2, maxRequests: 3 };
}

export default function useBinanceFootprintHistory(
  symbol: string = "BTCUSDT",
  barSeconds: number = 60,
  priceBin: number = 100,
  numBarsOverride?: number,
  refreshMs: number = 60_000
) {
  const [bars, setBars] = useState<FootprintBar[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cancelRef = useRef(false);
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimer = useRef<number | null>(null);
  const shouldReconnect = useRef(true);

  const adaptiveParams = adaptiveNumBars(barSeconds);
  const baseNumBars = adaptiveParams.numBars;
  const baseMaxRequests = adaptiveParams.maxRequests;
  const effectiveNumBars = numBarsOverride ?? baseNumBars;
  const requestMultiplier = Math.max(1, Math.ceil(effectiveNumBars / baseNumBars));
  const maxRequests = baseMaxRequests * requestMultiplier;

  useEffect(() => {
    cancelRef.current = false;

    const load = async () => {
      try {
        setLoading(true);
        setError(null);

        const nowMs = Date.now();
        const currentBarStart = Math.floor(nowMs / 1000 / barSeconds) * barSeconds * 1000;
        const startMs = currentBarStart - effectiveNumBars * barSeconds * 1000;

        const trades = await fetchAggTrades(symbol, startMs, nowMs, maxRequests);
        if (cancelRef.current) return;

        const aggregated = aggregateToBars(trades, barSeconds, priceBin);
        setBars(aggregated);
      } catch (e: unknown) {
        if (!cancelRef.current) {
          setError(e instanceof Error ? e.message : "Fetch error");
        }
      } finally {
        if (!cancelRef.current) setLoading(false);
      }
    };

    load();
    const timer = setInterval(load, refreshMs);
    return () => {
      cancelRef.current = true;
      clearInterval(timer);
    };
  }, [symbol, barSeconds, priceBin, numBarsOverride, refreshMs, effectiveNumBars, maxRequests]);

  useEffect(() => {
    shouldReconnect.current = true;
    const manager = new BinanceFootprintManager(barSeconds, priceBin);
    const wsSymbol = symbol.toLowerCase();
    const connect = () => {
      const ws = new WebSocket(`wss://fstream.binance.com/ws/${wsSymbol}@aggTrade`);
      wsRef.current = ws;
      ws.onmessage = (event) => {
        try {
          const payload = JSON.parse(event.data);
          const completedBar = manager.processTrade(payload);
          if (completedBar) {
            setBars((prev) => {
              const next = [...prev, completedBar];
              if (next.length > effectiveNumBars) {
                next.splice(0, next.length - effectiveNumBars);
              }
              return next;
            });
          }
        } catch (error) {
          console.error("Footprint history websocket error", error);
        }
      };
      ws.onclose = () => {
        if (shouldReconnect.current) {
          reconnectTimer.current = window.setTimeout(connect, 1000);
        }
      };
      ws.onerror = () => {
        ws.close();
      };
    };

    connect();
    return () => {
      shouldReconnect.current = false;
      if (reconnectTimer.current) clearTimeout(reconnectTimer.current);
      wsRef.current?.close();
    };
  }, [symbol, barSeconds, priceBin, effectiveNumBars]);

  return { bars, loading, error };
}
