import Fastify from "fastify";
import cors from "@fastify/cors";
import { config } from "./config.js";
import {
  getOpenOrders,
  getAllOrders,
  getOrderById,
  updateOrderTpSl,
  updateTpSlByWalletAndMarket,
} from "./db.js";
import { log } from "./logger.js";

const TAG = "api";

export async function startApi(): Promise<void> {
  const app = Fastify({ logger: false });

  await app.register(cors, { origin: true });

  // ─── Health check ──────────────────────────────────────────────────────────

  app.get("/health", async () => ({
    status: "ok",
    chain: config.chainId,
    contract: config.perpDexAddress,
    uptime: process.uptime(),
  }));

  // ─── GET /orders — list all orders ─────────────────────────────────────────

  app.get<{
    Querystring: { status?: string; limit?: string };
  }>("/orders", async (req) => {
    const limit = Math.min(Number(req.query.limit) || 100, 500);

    if (req.query.status === "Open") {
      return getOpenOrders();
    }
    return getAllOrders(limit);
  });

  // ─── GET /orders/:id — get single order ────────────────────────────────────

  app.get<{ Params: { id: string } }>("/orders/:id", async (req, reply) => {
    const order = await getOrderById(req.params.id);
    if (!order) {
      reply.status(404);
      return { error: "Order not found" };
    }
    return order;
  });

  // ─── PUT /orders/:id/tp-sl — update TP/SL by order ID ─────────────────────

  app.put<{
    Params: { id: string };
    Body: { takeProfitPrice?: number | null; stopLossPrice?: number | null };
  }>("/orders/:id/tp-sl", async (req, reply) => {
    const { id } = req.params;
    const { takeProfitPrice, stopLossPrice } = req.body ?? {};

    const existing = await getOrderById(id);
    if (!existing) {
      reply.status(404);
      return { error: "Order not found" };
    }
    if (existing.status !== "Open") {
      reply.status(400);
      return { error: `Cannot update TP/SL for order with status '${existing.status}'` };
    }

    const tp = takeProfitPrice !== undefined ? takeProfitPrice : existing.takeProfitPrice;
    const sl = stopLossPrice !== undefined ? stopLossPrice : existing.stopLossPrice;

    const updated = await updateOrderTpSl(id, tp, sl);

    log.info(TAG, `TP/SL updated via API`, {
      orderId: id,
      tp: tp != null ? `$${tp.toFixed(2)}` : "none",
      sl: sl != null ? `$${sl.toFixed(2)}` : "none",
    });

    return updated;
  });

  // ─── POST /orders/tp-sl — update TP/SL by wallet + market ─────────────────
  // This is what the frontend calls after opening a position

  app.post<{
    Body: {
      walletAddress: string;
      market: string;
      takeProfitPrice?: number | null;
      stopLossPrice?: number | null;
    };
  }>("/orders/tp-sl", async (req, reply) => {
    const { walletAddress, market, takeProfitPrice, stopLossPrice } =
      req.body ?? {};

    if (!walletAddress || !market) {
      reply.status(400);
      return { error: "walletAddress and market are required" };
    }

    const tp = takeProfitPrice ?? null;
    const sl = stopLossPrice ?? null;

    const updated = await updateTpSlByWalletAndMarket(
      walletAddress,
      market,
      tp,
      sl,
    );

    if (!updated) {
      reply.status(404);
      return {
        error: "No open order found for this wallet and market",
        walletAddress,
        market,
      };
    }

    log.info(TAG, `TP/SL registered via frontend`, {
      orderId: updated.id,
      wallet: walletAddress.slice(0, 10) + "...",
      market,
      tp: tp != null ? `$${tp.toFixed(2)}` : "none",
      sl: sl != null ? `$${sl.toFixed(2)}` : "none",
    });

    return updated;
  });

  // ─── Start server ──────────────────────────────────────────────────────────

  await app.listen({ port: config.apiPort, host: "0.0.0.0" });

  log.info(TAG, `REST API listening`, {
    port: config.apiPort,
    endpoints: [
      "GET  /health",
      "GET  /orders",
      "GET  /orders/:id",
      "PUT  /orders/:id/tp-sl",
      "POST /orders/tp-sl",
    ],
  });
}
