import { PrismaClient } from "@prisma/client";
import type { CreateOrderInput, Order, OrderStatus } from "./types.js";

const prisma = new PrismaClient();

export async function createOrder(input: CreateOrderInput): Promise<Order> {
  const positionSize = String(Number(input.marginAmount) * input.leverage);

  return prisma.order.create({
    data: {
      walletAddress: input.walletAddress,
      market: input.market,
      side: input.side,
      marginAmount: input.marginAmount,
      leverage: input.leverage,
      positionSize,
      entryPrice: input.entryPrice,
      liquidationPrice: input.liquidationPrice,
      takeProfitPrice: input.takeProfitPrice ?? null,
      stopLossPrice: input.stopLossPrice ?? null,
      openTxHash: input.openTxHash ?? null,
    },
  }) as unknown as Order;
}

export async function getOpenOrders(): Promise<Order[]> {
  return prisma.order.findMany({
    where: { status: "Open" },
    orderBy: { createdAt: "asc" },
  }) as unknown as Order[];
}

/**
 * Find the most recent open order matching a wallet address and market.
 * Used by the event listener to correlate on-chain PositionClosed events
 * back to our off-chain order records.
 */
export async function findOpenOrderByWalletAndMarket(
  walletAddress: string,
  market: string,
): Promise<Order | null> {
  const order = await prisma.order.findFirst({
    where: {
      walletAddress: walletAddress.toLowerCase(),
      market,
      status: "Open",
    },
    orderBy: { createdAt: "desc" },
  });
  return (order as unknown as Order) ?? null;
}

export async function closeOrder(
  id: string,
  status: OrderStatus,
  closePrice: number,
  closeTxHash?: string,
): Promise<Order> {
  return prisma.order.update({
    where: { id },
    data: {
      status,
      closePrice,
      closeTxHash: closeTxHash ?? null,
      closedAt: new Date(),
    },
  }) as unknown as Order;
}

/**
 * Mark an order as Closed specifically in response to an on-chain event.
 * Separate from closeOrder to provide a cleaner API for the event listener,
 * where we may not have a closePrice from our oracle feed.
 */
export async function markClosedByEvent(
  id: string,
  closeTxHash: string,
  closePrice?: number,
): Promise<Order> {
  return prisma.order.update({
    where: { id },
    data: {
      status: "Closed",
      closePrice: closePrice ?? null,
      closeTxHash,
      closedAt: new Date(),
    },
  }) as unknown as Order;
}

/**
 * Update TP/SL for an existing order. Called by the REST API when
 * the frontend registers take-profit / stop-loss after opening a position.
 */
export async function updateOrderTpSl(
  id: string,
  takeProfitPrice: number | null,
  stopLossPrice: number | null,
): Promise<Order> {
  return prisma.order.update({
    where: { id },
    data: { takeProfitPrice, stopLossPrice },
  }) as unknown as Order;
}

/**
 * Update TP/SL by wallet + market (finds the latest open order).
 */
export async function updateTpSlByWalletAndMarket(
  walletAddress: string,
  market: string,
  takeProfitPrice: number | null,
  stopLossPrice: number | null,
): Promise<Order | null> {
  const order = await prisma.order.findFirst({
    where: {
      walletAddress: walletAddress.toLowerCase(),
      market,
      status: "Open",
    },
    orderBy: { createdAt: "desc" },
  });
  if (!order) return null;
  return prisma.order.update({
    where: { id: order.id },
    data: { takeProfitPrice, stopLossPrice },
  }) as unknown as Order;
}

export async function getOrderById(id: string): Promise<Order | null> {
  const order = await prisma.order.findUnique({ where: { id } });
  return (order as unknown as Order) ?? null;
}

export async function getAllOrders(limit = 100): Promise<Order[]> {
  return prisma.order.findMany({
    orderBy: { createdAt: "desc" },
    take: limit,
  }) as unknown as Order[];
}

export { prisma };
