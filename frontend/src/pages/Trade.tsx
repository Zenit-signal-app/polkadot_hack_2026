import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, usePublicClient } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { CONTRACTS } from "@/config/contracts";
import { PERPETUAL_DEX_ABI, symbolToBytes32 } from "@/abis/PerpetualDEX";
import { ERC20_ABI } from "@/abis/Token";
import IndicatorPanel from "@/components/IndicatorPanel";
import RadarSignalPanel from "@/components/RadarSignalPanel";
import FearGreedIndex from "@/components/FearGreedIndex";
import AIChatbotWidget from "@/components/AIChatbotWidget";
import TVChartContainer from "@/components/TVChartContainer";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { usePolkadotPrices, type PolkadotSymbol } from "@/hooks/usePolkadotPrices";
import { useChartPrice } from "@/hooks/useChartPrice";
import { calculatePositionPnL, calculateLiquidationPrice, type PnLResult } from "@/utils/tradeMath";
import Decimal from "decimal.js";

const POSITION_TYPE = { Long: 0, Short: 1 } as const;

type PositionData = { amount: bigint; position: number; leverage: number };
type HistoryEntry = {
  id: string;
  symbol?: PolkadotSymbol;
  action: "open" | "increase" | "close";
  type: "Long" | "Short" | "N/A";
  amount: string;
  leverage: number;
  entryPrice: number;
  closePrice?: number;
  status: "open" | "closed";
  timestamp: number;
  fee: number;
  takeProfit: number | null;
  stopLoss: number | null;
  volume: number | null;
};

const POLKADOT_SYMBOLS: PolkadotSymbol[] = ["BTCUSD", "ETHUSD", "DOTUSD"];

/** Pyth ticker format - must match chart datafeed for price sync */
const TRADINGVIEW_SYMBOL_MAP: Record<PolkadotSymbol, string> = {
  BTCUSD: "Crypto.BTC/USD",
  ETHUSD: "Crypto.ETH/USD",
  DOTUSD: "Crypto.DOT/USD",
};

const USD_FORMATTER = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const TIME_FORMATTER = new Intl.DateTimeFormat("en-US", {
  hour: "numeric",
  minute: "2-digit",
  hour12: true,
});
const DATE_PART_FORMATTER = new Intl.DateTimeFormat("en-US", {
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

const ZUSDC_FORMATTER = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

function formatZUSDC(value?: bigint | null) {
  if (value == null) return ZUSDC_FORMATTER.format(0);
  const num = Number(formatUnits(value, 18));
  if (Number.isNaN(num)) return ZUSDC_FORMATTER.format(0);
  return ZUSDC_FORMATTER.format(num);
}

function formatZUSDCNumber(value?: number) {
  if (value == null || Number.isNaN(value)) return ZUSDC_FORMATTER.format(0);
  return ZUSDC_FORMATTER.format(value);
}

function formatForSymbol(value: number | null | undefined, symbol?: PolkadotSymbol) {
  if (value == null) return "—";
  const decimals = symbol === "DOTUSD" ? 4 : 2;
  return `$${value.toLocaleString("en-US", {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  })}`;
}

function formatCurrency(value?: number | null) {
  if (value == null || Number.isNaN(value)) return "—";
  return USD_FORMATTER.format(value);
}

function formatTimestamp(timestamp: number) {
  const date = new Date(timestamp);
  return `${TIME_FORMATTER.format(date)} ${DATE_PART_FORMATTER.format(date)}`;
}

const HISTORY_STORAGE_PREFIX = "zenit-history";
function buildHistoryKey(type: "trade" | "deposit" | "withdraw", wallet?: string) {
  if (!wallet) return "";
  return `${HISTORY_STORAGE_PREFIX}-${type}-${wallet.toLowerCase()}`;
}
function readHistory<T>(key: string): T[] {
  if (!key) return [];
  if (typeof window === "undefined") return [];
  const raw = window.localStorage.getItem(key);
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}
function persistHistory<T>(key: string, data: T[]) {
  if (!key) return;
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(key, JSON.stringify(data));
  } catch {
    // ignore
  }
}

function calculatePnL(entry: HistoryEntry, currentPrice?: number) {
  if (!entry.entryPrice) return null;
  const referencePrice =
    entry.status === "closed" ? entry.closePrice ?? entry.entryPrice : currentPrice ?? entry.entryPrice;
  if (referencePrice == null) return null;
  const size = new Decimal(entry.amount).mul(entry.leverage);
  const entryPriceDec = new Decimal(entry.entryPrice);
  if (entryPriceDec.eq(0)) return null;
  const referencePriceDec = new Decimal(referencePrice);
  const delta = entry.type === "Short"
    ? entryPriceDec.sub(referencePriceDec)
    : referencePriceDec.sub(entryPriceDec);
  const pnl = delta.div(entryPriceDec).mul(size);
  return Number(pnl.toNumber());
}

interface PositionPnLDisplayProps {
  side: "Long" | "Short";
  entryPrice: number;
  margin: number;
  leverage: number;
  markPrice?: number;
}

function PositionPnLDisplay({ side, entryPrice, leverage, margin, markPrice }: PositionPnLDisplayProps) {
  const [pnlData, setPnlData] = useState<PnLResult | null>(null);
  const [flash, setFlash] = useState(false);

  useEffect(() => {
    if (markPrice == null) return;
    const result = calculatePositionPnL(side, entryPrice, markPrice, margin, leverage);
    setPnlData(result);
    setFlash(true);
    const timeout = setTimeout(() => setFlash(false), 100);
    return () => clearTimeout(timeout);
  }, [entryPrice, leverage, margin, markPrice, side]);

  if (!pnlData) return null;

  return (
    <div
      className={`rounded-xl border border-[#363a59] bg-[#0d0f18] px-4 py-3 text-sm font-semibold tracking-wide transition-[filter] duration-150 ${
        flash ? "filter brightness-125" : ""
      }`}
      style={{ color: pnlData.color }}
    >
      <div className="text-[10px] uppercase text-slate-400">Real-time PnL</div>
      <div className="mt-1 text-base">{pnlData.formattedPnL}</div>
    </div>
  );
}

export default function Trade() {
  const { address } = useAccount();
  const [depositAmount, setDepositAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [positionAmount, setPositionAmount] = useState("");
  const [leverage, setLeverage] = useState(2);
  const [positionType, setPositionType] = useState<"Long" | "Short">("Long");
  const [closeAmount, setCloseAmount] = useState("");
  const [activeTab, setActiveTab] = useState<"trade" | "deposit">("trade");

  const [chartSymbol, setChartSymbol] = useState<PolkadotSymbol>("BTCUSD");
  const [chartResolution, setChartResolution] = useState<string>("1D");
  const [chartRightOffset, setChartRightOffset] = useState<number>(30);
  const [historyTab, setHistoryTab] = useState<"timeline" | "open" | "closed">("timeline");
  const [tradeHistory, setTradeHistory] = useState<HistoryEntry[]>([]);
  const [depositHistory, setDepositHistory] = useState<Array<{ id: string; amount: number; timestamp: number }>>([]);
  const [withdrawHistory, setWithdrawHistory] = useState<Array<{ id: string; amount: number; timestamp: number }>>([]);

  useEffect(() => {
    if (!address) {
      setTradeHistory([]);
      setDepositHistory([]);
      setWithdrawHistory([]);
      return;
    }
    const tradeKey = buildHistoryKey("trade", address);
    const depositKey = buildHistoryKey("deposit", address);
    const withdrawKey = buildHistoryKey("withdraw", address);
    setTradeHistory(readHistory<HistoryEntry>(tradeKey));
    setDepositHistory(readHistory<{ id: string; amount: number; timestamp: number }>(depositKey));
    setWithdrawHistory(readHistory<{ id: string; amount: number; timestamp: number }>(withdrawKey));
  }, [address]);

  useEffect(() => {
    if (!address) return;
    const key = buildHistoryKey("trade", address);
    persistHistory(key, tradeHistory);
  }, [address, tradeHistory]);

  useEffect(() => {
    if (!address) return;
    const key = buildHistoryKey("deposit", address);
    persistHistory(key, depositHistory);
  }, [address, depositHistory]);

  useEffect(() => {
    if (!address) return;
    const key = buildHistoryKey("withdraw", address);
    persistHistory(key, withdrawHistory);
  }, [address, withdrawHistory]);

  const { data: dexBalance, refetch: refetchDexBalance } = useReadContract({
    address: CONTRACTS.DEX,
    abi: PERPETUAL_DEX_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

  const { data: positionBtc, refetch: refetchBtc } = useReadContract({
    address: CONTRACTS.DEX,
    abi: PERPETUAL_DEX_ABI,
    functionName: "getCurrentPosition",
    args: address ? [address, symbolToBytes32("BTCUSD")] : undefined,
  });
  const { data: positionEth, refetch: refetchEth } = useReadContract({
    address: CONTRACTS.DEX,
    abi: PERPETUAL_DEX_ABI,
    functionName: "getCurrentPosition",
    args: address ? [address, symbolToBytes32("ETHUSD")] : undefined,
  });
  const { data: positionDot, refetch: refetchDot } = useReadContract({
    address: CONTRACTS.DEX,
    abi: PERPETUAL_DEX_ABI,
    functionName: "getCurrentPosition",
    args: address ? [address, symbolToBytes32("DOTUSD")] : undefined,
  });
  const refetchPositions = useCallback(() => {
    refetchBtc();
    refetchEth();
    refetchDot();
  }, [refetchBtc, refetchEth, refetchDot]);
  const positionsBySymbol = useMemo(
    () => ({
      BTCUSD: positionBtc as PositionData | undefined,
      ETHUSD: positionEth as PositionData | undefined,
      DOTUSD: positionDot as PositionData | undefined,
    }),
    [positionBtc, positionEth, positionDot],
  );
  const position = positionsBySymbol[chartSymbol];

  const { data: tokenBalance } = useReadContract({
    address: CONTRACTS.TOKEN,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

  const { writeContractAsync: approveTokenAsync } = useWriteContract();
  const { writeContract: deposit, data: depositHash } = useWriteContract();
  const { writeContract: withdraw, data: withdrawHash } = useWriteContract();
  const { writeContractAsync: openPosAsync, data: openHash } = useWriteContract();
  const { writeContractAsync: increasePosAsync, data: increaseHash } = useWriteContract();
  const { writeContractAsync: closePosAsync, data: closeHash } = useWriteContract();

  const { isLoading: isDepositPending } = useWaitForTransactionReceipt({ hash: depositHash });
  const { isLoading: isWithdrawPending } = useWaitForTransactionReceipt({ hash: withdrawHash });
  const { isLoading: isOpenPending } = useWaitForTransactionReceipt({ hash: openHash });
  const { isLoading: isIncreasePending } = useWaitForTransactionReceipt({ hash: increaseHash });
  const { isLoading: isClosePending } = useWaitForTransactionReceipt({ hash: closeHash });
  const [isSubmittingPosition, setIsSubmittingPosition] = useState(false);

  const publicClient = usePublicClient();

  const captureTxFee = useCallback(
    async (txPromise: Promise<`0x${string}` | undefined>): Promise<number> => {
      if (!publicClient) throw new Error("No public client");
      const hash = await txPromise;
      if (!hash) throw new Error("Transaction was not sent");
      const receipt = await publicClient.waitForTransactionReceipt({ hash: hash as `0x${string}` });
      const gasUsed = receipt.gasUsed ?? 0n;
      const gasPrice = receipt.effectiveGasPrice ?? 0n;
      if (gasUsed === 0n || gasPrice === 0n) return 0;
      return Number(formatUnits(gasUsed * gasPrice, 18));
    },
    [publicClient],
  );

  const handleDeposit = async () => {
    if (!depositAmount || !address || !publicClient) return;
    const amount = parseUnits(depositAmount, 18);
    const hash = await approveTokenAsync({ address: CONTRACTS.TOKEN, abi: ERC20_ABI, functionName: "approve", args: [CONTRACTS.DEX, amount] });
    if (hash) await publicClient.waitForTransactionReceipt({ hash });
    await deposit({ address: CONTRACTS.DEX, abi: PERPETUAL_DEX_ABI, functionName: "deposit", args: [amount] });
    setDepositAmount("");
    const depositValue = Number(depositAmount);
    if (!Number.isNaN(depositValue)) {
      setDepositHistory((prev) => [
        { id: crypto.randomUUID?.() ?? `deposit-${Date.now()}`, amount: depositValue, timestamp: Date.now() },
        ...prev,
      ]);
    }
  };

  const handleWithdraw = async () => {
    if (!withdrawAmount) return;
    await withdraw({ address: CONTRACTS.DEX, abi: PERPETUAL_DEX_ABI, functionName: "withdraw", args: [parseUnits(withdrawAmount, 18)] });
    setWithdrawAmount("");
    const withdrawValue = Number(withdrawAmount);
    if (!Number.isNaN(withdrawValue)) {
      setWithdrawHistory((prev) => [
        { id: crypto.randomUUID?.() ?? `withdraw-${Date.now()}`, amount: withdrawValue, timestamp: Date.now() },
        ...prev,
      ]);
    }
  };

  const handleOpenPosition = async () => {
    if (!positionAmount) return;
    const amountStr = positionAmount;
    const priceSnapshot = displayPrice?.price ?? chartPrice?.price ?? null;
    const entryPriceValue = priceSnapshot ?? 0;
    const parsedAmount = Number(amountStr);
    const volume = parsedAmount * leverage;
    setIsSubmittingPosition(true);
    try {
      const txFee = await captureTxFee(
        openPosAsync({
          address: CONTRACTS.DEX,
          abi: PERPETUAL_DEX_ABI,
          functionName: "openPosition",
          args: [symbolToBytes32(chartSymbol), parseUnits(amountStr, 18), POSITION_TYPE[positionType], leverage],
          gas: 500000n,
        }),
      );
      if (priceSnapshot) setEntryPrice(priceSnapshot);
      const newEntry: HistoryEntry = {
        id: crypto.randomUUID?.() ?? `${Date.now()}-open`,
        symbol: chartSymbol,
        action: "open",
        type: positionType,
        amount: amountStr,
        leverage,
        entryPrice: entryPriceValue,
        status: "open",
        timestamp: Date.now(),
        fee: txFee,
        takeProfit: previewTakeProfitPrice ?? null,
        stopLoss: previewStopLossPrice ?? null,
        volume,
      };
      setTradeHistory((prev) => [newEntry, ...prev]);
      refetchPositions();
      refetchDexBalance();
    } catch {
      setPositionAmount(amountStr);
    } finally {
      setIsSubmittingPosition(false);
    }
  };

  const handleIncreasePosition = async () => {
    if (!positionAmount) return;
    const amountStr = positionAmount;
    const priceSnapshot = displayPrice?.price ?? chartPrice?.price ?? null;
    const entryPriceValue = priceSnapshot ?? 0;
    const parsedAmount = Number(amountStr);
    const volume = parsedAmount * leverage;
    setIsSubmittingPosition(true);
    try {
      const txFee = await captureTxFee(
        increasePosAsync({
          address: CONTRACTS.DEX,
          abi: PERPETUAL_DEX_ABI,
          functionName: "increasePosition",
          args: [symbolToBytes32(chartSymbol), parseUnits(amountStr, 18)],
          gas: 400000n,
        }),
      );
      setPositionAmount("");
      if (priceSnapshot) setEntryPrice(priceSnapshot);
      const newEntry: HistoryEntry = {
        id: crypto.randomUUID?.() ?? `${Date.now()}-increase`,
        symbol: chartSymbol,
        action: "increase",
        type: positionType,
        amount: amountStr,
        leverage,
        entryPrice: entryPriceValue,
        status: "open",
        timestamp: Date.now(),
        fee: txFee,
        takeProfit: previewTakeProfitPrice ?? null,
        stopLoss: previewStopLossPrice ?? null,
        volume,
      };
      setTradeHistory((prev) => [newEntry, ...prev]);
      refetchPositions();
      refetchDexBalance();
    } catch {
      setPositionAmount(amountStr);
    } finally {
      setIsSubmittingPosition(false);
    }
  };

  const handleClosePosition = async (market: PolkadotSymbol, amountOverride?: string) => {
    const amountValue = amountOverride ?? closeAmount;
    if (!amountValue) return;
    const closePrice = displayPrice?.price ?? chartPrice?.price ?? 0;
    const amountNumber = Number(amountValue);
    const entryPriceValue = entryPrice ?? closePrice;
    const closingLeverage = pos?.leverage ?? leverage;
    const volume = amountNumber * closingLeverage;
    try {
      const txFee = await captureTxFee(
        closePosAsync({
          address: CONTRACTS.DEX,
          abi: PERPETUAL_DEX_ABI,
          functionName: "closePosition",
          args: [symbolToBytes32(market), parseUnits(amountValue, 18)],
          gas: 400000n,
        }),
      );
      setCloseAmount("");
      setTradeHistory((prev): HistoryEntry[] => {
      let replaced = false;
      const updatedHistory: HistoryEntry[] = prev.map((entry) => {
        if (!replaced && entry.status === "open" && (entry.symbol === market || !entry.symbol)) {
          replaced = true;
          return {
            ...entry,
            action: "close",
            amount: amountValue,
            leverage: entry.leverage || closingLeverage,
            entryPrice: entryPriceValue,
            closePrice,
            status: "closed",
            timestamp: Date.now(),
            fee: txFee,
            takeProfit: previewTakeProfitPrice ?? null,
            stopLoss: previewStopLossPrice ?? null,
            volume,
          };
        }
        return entry;
      });
      if (!replaced) {
        const fallbackEntry: HistoryEntry = {
          id: crypto.randomUUID?.() ?? `${Date.now()}-close`,
          symbol: market,
          action: "close",
          type: (posTypeStr === "-" ? "N/A" : (posTypeStr as "Long" | "Short")),
          amount: amountValue,
          leverage: closingLeverage,
          entryPrice: entryPriceValue,
          closePrice,
          status: "closed",
          timestamp: Date.now(),
          fee: txFee,
          takeProfit: previewTakeProfitPrice ?? null,
          stopLoss: previewStopLossPrice ?? null,
          volume,
        };
        return [fallbackEntry, ...prev];
      }
      return updatedHistory;
    });
      refetchPositions();
      refetchDexBalance();
    } catch {
      if (!amountOverride) setCloseAmount(amountValue);
    } finally {
      setIsSubmittingPosition(false);
    }
  };

  const handleTimeScaleRightOffsetChange = useCallback((offset: number) => {
    setChartRightOffset(offset);
  }, []);

  const pos = position as PositionData | undefined;
  const hasPosition = Boolean(pos && pos.amount > 0n);
  const posTypeStr = pos ? (pos.position === 0 ? "Long" : "Short") : "-";
  const positionMargin = pos ? Number(formatUnits(pos.amount, 18)) : 0;
  const positionSide = pos ? (pos.position === 0 ? "Long" : "Short") : "Long";
  const notConnected = !address;
  const { getPrice } = usePolkadotPrices();
  const btcPrice = getPrice("BTCUSD");
  const ethPrice = getPrice("ETHUSD");
  const dotPrice = getPrice("DOTUSD");

  const { price: chartPrice } = useChartPrice(chartSymbol);
  const tradingviewSymbol = TRADINGVIEW_SYMBOL_MAP[chartSymbol] ?? chartSymbol;
  const chartLabel = chartPrice ? `${chartSymbol} · Pyth Benchmarks` : undefined;
  const displayPrice = chartPrice ?? getPrice(chartSymbol);
  const [entryPrice, setEntryPrice] = useState<number | null>(null);
  const [targetPercent, setTargetPercent] = useState(5);
  const [stopLossPercent, setStopLossPercent] = useState(2);
  const [previewLiquidationPrice, setPreviewLiquidationPrice] = useState<number | null>(null);
  const [previewTakeProfitPrice, setPreviewTakeProfitPrice] = useState<number | null>(null);
  const [previewStopLossPrice, setPreviewStopLossPrice] = useState<number | null>(null);
  const [infoModal, setInfoModal] = useState<{ title: string; body: string } | null>(null);
  const [closeConfirmEntry, setCloseConfirmEntry] = useState<HistoryEntry | null>(null);
  const handlePositionAmountChange = useCallback(
    (value: string) => {
      if (value.trim()) {
        setCloseAmount("");
      }
      setPositionAmount(value);
    },
    [setCloseAmount],
  );
  const handleCloseAmountChange = useCallback(
    (value: string) => {
      if (value.trim()) {
        setPositionAmount("");
      }
      setCloseAmount(value);
    },
    [setPositionAmount],
  );
  const orderSize = useMemo(() => {
    const trimmedClose = closeAmount.trim();
    if (trimmedClose) {
      const normalizedClose = Number(trimmedClose);
      if (Number.isNaN(normalizedClose)) {
        return null;
      }
      const activeLeverage = pos?.leverage ?? leverage;
      return normalizedClose * activeLeverage;
    }

    const trimmedAmount = positionAmount.trim();
    if (!trimmedAmount) {
      return null;
    }
    const normalizedAmount = Number(trimmedAmount);
    if (Number.isNaN(normalizedAmount)) {
      return null;
    }
    return normalizedAmount * leverage;
  }, [closeAmount, positionAmount, leverage, pos?.leverage]);
  const prevHasPosition = useRef<boolean>(hasPosition);
  useEffect(() => {
    if (prevHasPosition.current && !hasPosition) {
      setLeverage(2);
    }
    prevHasPosition.current = hasPosition;
  }, [hasPosition]);

  useEffect(() => {
    setEntryPrice(displayPrice?.price ?? null);
  }, [chartSymbol, displayPrice?.price]);

  useEffect(() => {
    if (!address) {
      setInfoModal(null);
      return;
    }

    if (dexBalance === undefined) {
      return;
    }

    if (dexBalance === 0n) {
      setInfoModal({
        title: "Deposit zUSDC First",
        body: `Please deposit zUSDC (contract ${CONTRACTS.TOKEN}) into the DEX before trading. zUSDC is required for margin and gas.`,
      });
      return;
    }

    const depositedAmount = formatUnits(dexBalance, 18);
    let positionSummary = "You currently have no open positions.";
    const activePositions: string[] = [];
    for (const sym of POLKADOT_SYMBOLS) {
      const p = positionsBySymbol[sym];
      if (p && p.amount > 0n) {
        const side = p.position === 0 ? "Long" : "Short";
        activePositions.push(`${formatUnits(p.amount, 18)} ${sym} ${side} @ ${p.leverage}x`);
      }
    }
    if (activePositions.length > 0) {
      positionSummary = `Open: ${activePositions.join("; ")}.`;
    }

    setInfoModal({
      title: "Account Snapshot",
      body: `You have deposited ${depositedAmount} zUSDC. ${positionSummary}`,
    });
  }, [address, dexBalance, positionsBySymbol]);

  const effectiveEntryPrice = entryPrice ?? displayPrice?.price ?? null;
  const effectiveSide =
    hasPosition && pos
      ? pos.position === 0
        ? "Long"
        : "Short"
      : positionType;
  const effectiveLeverage =
    hasPosition && pos ? pos.leverage : Math.max(1, leverage);

  const calculatePreviewValues = useCallback(
    (
      price: number | null,
      leverageValue: number,
      side: "Long" | "Short",
      tpPercentage: number,
      slPercentage: number
    ) => {
      if (price == null || leverageValue <= 0) {
        return {
          liquidationPrice: null,
          takeProfitPrice: null,
          stopLossPrice: null,
        };
      }
      const safeLeverage = Math.max(1, leverageValue);
      const liquidationPrice =
        side === "Long"
          ? price * (1 - 0.9 / safeLeverage)
          : price * (1 + 0.9 / safeLeverage);
      const tpDelta = tpPercentage / 100 / safeLeverage;
      const slDelta = slPercentage / 100 / safeLeverage;
      const takeProfitPrice =
        side === "Long" ? price * (1 + tpDelta) : price * Math.max(0, 1 - tpDelta);
      const stopLossPrice =
        side === "Long" ? price * Math.max(0, 1 - slDelta) : price * (1 + slDelta);
      return {
        liquidationPrice,
        takeProfitPrice,
        stopLossPrice,
      };
    },
    []
  );

  useEffect(() => {
    const basePrice = effectiveEntryPrice;
    const preview = calculatePreviewValues(
      basePrice,
      effectiveLeverage,
      effectiveSide,
      targetPercent,
      stopLossPercent
    );
    setPreviewLiquidationPrice(preview.liquidationPrice);
    setPreviewTakeProfitPrice(preview.takeProfitPrice);
    setPreviewStopLossPrice(preview.stopLossPrice);
  }, [
    calculatePreviewValues,
    effectiveEntryPrice,
    effectiveLeverage,
    effectiveSide,
    targetPercent,
    stopLossPercent,
  ]);

  const chartOrderLines = useMemo(() => {
    if (!hasPosition) return undefined;
    const lines: Array<{
      name: string;
      price: number;
      color: string;
      lineWidth?: number;
      lineStyle?: number;
      labelAlign?: "top" | "bottom";
    }> = [];
    const addLine = (
      name: string,
      price: number | null | undefined,
      color: string,
      lineStyle: number,
      labelAlign: "top" | "bottom" = "top",
      lineWidth?: number,
    ) => {
      if (price == null || Number.isNaN(price) || !Number.isFinite(price)) return;
      lines.push({ name, price, color, lineStyle, labelAlign, lineWidth });
    };
    addLine("Entry Price", effectiveEntryPrice, "#ffffff", 0, "top", 0.5);
    addLine("Liquidation", previewLiquidationPrice, "#ef4444", 1, "bottom", 1);
    addLine("Take Profit", previewTakeProfitPrice, "#22c55e", 1, "top", 1);
    addLine("Stop Loss", previewStopLossPrice, "#eab308", 1, "bottom", 1);
    return lines.length > 0 ? lines : undefined;
  }, [
    hasPosition,
    effectiveEntryPrice,
    previewLiquidationPrice,
    previewTakeProfitPrice,
    previewStopLossPrice,
  ]);

  const historyTabOptions = [
    { key: "timeline", label: "Order Timeline" },
    { key: "open", label: "Open Positions" },
    { key: "closed", label: "Closed Positions" },
  ] as const;

  const openHistory = tradeHistory.filter((entry) => entry.status === "open");
  const closedHistory = tradeHistory.filter((entry) => entry.status === "closed");
  const historyEntries =
    historyTab === "timeline" ? tradeHistory : historyTab === "open" ? openHistory : closedHistory;
  const depositWithdrawHistory = useMemo(() => {
    type CombinedRecord = { id: string; amount: number; timestamp: number; type: "Deposit" | "Withdraw" };
    const deposits: CombinedRecord[] = depositHistory.map((record) => ({ ...record, type: "Deposit" }));
    const withdraws: CombinedRecord[] = withdrawHistory.map((record) => ({ ...record, type: "Withdraw" }));
    return [...deposits, ...withdraws]
      .sort((a, b) => b.timestamp - a.timestamp);
  }, [depositHistory, withdrawHistory]);

  const openPositionEntries = useMemo(() => tradeHistory.filter((entry) => entry.status === "open"), [tradeHistory]);
  const openPositionMargin = useMemo(() => {
    let total = 0;
    for (const sym of POLKADOT_SYMBOLS) {
      const p = positionsBySymbol[sym];
      if (p && p.amount > 0n) total += Number(formatUnits(p.amount, 18));
    }
    return total;
  }, [positionsBySymbol]);
  const openPositionSide = useMemo(() => {
    const sides = new Set<string>();
    for (const sym of POLKADOT_SYMBOLS) {
      const p = positionsBySymbol[sym];
      if (p && p.amount > 0n) sides.add(p.position === 0 ? "Long" : "Short");
    }
    if (sides.size > 1) return "Multiple";
    if (sides.size === 1) return [...sides][0]!;
    return openPositionEntries.length > 0 ? openPositionEntries[openPositionEntries.length - 1]?.type ?? posTypeStr : posTypeStr;
  }, [positionsBySymbol, openPositionEntries, posTypeStr]);

  const renderHistoryEntry = (entry: HistoryEntry) => {
    const entrySymbol = entry.symbol ?? chartSymbol;
    const entryPriceData = getPrice(entrySymbol);
    const currentPrice = entryPriceData?.price;
    const pnlValue = calculatePnL(entry, currentPrice);
    const sizeValue = entry.volume ?? Number(entry.amount) * entry.leverage;
    const closeTimestamp = entry.status === "closed" ? formatTimestamp(entry.timestamp) : "Open";
    const pnlClass =
      pnlValue == null ? "text-slate-400" : pnlValue >= 0 ? "text-emerald-400" : "text-rose-400";
    const priceTextColor =
      currentPrice == null || entry.entryPrice == null
        ? "text-white"
        : currentPrice > entry.entryPrice
        ? "text-emerald-400"
        : "text-rose-400";
    const liqPriceStr = calculateLiquidationPrice(entry.type === "N/A" ? "Long" : entry.type, entry.entryPrice, entry.leverage);
    const liqPriceValue = Number(liqPriceStr);
    const liqDistancePct =
      currentPrice == null || liqPriceValue === 0 ? Number.POSITIVE_INFINITY : Math.abs(currentPrice - liqPriceValue) / liqPriceValue;
    const isLiqNear = liqDistancePct <= 0.05;
    const liqDangerClass = isLiqNear
      ? `animate-pulse ${
          currentPrice != null &&
          entry.type !== "N/A" &&
          ((entry.type === "Long" && currentPrice <= liqPriceValue) || (entry.type === "Short" && currentPrice >= liqPriceValue))
            ? "text-rose-400"
            : "text-orange-400"
        }`
      : "text-white";

    return (
      <div
        key={entry.id}
        className="w-max min-w-full rounded-2xl border border-[#363a59] bg-[#121421]/60 p-4 shadow-inner shadow-black/20"
      >
        <div className="flex flex-nowrap gap-3 text-[11px] sm:text-[12px]">
          {[
            ["Market", entrySymbol],
            ["Time", formatTimestamp(entry.timestamp)],
            ["Position", entry.type],
            ["Entry", formatForSymbol(entry.entryPrice, entrySymbol)],
            ["Price", currentPrice != null ? formatForSymbol(currentPrice, entrySymbol) : "—"],
            ["Liq. Price", isNaN(Number(liqPriceStr)) ? "—" : formatCurrency(Number(liqPriceStr))],
            ["Margin", formatZUSDCNumber(Number(entry.amount))],
            ["Leverage", `${entry.leverage}x`],
            ["Size", formatCurrency(sizeValue)],
            ["Exc Fee", formatCurrency(entry.fee)],
            ["PnL", pnlValue == null ? "—" : formatCurrency(pnlValue)],
            ["Take Profit", formatForSymbol(entry.takeProfit, entrySymbol)],
            ["Stop Loss", formatForSymbol(entry.stopLoss, entrySymbol)],
            [
              "Status",
              entry.status === "open" ? "Open" : `Closed · ${closeTimestamp}`,
            ],
          ].map(([label, value]) => {
            const statusClass =
              label === "Status" && value === "Open" ? "text-lime-300 animate-pulse" : "";
            const valueClass =
              label === "PnL"
                ? pnlClass
                : label === "Liq. Price"
                ? liqDangerClass
                : label === "Price"
                ? priceTextColor
                : statusClass
                ? statusClass
                : "text-white";
            return (
              <div key={`${entry.id}-${label}`} className="flex min-w-[90px] flex-none flex-col gap-1">
                <span className="uppercase text-[9px] text-slate-500 tracking-[0.2em]">{label}</span>
                <span className={`text-[11px] ${valueClass}`}>{value}</span>
              </div>
            );
          })}
          {entry.status === "open" && (
            <div className="flex min-w-[40px] flex-none flex-col justify-end">
              <button
                type="button"
                onClick={() => setCloseConfirmEntry(entry)}
                className="flex h-8 w-8 items-center justify-center rounded-lg bg-rose-500/20 text-rose-400 transition hover:bg-rose-500 hover:text-white"
                title="Close position"
                aria-label="Close position"
              >
                <span className="text-lg font-bold leading-none">×</span>
              </button>
            </div>
          )}
        </div>
      </div>
    );
  };

  return (
    <>
    <div className="flex flex-col gap-6 -mx-2">
      {infoModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4 py-8">
          <div className="w-full max-w-md rounded-2xl bg-[#0d0f18] border border-[#3d51ff]/60 p-6 text-white shadow-xl">
            <div className="flex items-start justify-between gap-3">
              <div>
                <h3 className="text-xl font-semibold">{infoModal.title}</h3>
                <p className="text-sm text-slate-300 mt-2">{infoModal.body}</p>
              </div>
              <button
                className="text-sm text-slate-400 hover:text-white"
                onClick={() => setInfoModal(null)}
                aria-label="Close account notice"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {closeConfirmEntry && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4 py-8">
          <div className="w-full max-w-md rounded-2xl bg-[#0d0f18] border border-rose-500/60 p-6 text-white shadow-xl">
            <h3 className="text-xl font-semibold text-rose-400">Close Position</h3>
            <p className="mt-2 text-sm text-slate-400">
              Bạn sắp đóng vị thế với các thông tin sau:
            </p>
            <div className="mt-4 space-y-2 rounded-xl border border-[#363a59] bg-[#121421]/60 p-4 text-sm">
              <div className="flex justify-between">
                <span className="text-slate-400">Market</span>
                <span>{closeConfirmEntry.symbol ?? chartSymbol}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Position</span>
                <span className={closeConfirmEntry.type === "Long" ? "text-emerald-400" : "text-rose-400"}>
                  {closeConfirmEntry.type}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Amount (zUSDC)</span>
                <span>{formatZUSDCNumber(Number(closeConfirmEntry.amount))}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Size</span>
                <span>{formatCurrency((closeConfirmEntry.volume ?? Number(closeConfirmEntry.amount) * closeConfirmEntry.leverage))}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Entry Price</span>
                <span>{formatForSymbol(closeConfirmEntry.entryPrice, closeConfirmEntry.symbol ?? chartSymbol)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Current Price</span>
                <span>{formatForSymbol(getPrice(closeConfirmEntry.symbol ?? chartSymbol)?.price ?? null, closeConfirmEntry.symbol ?? chartSymbol)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Est. PnL</span>
                <span className={(() => {
                  const pnl = calculatePnL(closeConfirmEntry, getPrice(closeConfirmEntry.symbol ?? chartSymbol)?.price);
                  if (pnl == null) return "text-slate-400";
                  return pnl >= 0 ? "text-emerald-400" : "text-rose-400";
                })()}>
                  {formatCurrency(calculatePnL(closeConfirmEntry, getPrice(closeConfirmEntry.symbol ?? chartSymbol)?.price))}
                </span>
              </div>
            </div>
            <div className="mt-6 flex gap-3">
              <button
                type="button"
                onClick={() => setCloseConfirmEntry(null)}
                className="flex-1 rounded-xl border border-[#363a59] px-4 py-3 font-semibold text-slate-300 transition hover:bg-[#1e2033]"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={async () => {
                  if (!closeConfirmEntry) return;
                  await handleClosePosition(closeConfirmEntry.symbol ?? chartSymbol, closeConfirmEntry.amount);
                  setCloseConfirmEntry(null);
                }}
                disabled={isClosePending}
                className="flex-1 rounded-xl bg-rose-500 px-4 py-3 font-semibold text-white transition hover:bg-rose-600 disabled:opacity-50"
              >
                {isClosePending ? "Closing..." : "Confirm Close"}
              </button>
            </div>
          </div>
        </div>
      )}
      {/* Market Stats Bar */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">

        {/* BTC/USD */}
        <div
          className="relative overflow-hidden rounded-2xl p-4 border transition-all duration-200 hover:scale-[1.02] hover:shadow-lg cursor-default"
          style={{
            background: "linear-gradient(135deg, #1a1400 0%, #16182e 60%, #1e1a08 100%)",
            borderColor: "rgba(251,146,60,0.25)",
            boxShadow: "0 0 0 0 rgba(251,146,60,0)",
          }}
          onMouseEnter={(e) => (e.currentTarget.style.boxShadow = "0 0 24px rgba(251,146,60,0.15)")}
          onMouseLeave={(e) => (e.currentTarget.style.boxShadow = "0 0 0 0 rgba(251,146,60,0)")}
        >
          {/* glow blob */}
          <div className="pointer-events-none absolute -top-4 -right-4 h-16 w-16 rounded-full opacity-20" style={{ background: "radial-gradient(circle, #f97316, transparent)" }} />
          {/* bottom accent */}
          <div className="absolute bottom-0 left-0 right-0 h-0.5 rounded-b-2xl" style={{ background: "linear-gradient(to right, transparent, #f97316, transparent)" }} />

          <div className="flex items-center justify-between mb-2">
            <span className="text-[10px] font-semibold uppercase tracking-[0.2em] text-orange-400/80">BTC / USD</span>
            <span className="flex items-center justify-center h-6 w-6 rounded-lg" style={{ background: "rgba(251,146,60,0.15)", border: "1px solid rgba(251,146,60,0.3)" }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none">
                <path d="M11.5 2C6.25 2 2 6.25 2 11.5S6.25 21 11.5 21 21 16.75 21 11.5 16.75 2 11.5 2z" stroke="#f97316" strokeWidth="1.5"/>
                <path d="M8 8h5c1.1 0 2 .9 2 2s-.9 2-2 2H8v-4zm0 4h5.5c1.38 0 2.5 1.12 2.5 2.5S14.88 17 13.5 17H8v-5z" fill="#f97316"/>
                <line x1="10" y1="6" x2="10" y2="8" stroke="#f97316" strokeWidth="1.5" strokeLinecap="round"/>
                <line x1="13" y1="6" x2="13" y2="8" stroke="#f97316" strokeWidth="1.5" strokeLinecap="round"/>
                <line x1="10" y1="17" x2="10" y2="19" stroke="#f97316" strokeWidth="1.5" strokeLinecap="round"/>
                <line x1="13" y1="17" x2="13" y2="19" stroke="#f97316" strokeWidth="1.5" strokeLinecap="round"/>
              </svg>
            </span>
          </div>
          <div className="text-xl font-bold text-white tracking-tight">
            {btcPrice ? `$${btcPrice.formatted}` : "—"}
          </div>
          <div className="mt-1.5 flex items-center gap-1.5">
            <span className="h-1.5 w-1.5 rounded-full bg-orange-400 animate-pulse" />
            <span className="text-[10px] text-orange-400/60">
              {btcPrice ? (btcPrice.source === "pyth" ? "Pyth Oracle" : "DIA Oracle") : "Polkadot"}
            </span>
          </div>
        </div>

        {/* ETH/USD */}
        <div
          className="relative overflow-hidden rounded-2xl p-4 border transition-all duration-200 hover:scale-[1.02] cursor-default"
          style={{
            background: "linear-gradient(135deg, #0a0a1a 0%, #16182e 60%, #0e0a24 100%)",
            borderColor: "rgba(139,92,246,0.25)",
          }}
          onMouseEnter={(e) => (e.currentTarget.style.boxShadow = "0 0 24px rgba(139,92,246,0.15)")}
          onMouseLeave={(e) => (e.currentTarget.style.boxShadow = "none")}
        >
          <div className="pointer-events-none absolute -top-4 -right-4 h-16 w-16 rounded-full opacity-20" style={{ background: "radial-gradient(circle, #8b5cf6, transparent)" }} />
          <div className="absolute bottom-0 left-0 right-0 h-0.5 rounded-b-2xl" style={{ background: "linear-gradient(to right, transparent, #8b5cf6, transparent)" }} />

          <div className="flex items-center justify-between mb-2">
            <span className="text-[10px] font-semibold uppercase tracking-[0.2em] text-violet-400/80">ETH / USD</span>
            <span className="flex items-center justify-center h-6 w-6 rounded-lg" style={{ background: "rgba(139,92,246,0.15)", border: "1px solid rgba(139,92,246,0.3)" }}>
              <svg width="10" height="13" viewBox="0 0 10 16" fill="none">
                <polygon points="5,0 10,8 5,11 0,8" fill="rgba(139,92,246,0.5)" stroke="#8b5cf6" strokeWidth="0.8"/>
                <polygon points="5,12 10,9 5,16 0,9" fill="#8b5cf6"/>
              </svg>
            </span>
          </div>
          <div className="text-xl font-bold text-white tracking-tight">
            {ethPrice ? `$${ethPrice.formatted}` : "—"}
          </div>
          <div className="mt-1.5 flex items-center gap-1.5">
            <span className="h-1.5 w-1.5 rounded-full bg-violet-400 animate-pulse" />
            <span className="text-[10px] text-violet-400/60">
              {ethPrice ? (ethPrice.source === "pyth" ? "Pyth Oracle" : "DIA Oracle") : "Polkadot"}
            </span>
          </div>
        </div>

        {/* DOT/USD */}
        <div
          className="relative overflow-hidden rounded-2xl p-4 border transition-all duration-200 hover:scale-[1.02] cursor-default"
          style={{
            background: "linear-gradient(135deg, #160818 0%, #16182e 60%, #1a0a1c 100%)",
            borderColor: "rgba(232,121,249,0.25)",
          }}
          onMouseEnter={(e) => (e.currentTarget.style.boxShadow = "0 0 24px rgba(232,121,249,0.15)")}
          onMouseLeave={(e) => (e.currentTarget.style.boxShadow = "none")}
        >
          <div className="pointer-events-none absolute -top-4 -right-4 h-16 w-16 rounded-full opacity-20" style={{ background: "radial-gradient(circle, #e879f9, transparent)" }} />
          <div className="absolute bottom-0 left-0 right-0 h-0.5 rounded-b-2xl" style={{ background: "linear-gradient(to right, transparent, #e879f9, transparent)" }} />

          <div className="flex items-center justify-between mb-2">
            <span className="text-[10px] font-semibold uppercase tracking-[0.2em] text-fuchsia-400/80">DOT / USD</span>
            <span className="flex items-center justify-center h-6 w-6 rounded-lg" style={{ background: "rgba(232,121,249,0.15)", border: "1px solid rgba(232,121,249,0.3)" }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="4" fill="#e879f9"/>
                <circle cx="12" cy="4"  r="2.2" fill="rgba(232,121,249,0.6)"/>
                <circle cx="12" cy="20" r="2.2" fill="rgba(232,121,249,0.6)"/>
                <circle cx="4"  cy="12" r="2.2" fill="rgba(232,121,249,0.6)"/>
                <circle cx="20" cy="12" r="2.2" fill="rgba(232,121,249,0.6)"/>
              </svg>
            </span>
          </div>
          <div className="text-xl font-bold text-white tracking-tight">
            {dotPrice ? `$${dotPrice.formatted}` : "—"}
          </div>
          <div className="mt-1.5 flex items-center gap-1.5">
            <span className="h-1.5 w-1.5 rounded-full bg-fuchsia-400 animate-pulse" />
            <span className="text-[10px] text-fuchsia-400/60">
              {dotPrice ? (dotPrice.source === "pyth" ? "Pyth Oracle" : "DIA Oracle") : "Polkadot"}
            </span>
          </div>
        </div>

        {/* 24h Volume */}
        <div
          className="relative overflow-hidden rounded-2xl p-4 border transition-all duration-200 hover:scale-[1.02] cursor-default"
          style={{
            background: "linear-gradient(135deg, #021414 0%, #16182e 60%, #04161a 100%)",
            borderColor: "rgba(20,184,166,0.25)",
          }}
          onMouseEnter={(e) => (e.currentTarget.style.boxShadow = "0 0 24px rgba(20,184,166,0.15)")}
          onMouseLeave={(e) => (e.currentTarget.style.boxShadow = "none")}
        >
          <div className="pointer-events-none absolute -top-4 -right-4 h-16 w-16 rounded-full opacity-20" style={{ background: "radial-gradient(circle, #14b8a6, transparent)" }} />
          <div className="absolute bottom-0 left-0 right-0 h-0.5 rounded-b-2xl" style={{ background: "linear-gradient(to right, transparent, #14b8a6, transparent)" }} />

          <div className="flex items-center justify-between mb-2">
            <span className="text-[10px] font-semibold uppercase tracking-[0.2em] text-teal-400/80">24h Volume</span>
            <span className="flex items-center justify-center h-6 w-6 rounded-lg" style={{ background: "rgba(20,184,166,0.15)", border: "1px solid rgba(20,184,166,0.3)" }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#14b8a6" strokeWidth="2" strokeLinecap="round">
                <rect x="3"  y="12" width="4" height="9" rx="1" fill="rgba(20,184,166,0.4)" stroke="none"/>
                <rect x="10" y="7"  width="4" height="14" rx="1" fill="rgba(20,184,166,0.6)" stroke="none"/>
                <rect x="17" y="3"  width="4" height="18" rx="1" fill="#14b8a6" stroke="none"/>
              </svg>
            </span>
          </div>
          <div className="text-xl font-bold text-white tracking-tight">$1.2M</div>
          <div className="mt-1.5 flex items-center gap-1.5">
            <svg width="10" height="10" viewBox="0 0 12 12" fill="none">
              <path d="M2 9 L5 5 L8 7 L11 3" stroke="#14b8a6" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            <span className="text-[10px] text-teal-400/60">All markets · 24h</span>
          </div>
        </div>

        {/* Open Interest */}
        <div
          className="relative overflow-hidden rounded-2xl p-4 border transition-all duration-200 hover:scale-[1.02] cursor-default"
          style={{
            background: "linear-gradient(135deg, #0c0820 0%, #16182e 60%, #0e0a24 100%)",
            borderColor: "rgba(99,102,241,0.25)",
          }}
          onMouseEnter={(e) => (e.currentTarget.style.boxShadow = "0 0 24px rgba(99,102,241,0.15)")}
          onMouseLeave={(e) => (e.currentTarget.style.boxShadow = "none")}
        >
          <div className="pointer-events-none absolute -top-4 -right-4 h-16 w-16 rounded-full opacity-20" style={{ background: "radial-gradient(circle, #6366f1, transparent)" }} />
          <div className="absolute bottom-0 left-0 right-0 h-0.5 rounded-b-2xl" style={{ background: "linear-gradient(to right, transparent, #6366f1, transparent)" }} />

          <div className="flex items-center justify-between mb-2">
            <span className="text-[10px] font-semibold uppercase tracking-[0.2em] text-indigo-400/80">Open Interest</span>
            <span className="flex items-center justify-center h-6 w-6 rounded-lg" style={{ background: "rgba(99,102,241,0.15)", border: "1px solid rgba(99,102,241,0.3)" }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="9" stroke="#6366f1" strokeWidth="1.5" fill="none"/>
                <circle cx="12" cy="12" r="5.5" stroke="rgba(99,102,241,0.6)" strokeWidth="1.5" fill="none"/>
                <circle cx="12" cy="12" r="2"   fill="#6366f1"/>
              </svg>
            </span>
          </div>
          <div className="text-xl font-bold text-white tracking-tight">$845K</div>
          <div className="mt-1.5 flex items-center gap-1.5">
            <svg width="10" height="10" viewBox="0 0 12 12" fill="none">
              <path d="M6 2v8M2 6h8" stroke="#6366f1" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
            <span className="text-[10px] text-indigo-400/60">Total positions open</span>
          </div>
        </div>

        {/* Funding Rate */}
        <div
          className="relative overflow-hidden rounded-2xl p-4 border transition-all duration-200 hover:scale-[1.02] cursor-default"
          style={{
            background: "linear-gradient(135deg, #021408 0%, #16182e 60%, #041a0a 100%)",
            borderColor: "rgba(34,197,94,0.25)",
          }}
          onMouseEnter={(e) => (e.currentTarget.style.boxShadow = "0 0 24px rgba(34,197,94,0.15)")}
          onMouseLeave={(e) => (e.currentTarget.style.boxShadow = "none")}
        >
          <div className="pointer-events-none absolute -top-4 -right-4 h-16 w-16 rounded-full opacity-20" style={{ background: "radial-gradient(circle, #22c55e, transparent)" }} />
          <div className="absolute bottom-0 left-0 right-0 h-0.5 rounded-b-2xl" style={{ background: "linear-gradient(to right, transparent, #22c55e, transparent)" }} />

          <div className="flex items-center justify-between mb-2">
            <span className="text-[10px] font-semibold uppercase tracking-[0.2em] text-green-400/80">Funding Rate</span>
            <span className="flex items-center justify-center h-6 w-6 rounded-lg" style={{ background: "rgba(34,197,94,0.15)", border: "1px solid rgba(34,197,94,0.3)" }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2" strokeLinecap="round">
                <path d="M12 2v20M17 7l-5-5-5 5"/>
                <path d="M8 17l4 4 4-4" strokeOpacity="0.4"/>
              </svg>
            </span>
          </div>
          <div className="text-xl font-bold text-green-400 tracking-tight">+0.01%</div>
          <div className="mt-1.5 flex items-center gap-1.5">
            <span className="rounded-full px-1.5 py-0.5 text-[9px] font-semibold" style={{ background: "rgba(34,197,94,0.15)", color: "#4ade80" }}>
              LONGS PAY
            </span>
            <span className="text-[10px] text-green-400/50">per 8h</span>
          </div>
        </div>

      </div>

      {/* Chart + Trade Panel */}
      <div className="grid lg:grid-cols-[1fr_400px] gap-6">
        {/* Chart Section */}
        <div className="lg:order-1 min-w-0">
          <div className="bg-[#0d0f18] rounded-2xl border border-[#363a59]/50 overflow-hidden shadow-xl shadow-black/20">
            <div className="flex flex-col gap-3 border-b border-[#1d1f31] px-6 py-4 text-sm text-white lg:flex-row lg:items-center lg:justify-between">
              <div>
                <p className="text-xs uppercase text-slate-500">TradingView</p>
                <p className="text-base font-semibold text-white">
                  {chartSymbol}
                  {displayPrice ? ` · $${displayPrice.formatted}` : ""}
                </p>
                <p className="text-xs text-slate-500">
                  {displayPrice ? "Pyth Benchmarks" : "Đang tải..."}
                </p>
              </div>
              <select
                value={chartSymbol}
                onChange={(event) => setChartSymbol(event.target.value as PolkadotSymbol)}
                className="w-full max-w-[160px] rounded-xl border border-[#363a59] bg-[#121421] px-3 py-2 text-xs font-semibold uppercase tracking-wide text-white focus:border-blue-500 focus:outline-none"
              >
                {POLKADOT_SYMBOLS.map((symbol) => (
                  <option key={symbol} value={symbol}>
                    {symbol}
                  </option>
                ))}
              </select>
            </div>
            <ErrorBoundary
              fallback={
                <div className="min-h-[500px] flex flex-col items-center justify-center gap-3 p-8 text-slate-400">
                  <p>Không thể tải biểu đồ. Kiểm tra console để biết chi tiết.</p>
                  <p className="text-xs">Đảm bảo TradingView library đã load đúng.</p>
                </div>
              }
            >
              <TVChartContainer
                symbol={tradingviewSymbol}
                referencePrice={displayPrice?.price}
                referenceLabel={chartLabel}
                onIntervalChange={setChartResolution}
                onTimeScaleRightOffsetChange={handleTimeScaleRightOffsetChange}
              tpoLevels={chartOrderLines}
              />
            </ErrorBoundary>
            <IndicatorPanel
              symbol={chartSymbol}
              tradingViewSymbol={tradingviewSymbol}
              resolution={chartResolution}
              timeScaleRightOffset={chartRightOffset}
            />
          </div>
        </div>

        {/* Trade Panel */}
        <div className="lg:order-2 space-y-4 min-w-0">
          {notConnected ? (
            <div className="bg-gradient-to-br from-[#1e2033] to-[#16182e] rounded-2xl border border-[#363a59] p-12 text-center">
              <div className="text-6xl mb-4">🔐</div>
              <h3 className="text-xl font-semibold text-white mb-2">Connect Wallet</h3>
              <p className="text-slate-400 text-sm mb-6">Connect your wallet to start trading</p>
              <div className="[&_button]:!bg-gradient-to-r [&_button]:!from-blue-500 [&_button]:!to-blue-600 [&_button]:!px-8 [&_button]:!py-3 [&_button]:!rounded-xl [&_button]:!font-medium [&_button]:!border-0 flex justify-center">
                <ConnectButton />
              </div>
            </div>
          ) : (
            <>
              {/* User Stats */}
              <div className="grid grid-cols-3 gap-3">

                {/* Wallet */}
                <div
                  className="relative overflow-hidden rounded-2xl p-3.5 border transition-all duration-200"
                  style={{
                    background: "linear-gradient(135deg, #04101a 0%, #16182e 70%, #061424 100%)",
                    borderColor: "rgba(56,189,248,0.22)",
                  }}
                >
                  <div className="pointer-events-none absolute -top-3 -right-3 h-12 w-12 rounded-full opacity-20" style={{ background: "radial-gradient(circle, #38bdf8, transparent)" }} />
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 rounded-b-2xl" style={{ background: "linear-gradient(to right, transparent, #38bdf8, transparent)" }} />
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-[9px] font-semibold uppercase tracking-[0.18em] text-sky-400/70">Wallet</span>
                    <span className="flex items-center justify-center h-5 w-5 rounded-md" style={{ background: "rgba(56,189,248,0.12)", border: "1px solid rgba(56,189,248,0.28)" }}>
                      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#38bdf8" strokeWidth="2" strokeLinecap="round">
                        <path d="M20 7H4a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2z"/>
                        <path d="M16 3H8L4 7h16l-4-4z" strokeOpacity="0.5"/>
                        <circle cx="17" cy="13" r="1.5" fill="#38bdf8" stroke="none"/>
                      </svg>
                    </span>
                  </div>
                  <div className="text-white text-sm font-bold truncate leading-tight">{formatZUSDC(tokenBalance ?? 0n)}</div>
                  <div className="mt-1 text-[9px] text-sky-400/50">zUSDC balance</div>
                </div>

                {/* Collateral */}
                <div
                  className="relative overflow-hidden rounded-2xl p-3.5 border transition-all duration-200"
                  style={{
                    background: "linear-gradient(135deg, #140a00 0%, #16182e 70%, #1a0e00 100%)",
                    borderColor: "rgba(245,158,11,0.22)",
                  }}
                >
                  <div className="pointer-events-none absolute -top-3 -right-3 h-12 w-12 rounded-full opacity-20" style={{ background: "radial-gradient(circle, #f59e0b, transparent)" }} />
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 rounded-b-2xl" style={{ background: "linear-gradient(to right, transparent, #f59e0b, transparent)" }} />
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-[9px] font-semibold uppercase tracking-[0.18em]" style={{ color: "rgba(245,158,11,0.7)" }}>Collateral</span>
                    <span className="flex items-center justify-center h-5 w-5 rounded-md" style={{ background: "rgba(245,158,11,0.12)", border: "1px solid rgba(245,158,11,0.28)" }}>
                      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" strokeWidth="2" strokeLinecap="round">
                        <rect x="3" y="11" width="18" height="11" rx="2"/>
                        <path d="M7 11V7a5 5 0 0 1 10 0v4" strokeOpacity="0.5"/>
                        <circle cx="12" cy="16" r="1.5" fill="#f59e0b" stroke="none"/>
                      </svg>
                    </span>
                  </div>
                  <div className="text-white text-sm font-bold truncate leading-tight">{formatZUSDC(dexBalance ?? 0n)}</div>
                  <div className="mt-1 text-[9px]" style={{ color: "rgba(245,158,11,0.5)" }}>deposited margin</div>
                </div>

                {/* Position */}
                {(() => {
                  const isLong  = openPositionSide === "Long";
                  const isShort = openPositionSide === "Short";
                  const hasPos  = openPositionMargin > 0;
                  // Long = lime #a3e635 (distinct from Funding green #22c55e)
                  // Short = rose #f87171 (no red in top-6 cards)
                  const accent  = hasPos ? (isLong ? "#a3e635" : isShort ? "#f87171" : "#94a3b8") : "#64748b";
                  const accentBg   = hasPos ? (isLong ? "rgba(163,230,53,0.12)" : isShort ? "rgba(248,113,113,0.12)" : "rgba(148,163,184,0.12)") : "rgba(100,116,139,0.08)";
                  const accentBord = hasPos ? (isLong ? "rgba(163,230,53,0.28)" : isShort ? "rgba(248,113,113,0.28)" : "rgba(148,163,184,0.2)") : "rgba(100,116,139,0.15)";
                  const gradEnd   = hasPos ? (isLong ? "#0a1000" : isShort ? "#180404" : "#0d1020") : "#0d0f1c";
                  return (
                    <div
                      className="relative overflow-hidden rounded-2xl p-3.5 border transition-all duration-200"
                      style={{
                        background: `linear-gradient(135deg, ${gradEnd} 0%, #16182e 70%, ${gradEnd} 100%)`,
                        borderColor: accentBord,
                      }}
                    >
                      <div className="pointer-events-none absolute -top-3 -right-3 h-12 w-12 rounded-full opacity-20" style={{ background: `radial-gradient(circle, ${accent}, transparent)` }} />
                      <div className="absolute bottom-0 left-0 right-0 h-0.5 rounded-b-2xl" style={{ background: `linear-gradient(to right, transparent, ${accent}, transparent)` }} />
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-[9px] font-semibold uppercase tracking-[0.18em]" style={{ color: `${accent}99` }}>Position</span>
                        <span className="flex items-center justify-center h-5 w-5 rounded-md" style={{ background: accentBg, border: `1px solid ${accentBord}` }}>
                          <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke={accent} strokeWidth="2" strokeLinecap="round">
                            {isLong  && <><path d="M12 19V5"/><path d="M5 12l7-7 7 7" strokeOpacity="0.6"/></>}
                            {isShort && <><path d="M12 5v14"/><path d="M19 12l-7 7-7-7" strokeOpacity="0.6"/></>}
                            {!hasPos && <><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2" strokeOpacity="0.4"/></>}
                          </svg>
                        </span>
                      </div>
                      <div className="text-sm font-bold leading-tight truncate" style={{ color: hasPos ? accent : "#475569" }}>
                        {hasPos ? formatZUSDCNumber(openPositionMargin) : "—"}
                      </div>
                      <div className="mt-1 text-[9px]" style={{ color: `${accent}70` }}>
                        {hasPos && openPositionSide !== "N/A" ? openPositionSide : "no open position"}
                      </div>
                    </div>
                  );
                })()}

              </div>
              {hasPosition && entryPrice != null && positionMargin > 0 && displayPrice?.price && (
                <div className="mt-3">
                <PositionPnLDisplay
                  side={positionSide}
                  entryPrice={entryPrice}
                  leverage={pos?.leverage ?? leverage}
                  margin={positionMargin}
                  markPrice={displayPrice?.price}
                />
                </div>
              )}

              {/* Tabs */}
              <div className="flex gap-2 p-1 bg-[#121421] rounded-xl border border-[#363a59]">
                <button
                  onClick={() => setActiveTab("trade")}
                  className={`flex-1 py-2.5 rounded-lg font-medium transition ${activeTab === "trade" ? "bg-[#3d51ff] text-white" : "text-slate-400 hover:text-white"}`}
                >
                  Trade
                </button>
                <button
                  onClick={() => setActiveTab("deposit")}
                  className={`flex-1 py-2.5 rounded-lg font-medium transition ${activeTab === "deposit" ? "bg-[#3d51ff] text-white" : "text-slate-400 hover:text-white"}`}
                >
                  Deposit / Withdraw
                </button>
              </div>

              {activeTab === "trade" ? (
                <div className="bg-gradient-to-br from-[#1e2033] to-[#16182e] rounded-2xl border border-[#363a59] p-6 shadow-xl">
                <div className="grid gap-3 mb-4 md:grid-cols-3">
                  <div className="rounded-xl border border-[#363a59] bg-[#0d0f18] p-4">
                    <p className="text-[10px] uppercase text-slate-500">Entry Price</p>
                    <p className="text-lg font-semibold text-white">
                      {formatForSymbol(entryPrice ?? displayPrice?.price, chartSymbol)}
                    </p>
                  </div>
                  <div className="rounded-xl border border-[#363a59] bg-[#0d0f18] p-4">
                    <p className="text-[10px] uppercase text-slate-500">Liquidation</p>
                    <p className="text-lg font-semibold text-rose-400">{formatForSymbol(previewLiquidationPrice, chartSymbol)}</p>
                  </div>
                <div className="rounded-xl border border-[#363a59] bg-[#0d0f18] p-4">
                  <p className="text-[10px] uppercase text-slate-500">Size</p>
                  <p className="text-lg font-semibold text-slate-200">
                    {orderSize == null ? "—" : formatCurrency(orderSize)}
                  </p>
                </div>
                </div>
                <div className="grid gap-3 mb-4 md:grid-cols-2">
                  <div className="rounded-xl border border-[#363a59] bg-[#0d0f18] p-4">
                    <p className="text-[10px] uppercase text-slate-500">
                      Take Profit ({targetPercent}%)
                    </p>
                    <p className="text-lg font-semibold text-emerald-400">{formatForSymbol(previewTakeProfitPrice, chartSymbol)}</p>
                  </div>
                  <div className="rounded-xl border border-[#363a59] bg-[#0d0f18] p-4">
                    <p className="text-[10px] uppercase text-slate-500">
                      Stop Loss ({stopLossPercent}%)
                    </p>
                    <p className="text-lg font-semibold text-red-400">{formatForSymbol(previewStopLossPrice, chartSymbol)}</p>
                  </div>
                </div>
                  <div className="mb-4">
                    <div className="flex items-center justify-between text-xs text-slate-400">
                      <span>Select Take Profit level</span>
                      <span>{targetPercent}%</span>
                    </div>
                    <input
                      type="range"
                      min="1"
                      max="20"
                      value={targetPercent}
                      onChange={(event) => setTargetPercent(Number(event.target.value))}
                      className="w-full h-2 mt-2 accent-blue-500"
                    />
                  </div>
                  <div className="mb-4">
                    <div className="flex items-center justify-between text-xs text-slate-400">
                      <span>Select Stop Loss level</span>
                      <span>{stopLossPercent}%</span>
                    </div>
                    <input
                      type="range"
                      min="1"
                      max="20"
                      value={stopLossPercent}
                      onChange={(event) => setStopLossPercent(Number(event.target.value))}
                      className="w-full h-2 mt-2 accent-red-500"
                    />
                  </div>
                    <div className="text-xs text-slate-400 mb-3">
                      Stop Loss Price: {formatForSymbol(previewStopLossPrice, chartSymbol)}
                    </div>
                  <div className="mb-4 rounded-2xl border border-[#2c2f45] bg-[#0a0c17] p-4 space-y-4">
                    <div className="flex gap-2">
                      <button
                        onClick={() => setPositionType("Long")}
                        className={`flex-1 py-3 rounded-xl font-semibold transition ${
                          positionType === "Long"
                            ? "bg-green-500/20 text-green-400 border-2 border-green-500/50"
                            : "bg-[#363a59]/30 text-slate-400 border border-transparent hover:border-[#363a59]"
                        }`}
                        disabled={hasPosition}
                      >
                        Long
                      </button>
                      <button
                        onClick={() => setPositionType("Short")}
                        className={`flex-1 py-3 rounded-xl font-semibold transition ${
                          positionType === "Short"
                            ? "bg-red-500/20 text-red-400 border-2 border-red-500/50"
                            : "bg-[#363a59]/30 text-slate-400 border border-transparent hover:border-[#363a59]"
                        }`}
                        disabled={hasPosition}
                      >
                        Short
                      </button>
                    </div>
                    <div>
                      <div className="flex items-center justify-between text-sm mb-1">
                        <div>
                          <span className="text-slate-400">Leverage</span>
                          <span className="ml-2 text-[11px] text-slate-500">Max 25x</span>
                        </div>
                        <span className="text-slate-400">{leverage}x</span>
                      </div>
                      <input
                        type="range"
                        min="1"
                        max="25"
                        value={leverage}
                        onChange={(e) => setLeverage(Number(e.target.value))}
                        disabled={hasPosition || closeAmount.trim().length > 0}
                        className="w-full h-2 bg-[#363a59] rounded-lg appearance-none cursor-pointer accent-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
                      />
                      
                      {hasPosition && (
                        <p className="mt-1 text-[11px] text-slate-500">
                          Leverage matches the open position and cannot be changed here.
                        </p>
                      )}
                      {!hasPosition && closeAmount.trim().length > 0 && (
                        <p className="mt-1 text-[11px] text-slate-500">
                          Leverage locked to current position while close amount is active.
                        </p>
                      )}
                    </div>
                  </div>
                  <div className="mb-4">
                    <label className="block text-slate-400 text-sm mb-2">Amount (zUSDC)</label>
                    <input
                      type="text"
                      value={positionAmount}
                      onChange={(e) => handlePositionAmountChange(e.target.value)}
                      placeholder="0.00"
                      className="w-full px-4 py-3.5 rounded-xl bg-[#121421] border border-[#363a59] text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/50"
                    />
                  </div>
                  <button
                    onClick={hasPosition ? handleIncreasePosition : handleOpenPosition}
                    disabled={!positionAmount || isOpenPending || isIncreasePending || isSubmittingPosition}
                    className={`w-full py-4 rounded-xl font-semibold transition disabled:opacity-50 disabled:cursor-not-allowed ${
                      positionType === "Long" ? "bg-green-500 hover:bg-green-600 text-white" : "bg-red-500 hover:bg-red-600 text-white"
                    }`}
                  >
                    {isSubmittingPosition ? "Processing..." : hasPosition ? "Increase Position" : `Open ${positionType}`}
                  </button>

                  {hasPosition && (
                    <div className="mt-4 pt-4 border-t border-[#363a59]">
                      <div className="mb-4">
                        <label className="block text-slate-400 text-sm mb-2">Close Amount</label>
                        <input
                          type="text"
                          value={closeAmount}
                          onChange={(e) => handleCloseAmountChange(e.target.value)}
                          placeholder="0.00"
                          className="w-full px-4 py-3.5 rounded-xl bg-[#121421] border border-[#363a59] text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                        />
                      </div>
                      <button
                        onClick={() => handleClosePosition(chartSymbol)}
                        disabled={!closeAmount || isClosePending}
                        className="w-full py-3 rounded-xl font-semibold bg-gradient-to-r from-rose-500 via-rose-600 to-rose-700 text-white shadow-lg shadow-rose-900/40 transition hover:from-rose-400 hover:via-rose-500 hover:to-rose-600 hover:shadow-2xl disabled:opacity-50"
                      >
                        {isClosePending ? "Closing..." : "Close Position"}
                      </button>
                    </div>
                  )}
                </div>
              ) : (
                <div className="bg-gradient-to-br from-[#1e2033] to-[#16182e] rounded-2xl border border-[#363a59] p-6 space-y-6 shadow-xl">
                  <div>
                    <label className="block text-slate-400 text-sm mb-2">Deposit Amount</label>
                    <input
                      type="text"
                      value={depositAmount}
                      onChange={(e) => setDepositAmount(e.target.value)}
                      placeholder="0.00"
                      className="w-full px-4 py-3.5 rounded-xl bg-[#121421] border border-[#363a59] text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                    />
                    <button
                      onClick={handleDeposit}
                      disabled={!depositAmount || isDepositPending}
                      className="w-full mt-3 py-3.5 rounded-xl font-semibold bg-blue-500 hover:bg-blue-600 text-white transition disabled:opacity-50"
                    >
                      {isDepositPending ? "Processing..." : "Deposit"}
                    </button>
                  </div>
                  <div>
                    <label className="block text-slate-400 text-sm mb-2">Withdraw Amount</label>
                    <input
                      type="text"
                      value={withdrawAmount}
                      onChange={(e) => setWithdrawAmount(e.target.value)}
                      placeholder="0.00"
                      className="w-full px-4 py-3.5 rounded-xl bg-[#121421] border border-[#363a59] text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                    />
                    <button
                      onClick={handleWithdraw}
                      disabled={!withdrawAmount || isWithdrawPending}
                      className="w-full mt-3 py-3.5 rounded-xl font-semibold bg-[#363a59] hover:bg-[#4a4f6e] text-white transition disabled:opacity-50"
                    >
                      {isWithdrawPending ? "Processing..." : "Withdraw"}
                    </button>
                  </div>
                </div>
              )}

              {/* ── Signal Radar ── */}
              <RadarSignalPanel
                symbol={chartSymbol}
                resolution={chartResolution}
                tradingViewSymbol={tradingviewSymbol}
              />

              {/* ── Fear & Greed Index ── */}
              <FearGreedIndex />
            </>
          )}
        </div>
      </div>

      <div className="mt-6">
        <div className="rounded-2xl border border-[#363a59] bg-[#0d0f18]/80">
          <div className="flex flex-wrap items-center gap-2 border-b border-[#363a59]/40 bg-[#121421] px-3 py-3">
            {historyTabOptions.map((tab) => (
              <button
                key={tab.key}
                type="button"
                onClick={() => setHistoryTab(tab.key)}
                className={`flex-1 min-w-[140px] rounded-xl px-4 py-2 text-sm font-semibold text-center transition ${
                  historyTab === tab.key ? "bg-[#3d51ff] text-white" : "text-slate-400 hover:text-white hover:bg-[#1e2033]"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
          <div className="p-4 space-y-4">
            {historyEntries.length === 0 ? (
              <p className="text-sm text-slate-400">
                No trades have been recorded yet. Open or close a position to populate history.
              </p>
            ) : (
              <div className="history-scroll overflow-x-auto">
                <div className="flex flex-col items-start gap-3">
                  {historyEntries.map((entry) => renderHistoryEntry(entry))}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="mt-6">
        <div className="rounded-2xl border border-[#363a59] bg-[#0d0f18]/80">
          <div className="flex items-center justify-between border-b border-[#363a59]/40 bg-[#121421] px-3 py-3 text-sm uppercase tracking-[0.4em] text-slate-400">
            <span>Deposit / Withdraw History</span>
            <span className="text-xs normal-case text-slate-500">{depositWithdrawHistory.length} entries</span>
          </div>
          <div className="p-4 space-y-3">
            {depositWithdrawHistory.length === 0 ? (
              <p className="text-sm text-slate-400">No deposit or withdraw events yet.</p>
            ) : (
              depositWithdrawHistory.map((record) => (
                <div
                  key={`${record.id}-${record.timestamp}`}
                  className="flex items-center justify-between rounded-xl border border-[#1f2340] bg-[#0f1221]/60 px-4 py-3 text-sm text-white"
                >
                  <div className="space-y-1">
                    <div className="font-semibold text-[13px]">{record.type}</div>
                    <div className="text-[11px] text-slate-400">{formatTimestamp(record.timestamp)}</div>
                  </div>
                  <div className="text-[14px] font-semibold text-slate-100">{formatZUSDCNumber(record.amount)}</div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

    </div>

    {/* ── AI Chatbot Widget — fixed bottom-right ── */}
    <AIChatbotWidget />
    </>
  );
}
