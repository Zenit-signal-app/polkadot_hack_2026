import Decimal from "decimal.js";

export interface PnLResult {
  pnl: number;
  roi: number;
  isProfit: boolean;
  formattedPnL: string;
  color: "#22c55e" | "#ef4444";
}

const currencyFormatter = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

export const calculatePositionPnL = (
  side: "Long" | "Short",
  entryPrice: number,
  markPrice: number,
  margin: number,
  leverage: number,
): PnLResult => {
  if (margin === 0 || entryPrice === 0) {
    return {
      pnl: 0,
      roi: 0,
      isProfit: true,
      formattedPnL: `${currencyFormatter.format(0)} (0.00%)`,
      color: "#22c55e",
    };
  }

  const size = new Decimal(margin).mul(leverage);
  const entry = new Decimal(entryPrice);
  const mark = new Decimal(markPrice);
  const baseDelta = side === "Long" ? mark.sub(entry) : entry.sub(mark);
  const pnlDecimal = baseDelta.div(entry).mul(size);
  const roiDecimal = pnlDecimal.div(margin).mul(100);
  const pnl = Number(pnlDecimal.toNumber());
  const roi = Number(roiDecimal.toNumber());
  const isProfit = pnlDecimal.gte(0);
  const sign = isProfit && pnl === 0 ? "" : isProfit ? "+" : "-";
  const formattedPnL = `${sign}${currencyFormatter.format(Math.abs(pnl))} (${roi.toFixed(2)}%)`;

  return {
    pnl,
    roi,
    isProfit,
    formattedPnL,
    color: isProfit ? "#22c55e" : "#ef4444",
  };
};

export function calculateLiquidationPrice(
  side: "Long" | "Short",
  entryPrice: number,
  leverage: number,
  maintenanceMarginRate = 0.01,
): string {
  if (entryPrice <= 0 || leverage <= 0) {
    return "0.00";
  }

  const entry = new Decimal(entryPrice);
  const leverageDec = new Decimal(leverage);
  const mmrDec = new Decimal(maintenanceMarginRate);
  const invLeverage = Decimal.div(1, leverageDec);

  const liability = side === "Long"
    ? entry.mul(new Decimal(1).sub(invLeverage).add(mmrDec))
    : entry.mul(new Decimal(1).add(invLeverage).sub(mmrDec));

  return liability.toFixed(2);
}
