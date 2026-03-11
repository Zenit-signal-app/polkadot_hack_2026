import { useEffect, useMemo, useRef, useState } from "react";
import {
  createChart,
  ColorType,
  LineStyle,
  LineWidth,
  type IChartApi,
  type UTCTimestamp,
  type Time,
  TickMarkType,
} from "lightweight-charts";
import {
  fetchPythBenchmarkHistory,
  type BenchmarkHistoryPoint,
  type PolkadotSymbol,
} from "@/services/polkadotPrice";
import useBinanceFootprintHistory, { tvResolutionToSeconds } from "@/hooks/useBinanceFootprintHistory";

declare global {
  interface Window {
    LighweightChartPlugin?: any;
    __LIGHTWEIGHT_CHART_PLUGIN_LOADED?: boolean;
  }
}

const SMA_LENGTH = 14;
const EMA_LENGTH = 12;
const RSI_LENGTH = 14;
const MOMENTUM_LENGTH = 12;
const ADX_LENGTH = 14;
const HT_AMPLITUDE = 2;
const HT_CHANNEL_DEV = 2;
const DEFAULT_RIGHT_OFFSET = 60;
const TPO_ACTIVE_BARS = 14;
const TPO_ATR_PERIOD = 5;
const TPO_ROW_DETAIL_PCT = 70;
const TPO_PERCENT_VA = 65;

const FOOTPRINT_LINE_COLOR = "#facc15";
const IMBALANCE_THRESHOLD = 0.35;
const IMBALANCE_MIN_VOL = 5;

const PRICE_BIN_DEFAULTS: Record<PolkadotSymbol, number> = {
  BTCUSD: 100,
  ETHUSD: 10,
  DOTUSD: 0.1,
};
const POLKADOT_TO_BINANCE: Record<PolkadotSymbol, string> = {
  BTCUSD: "BTCUSDT",
  ETHUSD: "ETHUSDT",
  DOTUSD: "DOTUSDT",
};

interface IndicatorPanelProps {
  symbol: PolkadotSymbol;
  /** Symbol string used by TradingView datafeed (e.g. "BTCUSD", "Crypto.DOT/USD") */
  tradingViewSymbol?: string;
  /** TradingView resolution string (e.g. "1", "5", "60", "1D", "1W") */
  resolution?: string;
  /** Right offset of the TradingView time scale (bars) */
  timeScaleRightOffset?: number;
  /** Visible logical range shared from the TradingView chart */
  visibleLogicalRange?: { from: number; to: number } | null;
}

/** Pyth Benchmarks API caps history at 1 year (~365 days) */
const MAX_RANGE_SECONDS = 360 * 86400;

/** Format time scale labels in user's local timezone */
function localTickMarkFormatter(time: Time, tickMarkType: TickMarkType, locale: string): string | null {
  let d: Date;
  if (typeof time === "number") {
    d = new Date(time * 1000);
  } else if (typeof time === "string") {
    d = new Date(time);
  } else {
    d = new Date(time.year, time.month - 1, time.day);
  }
  const opts: Intl.DateTimeFormatOptions = {};
  switch (tickMarkType) {
    case TickMarkType.Year:
      opts.year = "numeric";
      break;
    case TickMarkType.Month:
      opts.month = "short";
      break;
    case TickMarkType.DayOfMonth:
      opts.day = "numeric";
      break;
    case TickMarkType.Time:
      opts.hour12 = false;
      opts.hour = "2-digit";
      opts.minute = "2-digit";
      break;
    case TickMarkType.TimeWithSeconds:
      opts.hour12 = false;
      opts.hour = "2-digit";
      opts.minute = "2-digit";
      opts.second = "2-digit";
      break;
    default:
      return null;
  }
  return d.toLocaleString(locale, opts);
}

/** Map TradingView resolution to Pyth API params and range */
function IndicatorSubChart({
  title,
  legend,
  series,
  color,
  fullWidth = false,
  rightOffset,
  zones,
  zoneGradient,
}: IndicatorSubChartProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const lineSeriesRef = useRef<ReturnType<IChartApi["addLineSeries"]> | null>(null);
  const zoneSeriesRefs = useRef<ReturnType<IChartApi["addLineSeries"]>[]>([]);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return undefined;

    const chart = createChart(container, {
      layout: {
        background: { type: ColorType.Solid, color: "#0c101f" },
        textColor: "#94a3b8",
        fontFamily: "inherit",
      },
      grid: { vertLines: { color: "#161b30" }, horzLines: { color: "#161b30" } },
      rightPriceScale: {
        visible: true,
        borderVisible: true,
        borderColor: "#363a59",
        scaleMargins: { top: 0.05, bottom: 0.2 },
      },
      timeScale: { visible: false, rightOffset: rightOffset ?? DEFAULT_RIGHT_OFFSET },
      width: Math.max(container.clientWidth, 300),
      height: 240,
    });

    chartRef.current = chart;
    lineSeriesRef.current = chart.addLineSeries({
      color,
      lineWidth: 2,
      priceLineVisible: false,
    });
    chart.timeScale().fitContent();
    chart.priceScale("right").applyOptions({ autoScale: true, alignLabels: true });

    const ro = new ResizeObserver(() => {
      chart.applyOptions({ width: Math.max(container.clientWidth, 300) });
    });
    ro.observe(container);

    return () => {
      ro.disconnect();
      chart.remove();
      chartRef.current = null;
      lineSeriesRef.current = null;
    };
  }, [color, rightOffset]);

  useEffect(() => {
    if (!lineSeriesRef.current) return;
    lineSeriesRef.current.setData(series.map((point) => ({ time: point.time, value: point.value })));
  }, [series]);

  useEffect(() => {
    if (!chartRef.current) return;
    zoneSeriesRefs.current.forEach((seriesRef) => chartRef.current?.removeSeries(seriesRef));
    zoneSeriesRefs.current = [];
    if (!zones?.length) return;
    zoneSeriesRefs.current = zones.map((zone) => {
      const zoneSeries = chartRef.current!.addLineSeries({
        color: zone.color,
        lineWidth: (zone.lineWidth ?? 1) as LineWidth,
        lineStyle: zone.lineStyle ?? LineStyle.Dashed,
        priceLineVisible: false,
      });
      zoneSeries.setData(series.map((point) => ({ time: point.time, value: zone.value })));
      return zoneSeries;
    });
    return () => {
      zoneSeriesRefs.current.forEach((seriesRef) => chartRef.current?.removeSeries(seriesRef));
      zoneSeriesRefs.current = [];
    };
  }, [zones, series]);

  const latestValue = series[series.length - 1]?.value;
  return (
    <div className={`rounded-2xl border border-[#363a59] bg-[#080a14] p-4 text-sm ${fullWidth ? "w-full" : ""}`}>
      <div className="flex items-center justify-between pb-3 text-xs uppercase tracking-[0.4em] text-slate-500">
        <span>{title}</span>
        <span className="text-slate-400">{legend}</span>
      </div>
      <div className="text-lg font-semibold text-white mb-2">{latestValue?.toFixed(2) ?? "—"}</div>
      <div className="rounded-xl border border-[#1d2142] bg-[#0d0f18] overflow-hidden mt-3 relative" style={{ minHeight: 140 }}>
        {zoneGradient && (
          <div
            className="absolute inset-0 pointer-events-none opacity-70"
            style={{ background: zoneGradient }}
          />
        )}
        <div ref={containerRef} className="w-full h-[240px]" />
      </div>
    </div>
  );
}

function MultiSeriesSubChart({
  title,
  seriesSets,
  rightOffset,
  zones,
  zoneGradient,
}: MultiSeriesChartProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const lineSeriesRefs = useRef<ReturnType<IChartApi["addLineSeries"]>[]>([]);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return undefined;

    const chart = createChart(container, {
      layout: {
        background: { type: ColorType.Solid, color: "#0c101f" },
        textColor: "#94a3b8",
        fontFamily: "inherit",
      },
      grid: { vertLines: { color: "#161b30" }, horzLines: { color: "#161b30" } },
      rightPriceScale: { visible: true, borderVisible: true, borderColor: "#363a59", scaleMargins: { top: 0.05, bottom: 0.2 }, alignLabels: true },
      leftPriceScale: { visible: false },
      timeScale: { visible: false, rightOffset: rightOffset ?? DEFAULT_RIGHT_OFFSET },
      width: Math.max(container.clientWidth, 300),
      height: 240,
    });

    chartRef.current = chart;
    lineSeriesRefs.current = seriesSets.map((series) =>
      chart.addLineSeries({
        priceScaleId: "right",
        color: series.color,
        lineWidth: 2,
        priceLineVisible: true,
        title: series.label,
        priceLineColor: series.color,
        priceLineWidth: 2,
        lastValueVisible: true,
      })
    );
    chart.timeScale().fitContent();
    chart.priceScale("right").applyOptions({ autoScale: true });
    chart.priceScale("right").applyOptions({ autoScale: true });

    const ro = new ResizeObserver(() => {
      chart.applyOptions({ width: Math.max(container.clientWidth, 300) });
    });
    ro.observe(container);

    return () => {
      ro.disconnect();
      chart.remove();
      chartRef.current = null;
      lineSeriesRefs.current = [];
    };
  }, [seriesSets, rightOffset]);

  useEffect(() => {
    if (!lineSeriesRefs.current.length) return;
    lineSeriesRefs.current.forEach((seriesRef, index) => {
      const data = seriesSets[index]?.data ?? [];
      seriesRef.setData(data.map((point) => ({ time: point.time, value: point.value })));
    });
  }, [seriesSets]);

  useEffect(() => {
    if (!chartRef.current) return;
    const zoneSeries = zones?.map((zone) => {
      const seriesRef = chartRef.current!.addLineSeries({
        color: zone.color,
        lineWidth: (zone.lineWidth ?? 1) as LineWidth,
        lineStyle: zone.lineStyle ?? LineStyle.Dashed,
        priceLineVisible: false,
      });
      seriesRef.setData(seriesSets[0]?.data.map((point) => ({ time: point.time, value: zone.value })));
      return seriesRef;
    });
    return () => {
      zoneSeries?.forEach((seriesRef) => chartRef.current?.removeSeries(seriesRef));
    };
  }, [zones, seriesSets]);

  const latestValues = seriesSets.map((series) => ({
    label: series.label,
    value: series.data[series.data.length - 1]?.value,
    color: series.color,
  }));

  return (
    <div
      className="rounded-2xl border border-[#363a59] bg-[#080a14] p-4 text-sm w-full"
      style={{ letterSpacing: "-0.5px", fontVariantNumeric: "tabular-nums" }}
    >
      <div className="flex flex-wrap items-center justify-between gap-3 pb-3 text-xs uppercase tracking-[0.4em] text-slate-500">
        <span>{title}</span>
          <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-200">
            {latestValues.map((item) => (
              <span
                key={item.label}
                className="flex items-center gap-1 rounded-full bg-[#121421]/80 px-1 py-1 text-[10px]"
                style={{ letterSpacing: "-0.05em", fontVariantNumeric: "tabular-nums" }}
              >
              <span className="h-2 w-2 rounded-full" style={{ background: item.color }}></span>
              <span className="min-w-[48px] text-left">
                {item.label} {item.value?.toFixed(2) ?? "—"}
              </span>
            </span>
          ))}
        </div>
      </div>
      <div className="rounded-xl border border-[#1d2142] bg-[#0d0f18] overflow-hidden relative" style={{ minHeight: 240 }}>
        {zoneGradient && (
          <div
            className="absolute inset-0 pointer-events-none opacity-70"
            style={{ background: zoneGradient }}
          />
        )}
        <div ref={containerRef} className="w-full h-[240px]" />
      </div>
    </div>
  );
}

interface FootprintHistoryChartProps {
  polkadotSymbol?: PolkadotSymbol;
  priceBin: number;
  lineColor: string;
  numBars?: number;
  barSeconds?: number;
  resolution?: string;
  displayPrice?: number;
}

function FootprintHistoryChart({
  polkadotSymbol,
  priceBin,
  lineColor,
  numBars,
  barSeconds = 60,
  resolution,
  displayPrice,
}: FootprintHistoryChartProps) {
  const binanceSymbol = polkadotSymbol ? POLKADOT_TO_BINANCE[polkadotSymbol] ?? "BTCUSDT" : "BTCUSDT";
  const { bars, loading, error } = useBinanceFootprintHistory(
    binanceSymbol,
    barSeconds,
    priceBin,
    numBars,
    Math.max(barSeconds * 1000, 30_000)
  );
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [hoverInfo, setHoverInfo] = useState<{
    price: number;
    x: number;
    y: number;
    color: string;
  } | null>(null);

  // Layout constants
  const LABEL_W = 68;   // Y-axis price labels
  const TIME_H = 22;    // X-axis time labels
  const BAR_W = 90;     // width per bar column
  const ROW_H = 18;     // height per price level row
  const PAD = 1;        // gap between cells

  // Collect all unique price levels (sorted descending)
  const { sortedPrices, decimals, canvasW, canvasH, barsWidth } = useMemo(() => {
    if (bars.length === 0) return { sortedPrices: [], decimals: 0, canvasW: 200, canvasH: 120, barsWidth: 0 };
    const allLevels = new Set<number>();
    bars.forEach((bar) => {
      Object.keys(bar.clusters).forEach((l) => allLevels.add(Number(l)));
    });
    const dec = Math.max(0, -Math.floor(Math.log10(priceBin)));
    const sorted = Array.from(allLevels).sort((a, b) => b - a);
    const barsW = bars.length * BAR_W;
    const cW = barsW + LABEL_W;
    const cH = sorted.length * ROW_H + TIME_H;
    return { sortedPrices: sorted, decimals: dec, canvasW: cW, canvasH: cH, barsWidth: barsW };
  }, [bars, priceBin]);

  const containerHeight = Math.max(canvasH, 420);
  const symbolLabel = polkadotSymbol ?? "BTCUSD";
  const formattedPrice =
    displayPrice == null
      ? "—"
      : `$${displayPrice.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  const fallbackResolution =
    barSeconds >= 86400
      ? `${barSeconds / 86400}D`
      : barSeconds >= 3600
      ? `${barSeconds / 3600}h`
      : `${barSeconds / 60}m`;
  const resolutionLabel = resolution ?? fallbackResolution;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || bars.length === 0 || sortedPrices.length === 0) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    canvas.width = canvasW * dpr;
    canvas.height = canvasH * dpr;
    canvas.style.width = canvasW + "px";
    canvas.style.height = canvasH + "px";
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, canvasW, canvasH);

    // Global background
    ctx.fillStyle = "#080a14";
    ctx.fillRect(0, 0, canvasW, canvasH);

    // Find global max vol for scaling bars within each column
    const colMaxVol = bars.map((bar) =>
      Math.max(1, ...Object.values(bar.clusters).map((c) => c.total_vol))
    );

    const priceTop = sortedPrices[0] ?? 0;
    const priceBottom = sortedPrices[sortedPrices.length - 1] ?? priceTop;
    const priceRange = Math.max(0.0001, priceTop - priceBottom);
    const priceToY = (price: number) => {
      const constrained = Math.min(priceTop, Math.max(priceBottom, price));
      return ((priceTop - constrained) / priceRange) * sortedPrices.length * ROW_H;
    };

    bars.forEach((bar, barIdx) => {
      const colX = barIdx * BAR_W;
      const barCenterX = colX + BAR_W / 2;
      const bodyWidth = Math.max(1, (BAR_W * 2) / 3);
      const bodyLeft = barCenterX - bodyWidth / 2;
      const maxVol = colMaxVol[barIdx];

      sortedPrices.forEach((price, priceIdx) => {
        const cellY = priceIdx * ROW_H;
        const priceKey = price.toFixed(decimals);
        const cluster = bar.clusters[priceKey];
        const isVpoc = bar.vpocPrice === priceKey;

        // Cell background
        ctx.fillStyle = isVpoc
          ? "rgba(250,204,21,0.10)"
          : priceIdx % 2 === 0
          ? "#0a0d1b"
          : "#0c0f1e";
        ctx.fillRect(colX + PAD, cellY, BAR_W - PAD * 2, ROW_H - 1);

        if (cluster && cluster.total_vol > 0) {
          const half = (BAR_W - PAD * 2) / 2;
          const buyW = (cluster.buy_vol / maxVol) * half;
          const sellW = (cluster.sell_vol / maxVol) * half;
          const cellH = ROW_H - 2;
          const imbalance = cluster.buy_vol - cluster.sell_vol;
          const strength = Math.abs(imbalance) / Math.max(cluster.total_vol, 1);
          if (cluster.total_vol >= IMBALANCE_MIN_VOL && strength >= IMBALANCE_THRESHOLD) {
            ctx.fillStyle = imbalance > 0 ? "rgba(34,197,94,0.12)" : "rgba(248,113,113,0.12)";
            ctx.fillRect(colX + PAD, cellY + 1, BAR_W - PAD * 2, cellH);
          }

          ctx.fillStyle = "rgba(34,197,94,0.72)";
          ctx.fillRect(colX + PAD + half, cellY + 1, buyW, cellH);

          ctx.fillStyle = "rgba(248,113,113,0.72)";
          ctx.fillRect(colX + PAD + half - sellW, cellY + 1, sellW, cellH);
        }

        // VPOC highlight border
        if (isVpoc) {
          const pocWidth = Math.max(2, bodyWidth - 1);
          const pocX = bodyLeft + (bodyWidth - pocWidth) / 2;
          ctx.strokeStyle = lineColor;
          ctx.lineWidth = 1.5;
          ctx.strokeRect(pocX, cellY + 0.75, pocWidth, ROW_H - 2.5);
        }

        if (cluster && cluster.total_vol > 0) {
          const labelY = cellY + 10;
          ctx.font = "8px monospace";
          ctx.fillStyle = "rgba(255,255,255,0.95)";
          ctx.textAlign = "center";
          ctx.fillText(`${cluster.buy_vol.toFixed(1)} / ${cluster.sell_vol.toFixed(1)}`, barCenterX, labelY);
        }

      });

      // Column separator
      ctx.strokeStyle = "#1d2142";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(colX, 0);
      ctx.lineTo(colX, canvasH - TIME_H);
      ctx.stroke();

      // Time label (bottom) — format depends on bar duration
      const d = new Date(bar.barStart * 1000);
    const timeLabel = barSeconds >= 86400
      ? `${(d.getMonth() + 1).toString().padStart(2, "0")}/${d.getDate().toString().padStart(2, "0")}`
      : barSeconds >= 3600
      ? `${d.getHours().toString().padStart(2, "0")}h`
      : `${d.getHours().toString().padStart(2, "0")}:${d.getMinutes().toString().padStart(2, "0")}`;
      ctx.fillStyle = "#475569";
      ctx.font = "9px monospace";
      ctx.textAlign = "center";
      ctx.fillText(timeLabel, colX + BAR_W / 2, canvasH - 6);

      // VPOC price label below time
      if (bar.vpocPrice) {
        ctx.fillStyle = lineColor;
        ctx.font = "bold 8px monospace";
        ctx.textAlign = "center";
        ctx.fillText("V" + bar.vpocPrice, colX + BAR_W / 2, canvasH - 14);
      }

      const candleColor =
        bar.close >= bar.open ? "rgba(37,211,102,1)" : "rgba(248,113,113,1)";
      const highY = priceToY(bar.high);
      const lowY = priceToY(bar.low);
      const openY = priceToY(bar.open);
      const closeY = priceToY(bar.close);
      const bodyTop = Math.min(openY, closeY);
      const bodyHeight = Math.max(2, Math.abs(closeY - openY));

      ctx.strokeStyle = candleColor;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(barCenterX, highY);
      ctx.lineTo(barCenterX, bodyTop);
      ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(barCenterX, bodyTop + bodyHeight);
      ctx.lineTo(barCenterX, lowY);
      ctx.stroke();

      ctx.strokeRect(
        bodyLeft,
        bodyTop,
        bodyWidth,
        bodyHeight
      );

    });

    // Price column background
    ctx.fillStyle = "#050817";
    ctx.fillRect(barsWidth, 0, LABEL_W, canvasH - TIME_H);

    // Y-axis price labels
    sortedPrices.forEach((price, i) => {
      ctx.fillStyle = "#475569";
      ctx.font = "9px monospace";
      ctx.textAlign = "right";
      ctx.fillText(
        price.toFixed(decimals),
        barsWidth + LABEL_W - 4,
        i * ROW_H + ROW_H * 0.72
      );
    });

    // Y-axis separator line
    ctx.strokeStyle = "#1d2142";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(barsWidth, 0);
    ctx.lineTo(barsWidth, canvasH - TIME_H);
    ctx.stroke();
  }, [bars, sortedPrices, decimals, canvasW, canvasH, lineColor, barSeconds, barsWidth]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || bars.length === 0) return undefined;
    const handleMove = (event: MouseEvent) => {
      const rect = canvas.getBoundingClientRect();
      const relX = event.clientX - rect.left;
      const barIdx = Math.floor(relX / BAR_W);
      if (barIdx < 0 || barIdx >= bars.length) {
        setHoverInfo(null);
        return;
      }
      const bar = bars[barIdx];
      if (!bar || !bar.vpocPrice) {
        setHoverInfo(null);
        return;
      }
      const cluster = bar.clusters[bar.vpocPrice];
      if (!cluster) {
        setHoverInfo(null);
        return;
      }
      let color = "#fff";
      if (cluster.sell_vol > cluster.buy_vol) {
        color = "#f87171";
      } else if (cluster.buy_vol > cluster.sell_vol) {
        color = "#22c55e";
      }
      setHoverInfo({
        price: Number(bar.vpocPrice),
        x: event.clientX - rect.left,
        y: event.clientY - rect.top,
        color,
      });
    };
    const handleLeave = () => setHoverInfo(null);
    canvas.addEventListener("mousemove", handleMove);
    canvas.addEventListener("mouseleave", handleLeave);
    return () => {
      canvas.removeEventListener("mousemove", handleMove);
      canvas.removeEventListener("mouseleave", handleLeave);
    };
  }, [bars]);

  return (
    <div className="rounded-2xl border border-[#363a59] bg-[#080a14] p-4 text-sm w-full">
      <div className="flex flex-wrap items-center justify-between gap-2 pb-3 text-xs uppercase tracking-[0.4em] text-slate-500">
        <div className="space-y-1 text-right">
          <span className="font-semibold text-white">Footprint History · {symbolLabel} · {formattedPrice}</span>
          <span className="text-[11px] text-slate-500">Pyth Benchmarks · {resolutionLabel}</span>
        </div>
        <div className="flex flex-wrap gap-3 normal-case tracking-normal text-[11px] items-center justify-end text-right">
          <span className="inline-flex items-center gap-1">
            <span className="inline-block w-2 h-2 rounded-sm bg-green-500/70" />
            Buy
          </span>
          <span className="inline-flex items-center gap-1">
            <span className="inline-block w-2 h-2 rounded-sm bg-red-400/70" />
            Sell
          </span>
          <span className="text-slate-500">bin≈{priceBin.toFixed(2)} · {bars.length} bars</span>
          {loading && <span className="text-slate-600 animate-pulse">Loading…</span>}
          {error && <span className="text-rose-400" title={error}>Error</span>}
        </div>
      </div>
      <div
        className="overflow-auto relative flex justify-end rounded-xl border border-[#1d2142] bg-[#080a14]"
        style={{ minHeight: containerHeight }}
      >
        {bars.length === 0 && !loading && (
          <div className="flex items-center justify-center h-24 text-xs text-slate-500">
            {error ? `Binance API error: ${error}` : "Đang tải dữ liệu Binance…"}
          </div>
        )}
        {bars.length === 0 && loading && (
          <div className="flex items-center justify-center h-24 text-xs text-slate-500 animate-pulse">
            Đang tải lịch sử giao dịch…
          </div>
        )}
        <canvas
          ref={canvasRef}
          style={{
            display: bars.length > 0 ? "block" : "none",
            marginLeft: "auto",
          }}
        />
      </div>
      {hoverInfo && (
        <div
          className="pointer-events-none absolute z-10 rounded border border-[#363a59] bg-[#0d1020] px-2 py-1 text-[11px] font-mono shadow-lg"
          style={{
            left: Math.max(
              4,
              Math.min(canvasW - 120, hoverInfo.x + 8)
            ),
            top: Math.max(
              4,
              Math.min(canvasH - 30, hoverInfo.y - 26)
            ),
            color: hoverInfo.color,
          }}
        >
          {`POC ${hoverInfo.price?.toFixed(2) ?? "—"}`}
        </div>
      )}
    </div>
  );
}

function resolutionToParams(tvResolution: string): { resolution: string; rangeSeconds: number; resolutionSeconds: number } {
  const r = String(tvResolution || "1D").trim();
  const rUpper = r.toUpperCase();

  let resolutionSeconds: number;
  let resolution: string;

  if (["1", "2", "5", "15", "30"].includes(rUpper)) {
    resolutionSeconds = parseInt(r, 10) * 60;
    resolution = r;
  } else if (["60", "120", "240"].includes(rUpper)) {
    resolutionSeconds = parseInt(r, 10) * 60;
    resolution = r;
  } else if (rUpper === "1W" || rUpper === "W") {
    resolutionSeconds = 604800;
    resolution = "1W";
  } else if (rUpper === "1M" || rUpper === "M") {
    resolutionSeconds = 2592000;
    resolution = "1M";
  } else {
    resolutionSeconds = 86400;
    resolution = "1D";
  }

  const targetBars = 300;
  const rangeSeconds = Math.min(resolutionSeconds * targetBars, MAX_RANGE_SECONDS);

  return { resolution, rangeSeconds, resolutionSeconds };
}

type IndicatorPoint = { time: UTCTimestamp; value: number };

interface IndicatorSubChartProps {
  title: string;
  legend: string;
  series: IndicatorPoint[];
  color: string;
  fullWidth?: boolean;
  rightOffset?: number;
  zones?: Array<{ value: number; color: string; lineStyle?: LineStyle; lineWidth?: number }>;
  zoneGradient?: string;
}

interface MultiSeriesChartProps {
  title: string;
  seriesSets: Array<{ label: string; color: string; data: IndicatorPoint[] }>;
  rightOffset?: number;
  zones?: Array<{ value: number; color: string; lineStyle?: LineStyle; lineWidth?: number }>;
  zoneGradient?: string;
}

function calculateSMA(history: BenchmarkHistoryPoint[], length: number): IndicatorPoint[] {
  const result: IndicatorPoint[] = [];
  if (!history.length || history.length < length) return result;
  let sum = 0;
  for (let i = 0; i < history.length; i += 1) {
    sum += history[i].close;
    if (i >= length) sum -= history[i - length].close;
    if (i >= length - 1) {
      result.push({ time: history[i].time as UTCTimestamp, value: sum / length });
    }
  }
  return result;
}

function calculateEMA(history: BenchmarkHistoryPoint[], length: number): IndicatorPoint[] {
  if (!history.length || history.length < length) return [];
  const k = 2 / (length + 1);
  const result: IndicatorPoint[] = [];
  let ema = history.slice(0, length).reduce((s, p) => s + p.close, 0) / length;
  result.push({ time: history[length - 1].time as UTCTimestamp, value: ema });
  for (let i = length; i < history.length; i += 1) {
    ema = history[i].close * k + ema * (1 - k);
    result.push({ time: history[i].time as UTCTimestamp, value: ema });
  }
  return result;
}

function calculateRSI(history: BenchmarkHistoryPoint[], length: number): IndicatorPoint[] {
  if (!history.length || history.length <= length) return [];
  const result: IndicatorPoint[] = [];
  for (let i = length; i < history.length; i += 1) {
    let gains = 0;
    let losses = 0;
    for (let j = i - length + 1; j <= i; j += 1) {
      const change = history[j].close - history[j - 1].close;
      if (change > 0) gains += change;
      else losses -= change;
    }
    const avgGain = gains / length;
    const avgLoss = losses / length;
    const rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
    const rsi = 100 - 100 / (1 + rs);
    result.push({ time: history[i].time as UTCTimestamp, value: Math.min(100, Math.max(0, rsi)) });
  }
  return result;
}

function calculateMomentum(history: BenchmarkHistoryPoint[], length: number): IndicatorPoint[] {
  if (!history.length || history.length <= length) return [];
  return history.slice(length).map((point, index) => ({
    time: point.time as UTCTimestamp,
    value: point.close - history[index].close,
  }));
}

interface TpoHistogramBin {
  price: number;
  count: number;
}

interface TpoResult {
  poc: number;
  vah: number;
  val: number;
  segments: number[];
  histogram: TpoHistogramBin[];
}

function computeTpoRowHeight(
  ohlc: Array<{ high: number; low: number; close: number }>,
  period: number,
  detailPct: number,
  pipSize: number
): number {
  const atrArr = calculateATR(ohlc, period);
  if (!atrArr.length) return pipSize * 4;
  const atrInTick = atrArr[atrArr.length - 1] / pipSize;
  const priceInTick = ohlc[ohlc.length - 1].close / pipSize;
  if (priceInTick <= 0) return pipSize * 4;
  const kFactor = (atrInTick * detailPct) / priceInTick;
  const rowSizeInTick = (atrInTick * atrInTick) / (kFactor * priceInTick);
  const rowSizePips = Math.max(0.3, Math.round(rowSizeInTick * 100) / 100);
  return pipSize * rowSizePips;
}

function createTpoSegments(open: number, lowest: number, highest: number, rowHeight: number): number[] {
  const segments: number[] = [];
  let value = open;
  while (value >= lowest - rowHeight) {
    segments.push(value);
    value = Math.abs(value - rowHeight);
  }
  value = open;
  while (value <= highest + rowHeight) {
    segments.push(value);
    value = Math.abs(value + rowHeight);
  }
  return Array.from(new Set(segments)).sort((a, b) => a - b);
}

function buildTpoHistogram(
  bars: Array<{ high: number; low: number }>,
  segments: number[],
  rowHeight: number
): Map<number, number> {
  const histogram = new Map<number, number>();
  if (!segments.length) return histogram;
  for (const bar of bars) {
    const { high, low } = bar;
    let letters = 0;
    for (const segment of segments) {
      if (segment < high && segment > low) letters += 1;
    }
    let current = high;
    for (let i = 0; i <= letters; i += 1) {
      let prev = 0;
      for (const segment of segments) {
        if (prev !== 0 && current >= prev && current <= segment) {
          histogram.set(segment, (histogram.get(segment) ?? 0) + 1);
          break;
        }
        prev = segment;
      }
      current = Math.abs(current - rowHeight);
    }
  }
  return histogram;
}

function calculateVaPocFromHistogram(
  histogram: Map<number, number>,
  segments: number[],
  percent: number,
  rowHeight: number
): TpoResult | null {
  const entries = Array.from(histogram.entries());
  if (entries.length < 4) return null;
  const totalLetters = entries.reduce((sum, [, value]) => sum + value, 0);
  const target = Math.round((percent / 100) * totalLetters);
  let poc = 0;
  let maxCount = -Infinity;
  for (const [price, count] of entries) {
    if (count > maxCount) {
      maxCount = count;
      poc = price;
    }
  }
  let running = histogram.get(poc) ?? 0;
  let upper = poc;
  let lower = poc;
  const sortedSegments = segments;
  const segmentIndex = sortedSegments.indexOf(poc);
  let iUp = segmentIndex;
  let iDown = segmentIndex;
  while (running < target && (iUp < sortedSegments.length - 1 || iDown > 0)) {
    const upPrice = iUp < sortedSegments.length - 1 ? sortedSegments[iUp + 1] : undefined;
    const downPrice = iDown > 0 ? sortedSegments[iDown - 1] : undefined;
    const upValue = upPrice !== undefined ? histogram.get(upPrice) ?? 0 : 0;
    const downValue = downPrice !== undefined ? histogram.get(downPrice) ?? 0 : 0;
    if (upValue >= downValue && upPrice !== undefined) {
      running += upValue;
      upper = upPrice;
      iUp += 1;
    } else if (downPrice !== undefined) {
      running += downValue;
      lower = downPrice;
      iDown -= 1;
    } else {
      break;
    }
  }
  const vah = upper + rowHeight;
  const val = lower - rowHeight;
  const histogramBins: TpoHistogramBin[] = segments.map((price) => ({
    price,
    count: histogram.get(price) ?? 0,
  }));
  return {
    poc,
    vah,
    val,
    segments,
    histogram: histogramBins,
  };
}

function getTpoLevels(history: BenchmarkHistoryPoint[]): TpoResult | null {
  if (history.length < TPO_ACTIVE_BARS + TPO_ATR_PERIOD) return null;
  const ohlc = ensureOHLC(history);
  const activeBars = ohlc.slice(-TPO_ACTIVE_BARS);
  const lastClose = ohlc[ohlc.length - 1]?.close ?? 0;
  const pipSize = lastClose >= 1 ? 0.01 : 0.0001;
  const rowHeight = computeTpoRowHeight(ohlc, TPO_ATR_PERIOD, TPO_ROW_DETAIL_PCT, pipSize);
  const open = activeBars[0].open ?? activeBars[0].close;
  const lowest = Math.min(...activeBars.map((b) => b.low));
  const highest = Math.max(...activeBars.map((b) => b.high));
  const segments = createTpoSegments(open, lowest, highest, rowHeight);
  if (!segments.length) return null;
  const histogram = buildTpoHistogram(
    activeBars.map((b) => ({ high: b.high, low: b.low })),
    segments,
    rowHeight
  );
  return calculateVaPocFromHistogram(histogram, segments, TPO_PERCENT_VA, rowHeight);
}


function calculateATR(ohlc: Array<{ high: number; low: number; close: number }>, period: number): number[] {
  const tr: number[] = [];
  for (let i = 1; i < ohlc.length; i += 1) {
    const { high, low } = ohlc[i];
    const prevClose = ohlc[i - 1].close;
    tr.push(Math.max(high - low, Math.abs(high - prevClose), Math.abs(low - prevClose)));
  }
  const result: number[] = [];
  let sum = tr.slice(0, period).reduce((a, b) => a + b, 0);
  result.push(sum / period);
  for (let i = period; i < tr.length; i += 1) {
    sum = sum - sum / period + tr[i];
    result.push(sum / period);
  }
  return result;
}

interface HalfTrendPoint {
  time: number;
  value: number;
  trend: 0 | 1;
  buySignal?: boolean;
  sellSignal?: boolean;
}

function calculateHalfTrend(
  history: BenchmarkHistoryPoint[],
  amplitude: number,
  channelDev: number
): HalfTrendPoint[] {
  const ohlc = ensureOHLC(history);
  if (ohlc.length < 110) return [];

  const atrArr = calculateATR(ohlc, 100);
  const result: HalfTrendPoint[] = [];
  let trend: 0 | 1 = 0;
  let nextTrend = 0;
  let maxLowPrice = ohlc[0].low;
  let minHighPrice = ohlc[0].high;
  let up = ohlc[0].low;
  let down = ohlc[0].high;

  for (let i = 1; i < ohlc.length; i += 1) {
    const atrIdx = i - 100;
    if (atrIdx < 0) continue;
    const atr2 = atrArr[atrIdx] / 2;
    const dev = channelDev * atr2;

    const highPrice = Math.max(...ohlc.slice(Math.max(0, i - amplitude), i + 1).map((b) => b.high));
    const lowPrice = Math.min(...ohlc.slice(Math.max(0, i - amplitude), i + 1).map((b) => b.low));
    const highma = ohlc.slice(Math.max(0, i - amplitude + 1), i + 1).reduce((s, b) => s + b.high, 0) / Math.min(amplitude, i + 1);
    const lowma = ohlc.slice(Math.max(0, i - amplitude + 1), i + 1).reduce((s, b) => s + b.low, 0) / Math.min(amplitude, i + 1);

    const prevLow = ohlc[i - 1].low;
    const prevHigh = ohlc[i - 1].high;
    const { close } = ohlc[i];

    if (nextTrend === 1) {
      maxLowPrice = Math.max(lowPrice, maxLowPrice);
      if (highma < maxLowPrice && close < prevLow) {
        trend = 1;
        nextTrend = 0;
        minHighPrice = highPrice;
      }
    } else {
      minHighPrice = Math.min(highPrice, minHighPrice);
      if (lowma > minHighPrice && close > prevHigh) {
        trend = 0;
        nextTrend = 1;
        maxLowPrice = lowPrice;
      }
    }

    let arrowUp: number | null = null;
    let arrowDown: number | null = null;
    const prevTrend = result[result.length - 1]?.trend;

    if (trend === 0) {
      if (prevTrend !== undefined && prevTrend !== 0) {
        up = down;
        arrowUp = up - atr2;
      } else {
        up = Math.max(maxLowPrice, up);
      }
      down = up - dev;
    } else {
      if (prevTrend !== undefined && prevTrend !== 1) {
        down = up;
        arrowDown = down + atr2;
      } else {
        down = Math.min(minHighPrice, down);
      }
      up = down + dev;
    }

    const ht = trend === 0 ? up : down;
    const buySignal = arrowUp !== null && trend === 0 && prevTrend === 1;
    const sellSignal = arrowDown !== null && trend === 1 && prevTrend === 0;

    result.push({
      time: ohlc[i].time,
      value: ht,
      trend,
      buySignal,
      sellSignal,
    });
  }
  return result;
}

/** Ensure OHLC for ADX; synthesize from close when missing */
function ensureOHLC(history: BenchmarkHistoryPoint[]): Array<{ high: number; low: number; close: number; open: number; time: number; volume: number }> {
  return history.map((p, i) => {
    const open = p.open ?? (i > 0 ? history[i - 1].close : p.close);
    const close = p.close;
    const high = p.high ?? Math.max(open, close);
    const low = p.low ?? Math.min(open, close);
    const volume = p.volume ?? 0;
    return { open, high, low, close, time: p.time, volume };
  });
}

function formatPluginTime(seconds?: number) {
  const ts = seconds ?? Math.floor(Date.now() / 1000);
  const date = new Date(ts * 1000);
  const pad = (value: number) => value.toString().padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(
    date.getHours()
  )}:${pad(date.getMinutes())}`;
}

function calculateADX(
  history: BenchmarkHistoryPoint[],
  length: number
): { adx: IndicatorPoint[]; plusDI: IndicatorPoint[]; minusDI: IndicatorPoint[] } {
  const ohlc = ensureOHLC(history);
  if (ohlc.length < length * 2) return { adx: [], plusDI: [], minusDI: [] };

  let trSum = 0;
  let plusDMSum = 0;
  let minusDMSum = 0;

  const dxData: Array<{ time: number; value: number }> = [];
  const diSnapshots: Array<{ time: number; pdi: number; mdi: number }> = [];

  for (let i = 1; i < ohlc.length; i += 1) {
    const { high, low } = ohlc[i];
    const prevClose = ohlc[i - 1].close;
    const prevHigh = ohlc[i - 1].high;
    const prevLow = ohlc[i - 1].low;
    const tr = Math.max(high - low, Math.abs(high - prevClose), Math.abs(low - prevClose));
    const upMove = high - prevHigh;
    const downMove = prevLow - low;
    const plusDM = upMove > downMove && upMove > 0 ? upMove : 0;
    const minusDM = downMove > upMove && downMove > 0 ? downMove : 0;

    if (i <= length) {
      trSum += tr;
      plusDMSum += plusDM;
      minusDMSum += minusDM;
      if (i < length) continue;
    } else {
      trSum = trSum - trSum / length + tr;
      plusDMSum = plusDMSum - plusDMSum / length + plusDM;
      minusDMSum = minusDMSum - minusDMSum / length + minusDM;
    }

    const atr = trSum;
    const pdi = atr === 0 ? 0 : (100 * plusDMSum) / atr;
    const mdi = atr === 0 ? 0 : (100 * minusDMSum) / atr;
    const diSum = pdi + mdi;
    const dxVal = diSum === 0 ? 0 : (100 * Math.abs(pdi - mdi)) / diSum;
    const time = ohlc[i].time;
    dxData.push({ time, value: dxVal });
    diSnapshots.push({ time, pdi, mdi });
  }

  if (dxData.length < length) return { adx: [], plusDI: [], minusDI: [] };

  let adxValue = dxData.slice(0, length).reduce((sum, item) => sum + item.value, 0) / length;
  const adx: IndicatorPoint[] = [];
  const plusDI: IndicatorPoint[] = [];
  const minusDI: IndicatorPoint[] = [];

  for (let idx = length - 1; idx < dxData.length; idx += 1) {
    if (idx > length - 1) {
      adxValue = ((adxValue * (length - 1)) + dxData[idx].value) / length;
    }
    const time = dxData[idx].time as UTCTimestamp;
    adx.push({ time, value: Math.max(0, Math.min(100, adxValue)) });
    plusDI.push({ time, value: Math.max(0, Math.min(100, diSnapshots[idx].pdi)) });
    minusDI.push({ time, value: Math.max(0, Math.min(100, diSnapshots[idx].mdi)) });
  }

  return { adx, plusDI, minusDI };
}

function generateFallbackData(symbol: PolkadotSymbol, resolutionSeconds = 3600): BenchmarkHistoryPoint[] {
  const basePrice = symbol === "DOTUSD" ? 5 : symbol === "ETHUSD" ? 2200 : 70000;
  const points: BenchmarkHistoryPoint[] = [];
  const barCount = 168;
  let time = Math.floor(Date.now() / 1000) - barCount * resolutionSeconds;
  let price = basePrice;
  for (let i = 0; i < barCount; i += 1) {
    const prevClose = price;
    price = price * (1 + (Math.random() - 0.48) * 0.02);
    const close = Math.round(price * 100) / 100;
    const open = i === 0 ? close : prevClose;
    const high = Math.max(open, close) * (1 + Math.random() * 0.005);
    const low = Math.min(open, close) * (1 - Math.random() * 0.005);
    const volume = (high - low) * (500 + Math.random() * 500);
    points.push({ time, close, open, high, low, volume });
    time += resolutionSeconds;
  }
  return points;
}

function formatPercent(value?: number) {
  if (value == null || Number.isNaN(value)) return "—";
  const sign = value > 0 ? "+" : "";
  return `${sign}${value.toFixed(2)}%`;
}

export default function IndicatorPanel({ symbol, tradingViewSymbol, resolution, timeScaleRightOffset, visibleLogicalRange }: IndicatorPanelProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const priceSeriesRef = useRef<ReturnType<IChartApi["addLineSeries"]> | null>(null);
  const smaSeriesRef = useRef<ReturnType<IChartApi["addLineSeries"]> | null>(null);
  const emaSeriesRef = useRef<ReturnType<IChartApi["addLineSeries"]> | null>(null);
  const htSeriesRef = useRef<ReturnType<IChartApi["addLineSeries"]> | null>(null);
  const [history, setHistory] = useState<BenchmarkHistoryPoint[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [chartInitialized, setChartInitialized] = useState(false);
  const [pluginScriptReady, setPluginScriptReady] = useState(false);
  const pluginRef = useRef<any>(null);

  useEffect(() => {
    if (window.__LIGHTWEIGHT_CHART_PLUGIN_LOADED) {
      setPluginScriptReady(true);
      return;
    }
    const script = document.createElement("script");
    script.src = "/plugins/lightweight-chart-plugin.js";
    script.async = true;
    script.onload = () => {
      window.__LIGHTWEIGHT_CHART_PLUGIN_LOADED = true;
      setPluginScriptReady(true);
    };
    document.body.appendChild(script);
    return () => {
      // keep script loaded for the lifetime of the app
    };
  }, []);

  useEffect(() => {
    if (!chartInitialized || !pluginScriptReady) return;
    if (pluginRef.current) return;
    const chart = chartRef.current;
    const series = priceSeriesRef.current;
    if (!chart || !series) return;
    const PluginCtor = window.LighweightChartPlugin;
    if (typeof PluginCtor !== "function") return;
    const plugin = new PluginCtor({
      chart,
      series,
      chartContainerId: "chartContainer",
      chartDivId: "chart",
      overlayCanvasId: "overlayCanvas",
      volumeprofile: { volumeProfileId: "overlayCanvasVP" },
      background: { pointerEvents: "none" },
    });
    plugin.initElement?.();
    plugin.initTooltip?.();
    plugin.boundRectOverlay?.();
    pluginRef.current = plugin;
  }, [chartInitialized, pluginScriptReady]);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return undefined;

    const chart = createChart(container, {
      layout: {
        background: { type: ColorType.Solid, color: "#0f111f" },
        textColor: "#94a3b8",
        fontFamily: "inherit",
      },
      grid: {
        vertLines: { color: "#1e2033" },
        horzLines: { color: "#1e2033" },
      },
      rightPriceScale: {
        borderColor: "#363a59",
        scaleMargins: { top: 0.05, bottom: 0.2 },
      },
      timeScale: {
        borderColor: "#363a59",
        timeVisible: true,
        secondsVisible: false,
        rightOffset: timeScaleRightOffset ?? DEFAULT_RIGHT_OFFSET,
        tickMarkFormatter: localTickMarkFormatter,
      },
      crosshair: {
        vertLine: { color: "#3d51ff", width: 1 },
        horzLine: { color: "#3d51ff", width: 1 },
      },
      width: Math.max(container.clientWidth, 300),
      height: 240,
    });

    chartRef.current = chart;
    priceSeriesRef.current = chart.addLineSeries({
      color: "#38bdf8",
      lineWidth: 2,
      title: "Price",
    });
    smaSeriesRef.current = chart.addLineSeries({
      color: "#facc15",
      lineWidth: 2,
      lineStyle: 2,
      title: `SMA(${SMA_LENGTH})`,
    });
    emaSeriesRef.current = chart.addLineSeries({
      color: "#a78bfa",
      lineWidth: 2,
      lineStyle: 2,
      title: `EMA(${EMA_LENGTH})`,
    });
    htSeriesRef.current = chart.addLineSeries({
      color: "#94a3b8",
      lineWidth: 2,
      title: "HalfTrend",
    });
    setChartInitialized(true);

    chart.timeScale().fitContent();

    const ro = new ResizeObserver(() => {
      chart.applyOptions({ width: Math.max(container.clientWidth, 300) });
    });
    ro.observe(container);

    return () => {
      ro.disconnect();
      chart.remove();
      chartRef.current = null;
      priceSeriesRef.current = null;
      smaSeriesRef.current = null;
      emaSeriesRef.current = null;
      htSeriesRef.current = null;
      setChartInitialized(false);
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    const { resolution: resStr, rangeSeconds, resolutionSeconds } = resolutionToParams(resolution ?? "1D");
    fetchPythBenchmarkHistory(symbol, {
      resolution: resStr,
      rangeSeconds,
      symbolOverride: tradingViewSymbol,
    })
      .then((points) => {
        if (!cancelled) {
          if (points.length >= SMA_LENGTH) {
            setHistory(points);
          } else {
            setHistory(generateFallbackData(symbol, resolutionSeconds));
          }
        }
      })
      .catch(() => {
        if (!cancelled) {
          setHistory(generateFallbackData(symbol, resolutionSeconds));
          setError(null);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [symbol, tradingViewSymbol, resolution]);

  const priceData = useMemo(
    () => history.map((p) => ({ time: p.time as UTCTimestamp, value: p.close })),
    [history]
  );
  const smaData = useMemo(() => calculateSMA(history, SMA_LENGTH), [history]);
  const emaData = useMemo(() => calculateEMA(history, EMA_LENGTH), [history]);
  const rsi14Data = useMemo(() => calculateRSI(history, RSI_LENGTH), [history]);
  const rsi28Data = useMemo(() => calculateRSI(history, 28), [history]);
  const momentumData = useMemo(() => calculateMomentum(history, MOMENTUM_LENGTH), [history]);
  const { adx: adxData, plusDI: plusDIData, minusDI: minusDIData } = useMemo(
    () => calculateADX(history, ADX_LENGTH),
    [history]
  );
  const tpoResult = useMemo(() => getTpoLevels(history), [history]);
  const latestPrice = priceData[priceData.length - 1]?.value;
  const footprintBin = useMemo(() => {
    const defaultBin = PRICE_BIN_DEFAULTS[symbol] ?? 1;
    if (!latestPrice || Number.isNaN(latestPrice)) return defaultBin;
    const candidate = latestPrice * 0.001;
    if (candidate < 0.01) return 0.01;
    if (candidate >= 1) return Number(candidate.toFixed(2));
    return Number(candidate.toFixed(4));
  }, [latestPrice, symbol]);
  const latestSma = smaData[smaData.length - 1]?.value;
  const latestEma = emaData[emaData.length - 1]?.value;
  const latestRsi = rsi14Data[rsi14Data.length - 1]?.value;
  const latestMomentum = momentumData[momentumData.length - 1]?.value;

  const smaDelta = latestPrice && latestSma ? ((latestSma - latestPrice) / latestPrice) * 100 : undefined;
  const emaDelta = latestPrice && latestEma ? ((latestEma - latestPrice) / latestPrice) * 100 : undefined;
  const rsiLabel =
    latestRsi == null ? "—" : latestRsi >= 70 ? "Overbought" : latestRsi <= 30 ? "Oversold" : "Neutral";
  const momentumLabel =
    latestMomentum == null ? "—" : latestMomentum >= 0 ? "Bullish" : "Bearish";


  useEffect(() => {
    const plugin = pluginRef.current;
    if (!plugin) return;
    plugin.volume_data = [];
    plugin.rectangles = [];

    if (tpoResult) {
      const startTime = history[0]?.time ?? Math.floor(Date.now() / 1000);
      const endTime = history[history.length - 1]?.time ?? startTime;
      const startLabel = formatPluginTime(startTime);
      const endLabel = formatPluginTime(endTime);
      tpoResult.histogram.forEach((bin) => {
        if (bin.count <= 0) return;
        plugin.addVolume(endLabel, bin.price, bin.count);
      });
      plugin.addRectangle(
        startLabel,
        tpoResult.val,
        endLabel,
        tpoResult.vah,
        "rgba(34,197,94,0.18)",
        true,
        "TPO Value Area",
        true
      );
    }

    plugin.scheduleRedraw();
  }, [history, tpoResult]);

  const halfTrendData = useMemo(
    () => calculateHalfTrend(history, HT_AMPLITUDE, HT_CHANNEL_DEV),
    [history]
  );

  const htLineData = useMemo(
    () =>
      halfTrendData.map((p) => ({ time: p.time as UTCTimestamp, value: p.value })),
    [halfTrendData]
  );

  const latestHT = halfTrendData[halfTrendData.length - 1]?.value;
  const legendItems = [
    { label: "Price", value: latestPrice, color: "#38bdf8" },
    { label: `EMA(${EMA_LENGTH})`, value: latestEma, color: "#a78bfa" },
    { label: `SMA(${SMA_LENGTH})`, value: latestSma, color: "#facc15" },
    { label: "HalfTrend", value: latestHT, color: "#94a3b8" },
  ];

  const lastUpdate = history[history.length - 1]
    ? new Date(history[history.length - 1].time * 1000).toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
      })
    : "—";

  useEffect(() => {
    if (!chartRef.current) return;
    priceSeriesRef.current?.setData(priceData);
    smaSeriesRef.current?.setData(smaData);
    emaSeriesRef.current?.setData(emaData);
    chartRef.current.timeScale().fitContent();
    chartRef.current.priceScale("right").applyOptions({ autoScale: true });
  }, [priceData, smaData, emaData]);

  useEffect(() => {
    if (!htSeriesRef.current || !htLineData.length) return;
    htSeriesRef.current.setData(htLineData);
  }, [htLineData]);

  useEffect(() => {
    if (!chartRef.current) return;
    chartRef.current.timeScale().applyOptions({
      rightOffset: timeScaleRightOffset ?? DEFAULT_RIGHT_OFFSET,
    });
  }, [timeScaleRightOffset]);

  useEffect(() => {
    if (!chartRef.current || !visibleLogicalRange) return;
    chartRef.current.timeScale().setVisibleLogicalRange({
      from: visibleLogicalRange.from,
      to: visibleLogicalRange.to,
    });
  }, [visibleLogicalRange]);

  return (
    <div className="mt-6 px-6 pb-6">
      <div className="bg-[#0f111f] rounded-2xl border border-[#363a59] p-5 shadow-xl shadow-black/20">
        <div className="flex items-center justify-between text-[11px] uppercase tracking-[0.4em] text-slate-500 mb-3">
          <span>Indicators</span>
          <span className="text-slate-400 text-[10px] normal-case tracking-normal">
            {symbol} · {resolution ?? "1D"} · {lastUpdate}
          </span>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-left text-sm mb-4">
          <div className="rounded-xl border border-[#363a59] bg-[#121421] p-3">
            <p className="text-[10px] uppercase text-slate-400 mb-1">SMA ({SMA_LENGTH})</p>
            <div className="text-lg font-semibold text-white">${latestSma?.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) ?? "—"}</div>
            <p className="text-[11px] text-slate-500">{formatPercent(smaDelta)} vs price</p>
          </div>
          <div className="rounded-xl border border-[#363a59] bg-[#121421] p-3">
            <p className="text-[10px] uppercase text-slate-400 mb-1">EMA ({EMA_LENGTH})</p>
            <div className="text-lg font-semibold text-white">${latestEma?.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) ?? "—"}</div>
            <p className="text-[11px] text-slate-500">{formatPercent(emaDelta)} vs price</p>
          </div>
          <div className="rounded-xl border border-[#363a59] bg-[#121421] p-3">
            <p className="text-[10px] uppercase text-slate-400 mb-1">RSI ({RSI_LENGTH})</p>
            <div className="text-lg font-semibold text-white">{latestRsi?.toFixed(1) ?? "—"}</div>
            <p className="text-[11px] text-slate-500">{rsiLabel}</p>
          </div>
          <div className="rounded-xl border border-[#363a59] bg-[#121421] p-3">
            <p className="text-[10px] uppercase text-slate-400 mb-1">Momentum ({MOMENTUM_LENGTH})</p>
            <div className="text-lg font-semibold text-white">{latestMomentum?.toFixed(2) ?? "—"}</div>
            <p className="text-[11px] text-slate-500">{momentumLabel}</p>
          </div>
        </div>
        <div className="relative min-h-[240px] w-full rounded-xl overflow-hidden border border-[#363a59] bg-[#0d0f18]">
          <div id="chartContainer" className="relative w-full h-[240px] min-w-[300px]">
            <div id="chart" ref={containerRef} className="w-full h-[240px]" />
            <canvas
              id="overlayCanvas"
              className="absolute inset-0 pointer-events-none"
              style={{ zIndex: -1 }}
            />
            <canvas
              id="overlayCanvasVP"
              className="absolute inset-0 pointer-events-none"
              style={{ zIndex: -2 }}
            />
          </div>
          <div className="absolute right-[0.5rem] top-4 hidden flex-col items-end gap-1 rounded-lg bg-black/30 px-3 py-2 text-right text-[11px] font-semibold text-white backdrop-blur sm:flex">
            {legendItems.map((item) => (
              <div key={item.label} className="flex items-center gap-1" style={{ letterSpacing: "-0.05em" }}>
                <span
                  className="block h-2.5 w-2.5 rounded-full"
                  style={{ background: item.color }}
                />
                <span className="text-slate-300">{item.label}</span>
                <span className="text-[13px] text-white">{item.value?.toFixed(2) ?? "—"}</span>
              </div>
            ))}
          </div>
          {loading && (
            <div className="absolute inset-0 flex items-center justify-center bg-[#0d0f18]/80 text-xs uppercase tracking-[0.3em] text-slate-400">
              Loading...
            </div>
          )}
          {error && (
            <div className="absolute inset-0 flex items-center justify-center px-6 text-center text-xs text-rose-400">
              {error}
            </div>
          )}
        </div>
        <div className="mt-4 flex flex-col gap-3">
          <MultiSeriesSubChart
            title="RSI Chart"
            seriesSets={[
              { label: "RSI(14)", color: "#38bdf8", data: rsi14Data },
              { label: "RSI(28)", color: "#22c55e", data: rsi28Data },
            ]}
            rightOffset={30}
            zones={[
              { value: 100, color: "#facc15", lineStyle: LineStyle.Dotted },
              { value: 70, color: "#fde047", lineStyle: LineStyle.Dashed },
              { value: 50, color: "#94a3b8", lineStyle: LineStyle.Dashed },
              { value: 30, color: "#38bdf8", lineStyle: LineStyle.Dashed },
              { value: 0, color: "#0ea5e9", lineStyle: LineStyle.Dotted },
            ]}
            zoneGradient="linear-gradient(to top, rgba(14,165,233,0.25) 0%, rgba(59,130,246,0.18) 30%, rgba(148,163,184,0.1) 50%, rgba(251,146,60,0.2) 80%, rgba(248,113,113,0.2) 100%)"
          />
          <MultiSeriesSubChart
            title="ADX Chart"
            seriesSets={[
              { label: `ADX(${ADX_LENGTH})`, color: "#a78bfa", data: adxData },
              { label: "+DI", color: "#22c55e", data: plusDIData },
              { label: "-DI", color: "#f87171", data: minusDIData },
            ]}
            rightOffset={30}
            zones={[
              { value: 100, color: "#facc15", lineStyle: LineStyle.Dotted },
              { value: 50, color: "#fde047", lineStyle: LineStyle.Dashed },
              { value: 25, color: "#94a3b8", lineStyle: LineStyle.Dashed },
              { value: 0, color: "#0ea5e9", lineStyle: LineStyle.Dotted },
            ]}
            zoneGradient="linear-gradient(to top, rgba(14,165,233,0.15) 0%, rgba(148,163,184,0.08) 25%, rgba(251,146,60,0.15) 50%, rgba(248,113,113,0.2) 100%)"
          />
          <IndicatorSubChart
            title={`Momentum (${MOMENTUM_LENGTH})`}
            legend="Momentum"
            series={momentumData}
            color="#0ea5e9"
            fullWidth
            rightOffset={6}
          />
          <FootprintHistoryChart
            polkadotSymbol={symbol}
            priceBin={footprintBin}
            lineColor={FOOTPRINT_LINE_COLOR}
            displayPrice={latestPrice}
            numBars={18}
            barSeconds={tvResolutionToSeconds(resolution ?? "1")}
            resolution={resolution ?? "1m"}
          />
        </div>
      </div>
    </div>
  );
}
