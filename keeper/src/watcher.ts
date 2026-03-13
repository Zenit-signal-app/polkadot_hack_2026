import { getOpenOrders, closeOrder } from "./db.js";
import { fetchPrices } from "./price.js";
import { executeOnChainClose } from "./executor.js";
import { log } from "./logger.js";
import type { Order, Market } from "./types.js";

// ─── Trigger condition helpers ───────────────────────────────────────────────

function shouldTakeProfit(order: Order, price: number): boolean {
  if (order.takeProfitPrice == null) return false;
  return order.side === "Long"
    ? price >= order.takeProfitPrice
    : price <= order.takeProfitPrice;
}

function shouldStopLoss(order: Order, price: number): boolean {
  if (order.stopLossPrice == null) return false;
  return order.side === "Long"
    ? price <= order.stopLossPrice
    : price >= order.stopLossPrice;
}

function shouldLiquidate(order: Order, price: number): boolean {
  return order.side === "Long"
    ? price <= order.liquidationPrice
    : price >= order.liquidationPrice;
}

// ─── Core: processOpenPositions ──────────────────────────────────────────────

export async function processOpenPositions(): Promise<void> {
  const tag = "watcher";

  let orders: Order[];
  try {
    orders = await getOpenOrders();
  } catch (err) {
    log.error(tag, "Failed to fetch open orders from database", {
      error: err instanceof Error ? err.message : String(err),
    });
    return;
  }

  if (orders.length === 0) {
    log.info(tag, "No open positions to monitor");
    return;
  }

  log.info(tag, `Monitoring ${orders.length} open position(s)`);

  let prices: Awaited<ReturnType<typeof fetchPrices>>;
  try {
    prices = await fetchPrices();
  } catch (err) {
    log.error(tag, "Failed to fetch prices from oracle", {
      error: err instanceof Error ? err.message : String(err),
    });
    return;
  }

  if (prices.length === 0) {
    log.warn(tag, "Price feed returned empty – skipping this cycle");
    return;
  }

  const priceMap = new Map<Market, number>();
  for (const p of prices) priceMap.set(p.market, p.price);

  let triggered = 0;

  for (const order of orders) {
    const currentPrice = priceMap.get(order.market as Market);

    if (currentPrice == null) {
      log.warn(tag, `No price data for ${order.market} – skipping order`, {
        orderId: order.id,
      });
      continue;
    }

    const tpDist = order.takeProfitPrice != null
      ? `$${Math.abs(currentPrice - order.takeProfitPrice).toFixed(2)} (${((Math.abs(currentPrice - order.takeProfitPrice) / currentPrice) * 100).toFixed(2)}%)`
      : "not set";
    const slDist = order.stopLossPrice != null
      ? `$${Math.abs(currentPrice - order.stopLossPrice).toFixed(2)} (${((Math.abs(currentPrice - order.stopLossPrice) / currentPrice) * 100).toFixed(2)}%)`
      : "not set";
    const liqDist = `$${Math.abs(currentPrice - order.liquidationPrice).toFixed(2)} (${((Math.abs(currentPrice - order.liquidationPrice) / currentPrice) * 100).toFixed(2)}%)`;

    log.info(tag, `Checking ${order.market} ${order.side} #${order.id.slice(0, 8)}`, {
      currentPrice: `$${currentPrice.toFixed(2)}`,
      entryPrice: `$${order.entryPrice.toFixed(2)}`,
      tp: order.takeProfitPrice != null ? `$${order.takeProfitPrice.toFixed(2)}` : "—",
      sl: order.stopLossPrice != null ? `$${order.stopLossPrice.toFixed(2)}` : "—",
      liq: `$${order.liquidationPrice.toFixed(2)}`,
      distToTP: tpDist,
      distToSL: slDist,
      distToLiq: liqDist,
    });

    let reason: "Liquidated" | "Filled" | "Closed" | null = null;

    if (shouldLiquidate(order, currentPrice)) {
      reason = "Liquidated";
      log.warn(tag, `LIQUIDATION triggered`, {
        orderId: order.id,
        market: order.market,
        side: order.side,
        currentPrice: `$${currentPrice.toFixed(2)}`,
        liquidationPrice: `$${order.liquidationPrice.toFixed(2)}`,
      });
    } else if (shouldTakeProfit(order, currentPrice)) {
      reason = "Filled";
      log.action(tag, `TAKE PROFIT triggered`, {
        orderId: order.id,
        market: order.market,
        side: order.side,
        currentPrice: `$${currentPrice.toFixed(2)}`,
        takeProfitPrice: `$${order.takeProfitPrice!.toFixed(2)}`,
      });
    } else if (shouldStopLoss(order, currentPrice)) {
      reason = "Closed";
      log.action(tag, `STOP LOSS triggered`, {
        orderId: order.id,
        market: order.market,
        side: order.side,
        currentPrice: `$${currentPrice.toFixed(2)}`,
        stopLossPrice: `$${order.stopLossPrice!.toFixed(2)}`,
      });
    }

    if (!reason) continue;

    triggered++;

    // Execute close on-chain (with retry logic, gas optimization, nonce management)
    let txHash: string | null = null;
    try {
      const result = await executeOnChainClose(order, currentPrice);

      txHash = result.txHash;

      if (result.success) {
        log.info(tag, `On-chain close succeeded`, {
          orderId: order.id,
          txHash: result.txHash,
          gasUsed: result.gasUsed?.toString(),
          keeperReward: result.keeperReward?.toString() ?? "none",
          attempts: result.attempts,
        });
      } else {
        log.error(tag, `On-chain close failed`, {
          orderId: order.id,
          error: result.error,
          attempts: result.attempts,
        });
      }
    } catch (err) {
      log.error(tag, `executeOnChainClose threw unexpectedly`, {
        orderId: order.id,
        reason,
        error: err instanceof Error ? err.message : String(err),
      });
    }

    // Update database regardless of tx success – we still track the trigger
    try {
      await closeOrder(order.id, reason, currentPrice, txHash ?? undefined);
      log.info(tag, `DB updated: order ${order.id.slice(0, 8)} → ${reason}`, {
        closePrice: `$${currentPrice.toFixed(2)}`,
        txHash: txHash ?? "none (tx failed)",
      });
    } catch (err) {
      log.error(tag, `Failed to update order in DB after close`, {
        orderId: order.id,
        reason,
        error: err instanceof Error ? err.message : String(err),
      });
    }
  }

  if (triggered > 0) {
    log.info(tag, `Cycle complete: ${triggered}/${orders.length} position(s) triggered`);
  } else {
    log.info(tag, `Cycle complete: all ${orders.length} position(s) safe`);
  }
}

/** @deprecated Use processOpenPositions() instead */
export const tick = processOpenPositions;
