/**
 * BinanceBubbleChart – real-time crypto bubble heatmap powered by Binance APIs + D3 force.
 *
 * Architecture:
 *  - Data layer  : Binance REST (initial load) + WebSocket !miniTicker@arr (real-time)
 *  - Layout layer: d3-force simulation (gravity, collision) → each tick updates SVG attrs
 *  - Render layer: SVG drawn directly via D3 (bypasses React re-renders on every tick)
 *  - UI layer    : React for header, tooltip, controls, overlay
 */

import { useState, useEffect, useRef, useCallback } from "react";
import * as d3 from "d3";

// ─── Types ────────────────────────────────────────────────────────────────────
type Timeframe = "1H" | "4H" | "24H";
type SortMode  = "volume" | "change";

interface BubbleNode extends d3.SimulationNodeDatum {
  id: string;        // ticker, e.g. "BTC"
  fullId: string;    // full Binance symbol, e.g. "BTCUSDT"
  volume: number;    // quote volume in USDT
  priceChange: number; // % price change in selected timeframe
  delta: number;     // net buy-sell flow (positive = more buyers)
  price: number;
  radius: number;    // computed from volume
  color: string;     // computed from delta
  borderColor: string;
}

interface TooltipState {
  visible: boolean;
  x: number;
  y: number;
  node: BubbleNode | null;
}

// ─── Constants ───────────────────────────────────────────────────────────────
const REST_BASE  = "https://api.binance.com/api/v3";
const WS_URL     = "wss://stream.binance.com:9443/ws/!miniTicker@arr";
const TOP_N      = 80;
const MIN_RADIUS = 24;
const MAX_RADIUS = 100;

// ─── Color logic (delta → color intensity) ───────────────────────────────────
function bubbleColor(delta: number, maxAbs: number): string {
  if (maxAbs === 0) return "#2a2d3e";
  const intensity = Math.min(Math.abs(delta) / maxAbs, 1);
  if (Math.abs(delta) < maxAbs * 0.04) return "#2a2d3e"; // near-neutral → dark grey
  if (delta > 0) {
    // dim teal → bright teal
    const r = Math.round(d3.interpolateNumber(20, 38)(intensity));
    const g = Math.round(d3.interpolateNumber(55, 166)(intensity));
    const b = Math.round(d3.interpolateNumber(55, 154)(intensity));
    return `rgb(${r},${g},${b})`;
  } else {
    // dim red → bright red
    const r = Math.round(d3.interpolateNumber(55, 239)(intensity));
    const g = Math.round(d3.interpolateNumber(25, 83)(intensity));
    const b = Math.round(d3.interpolateNumber(25, 80)(intensity));
    return `rgb(${r},${g},${b})`;
  }
}

function bubbleBorderColor(delta: number): string {
  if (delta > 0) return "rgba(38,166,154,0.55)";
  if (delta < 0) return "rgba(239,83,80,0.55)";
  return "rgba(80,80,100,0.4)";
}

// ─── Radius scale (sqrt so area ∝ volume) ────────────────────────────────────
function makeRadiusScale(volumes: number[]) {
  const max = d3.max(volumes) ?? 1;
  return d3.scaleSqrt().domain([0, max]).range([MIN_RADIUS, MAX_RADIUS]).clamp(true);
}

// ─── Volume formatter ─────────────────────────────────────────────────────────
function fmtVol(v: number): string {
  if (v >= 1e9) return `$${(v / 1e9).toFixed(1)}B`;
  if (v >= 1e6) return `$${(v / 1e6).toFixed(1)}M`;
  if (v >= 1e3) return `$${(v / 1e3).toFixed(0)}K`;
  return `$${v.toFixed(0)}`;
}

// ─── Binance REST fetchers ─────────────────────────────────────────────────────
async function fetch24H(): Promise<BubbleNode[]> {
  const res = await fetch(`${REST_BASE}/ticker/24hr`);
  if (!res.ok) throw new Error("Binance API unavailable");
  const raw: any[] = await res.json();

  const filtered = raw
    .filter(t =>
      t.symbol.endsWith("USDT") &&
      !t.symbol.includes("UPUSDT") &&
      !t.symbol.includes("DOWNUSDT") &&
      !t.symbol.includes("BULLUSDT") &&
      !t.symbol.includes("BEARUSDT") &&
      parseFloat(t.quoteVolume) > 0
    )
    .sort((a, b) => parseFloat(b.quoteVolume) - parseFloat(a.quoteVolume))
    .slice(0, TOP_N);

  const volumes = filtered.map(t => parseFloat(t.quoteVolume));
  const rScale  = makeRadiusScale(volumes);

  // For 24H we approximate delta = volume * (priceChangePct / 100)
  // Positive % = more buyers drove price up = positive delta
  const deltas = filtered.map(t =>
    parseFloat(t.quoteVolume) * parseFloat(t.priceChangePercent) / 100
  );
  const maxAbs = d3.max(deltas.map(Math.abs)) ?? 1;

  return filtered.map((t, i) => ({
    id:          t.symbol.replace("USDT", ""),
    fullId:      t.symbol,
    volume:      parseFloat(t.quoteVolume),
    priceChange: parseFloat(t.priceChangePercent),
    delta:       deltas[i],
    price:       parseFloat(t.lastPrice),
    radius:      rScale(parseFloat(t.quoteVolume)),
    color:       bubbleColor(deltas[i], maxAbs),
    borderColor: bubbleBorderColor(deltas[i]),
  }));
}

async function fetchKlines(interval: "1h" | "4h"): Promise<BubbleNode[]> {
  // Step 1 – get top 60 symbols by 24h volume
  const tickerRes = await fetch(`${REST_BASE}/ticker/24hr`);
  const allTickers: any[] = await tickerRes.json();

  const topSymbols = allTickers
    .filter(t =>
      t.symbol.endsWith("USDT") &&
      !t.symbol.includes("UPUSDT") &&
      !t.symbol.includes("DOWNUSDT") &&
      parseFloat(t.quoteVolume) > 0
    )
    .sort((a, b) => parseFloat(b.quoteVolume) - parseFloat(a.quoteVolume))
    .slice(0, 60)
    .map(t => t.symbol);

  // Step 2 – fetch klines in parallel (browser handles concurrency)
  const settled = await Promise.allSettled(
    topSymbols.map(sym =>
      fetch(`${REST_BASE}/klines?symbol=${sym}&interval=${interval}&limit=1`)
        .then(r => r.json())
        .then((k: any[]) => {
          if (!k?.[0]) return null;
          const open       = parseFloat(k[0][1]);
          const close      = parseFloat(k[0][4]);
          const quoteVol   = parseFloat(k[0][7]);   // total quoteAsset traded
          const takerBuy   = parseFloat(k[0][10]);  // taker buy quoteAsset volume
          const change     = open > 0 ? (close - open) / open * 100 : 0;
          // Real delta: taker buy (aggressive buyers) minus taker sell
          const delta      = 2 * takerBuy - quoteVol;
          return { symbol: sym, volume: quoteVol, priceChange: change, delta, price: close };
        })
    )
  );

  const valid = settled
    .filter((r): r is PromiseFulfilledResult<any> => r.status === "fulfilled" && r.value !== null)
    .map(r => r.value)
    .sort((a, b) => b.volume - a.volume);

  const rScale  = makeRadiusScale(valid.map((d: any) => d.volume));
  const maxAbs  = d3.max(valid.map((d: any) => Math.abs(d.delta))) ?? 1;

  return valid.map((d: any) => ({
    id:          d.symbol.replace("USDT", ""),
    fullId:      d.symbol,
    volume:      d.volume,
    priceChange: d.priceChange,
    delta:       d.delta,
    price:       d.price,
    radius:      rScale(d.volume),
    color:       bubbleColor(d.delta, maxAbs),
    borderColor: bubbleBorderColor(d.delta),
  }));
}

// ─── Main Component ───────────────────────────────────────────────────────────
export default function BinanceBubbleChart() {
  const [open, setOpen]         = useState(false);
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState("");
  const [timeframe, setTimeframe] = useState<Timeframe>("24H");
  const [sortMode, setSortMode] = useState<SortMode>("volume");
  const [search, setSearch]     = useState("");
  const [wsLive, setWsLive]     = useState(false);
  const [nodeCount, setNodeCount] = useState(0);
  const [tooltip, setTooltip]   = useState<TooltipState>({ visible: false, x: 0, y: 0, node: null });

  const svgRef      = useRef<SVGSVGElement>(null);
  const simRef      = useRef<d3.Simulation<BubbleNode, undefined> | null>(null);
  const nodesRef    = useRef<BubbleNode[]>([]);
  const wsRef       = useRef<WebSocket | null>(null);
  const batchTimer  = useRef<ReturnType<typeof setTimeout>>();
  const [dims, setDims] = useState({ w: 0, h: 0 });

  // Window size
  useEffect(() => {
    const upd = () => setDims({ w: window.innerWidth, h: window.innerHeight });
    upd();
    window.addEventListener("resize", upd);
    return () => window.removeEventListener("resize", upd);
  }, []);

  // Cleanup when overlay closes
  useEffect(() => {
    if (!open) {
      simRef.current?.stop();
      wsRef.current?.close();
      wsRef.current = null;
      setWsLive(false);
    }
  }, [open]);

  // Escape key
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === "Escape") setOpen(false); };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, []);

  // ── D3 draw/init ────────────────────────────────────────────────────────────
  const initD3 = useCallback((nodes: BubbleNode[]) => {
    const svg = d3.select(svgRef.current!);
    svg.selectAll("*").remove();

    // Gradient defs (radial highlight per bubble)
    const defs = svg.append("defs");
    nodes.forEach(n => {
      const grad = defs.append("radialGradient")
        .attr("id", `grad-${n.id}`)
        .attr("cx", "35%").attr("cy", "35%").attr("r", "60%");
      grad.append("stop").attr("offset", "0%").attr("stop-color", "rgba(255,255,255,0.18)");
      grad.append("stop").attr("offset", "100%").attr("stop-color", "rgba(0,0,0,0)");
    });

    // One <g> per bubble
    const g = svg.selectAll<SVGGElement, BubbleNode>("g.bubble")
      .data(nodes, d => d.id)
      .join("g")
      .attr("class", "bubble")
      .style("cursor", "pointer");

    // Outer glow ring
    g.append("circle")
      .attr("class", "glow")
      .attr("r", d => d.radius + 4)
      .attr("fill", "none")
      .attr("stroke", d => d.borderColor)
      .attr("stroke-width", 1.5)
      .attr("opacity", 0.6);

    // Main filled circle
    g.append("circle")
      .attr("class", "body")
      .attr("r", d => d.radius)
      .attr("fill", d => d.color)
      .attr("stroke", d => d.borderColor)
      .attr("stroke-width", 1);

    // Inner highlight (gives 3D depth)
    g.append("circle")
      .attr("class", "highlight")
      .attr("r", d => d.radius)
      .attr("fill", d => `url(#grad-${d.id})`)
      .attr("pointer-events", "none");

    // Ticker label
    g.append("text")
      .attr("class", "label-ticker")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "auto")
      .attr("y", d => d.radius > 35 ? -4 : 4)
      .attr("fill", "white")
      .attr("font-weight", "700")
      .attr("font-family", "'JetBrains Mono', 'Courier New', monospace")
      .style("font-size", d => `${Math.max(9, Math.min(d.radius * 0.36, 22))}px`)
      .style("pointer-events", "none")
      .text(d => d.id);

    // % change label (only if bubble is big enough)
    g.append("text")
      .attr("class", "label-change")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "auto")
      .attr("y", d => d.radius > 35 ? 14 : 40) // push off-screen if bubble too small
      .attr("fill", d => d.priceChange >= 0 ? "#80cbc4" : "#ef9a9a")
      .attr("font-family", "'JetBrains Mono', 'Courier New', monospace")
      .style("font-size", d => `${Math.max(7, Math.min(d.radius * 0.24, 13))}px`)
      .style("pointer-events", "none")
      .text(d => `${d.priceChange >= 0 ? "+" : ""}${d.priceChange.toFixed(2)}%`);

    // Mouse events
    g.on("mouseenter", function (event, d) {
        d3.select(this).select(".body").transition().duration(120).attr("r", d.radius * 1.12);
        d3.select(this).select(".glow").transition().duration(120).attr("r", d.radius * 1.12 + 4).attr("opacity", 1);
        setTooltip({ visible: true, x: event.clientX, y: event.clientY, node: d });
      })
      .on("mousemove", function (event) {
        setTooltip(prev => ({ ...prev, x: event.clientX, y: event.clientY }));
      })
      .on("mouseleave", function (_event, d) {
        d3.select(this).select(".body").transition().duration(120).attr("r", d.radius);
        d3.select(this).select(".glow").transition().duration(120).attr("r", d.radius + 4).attr("opacity", 0.6);
        setTooltip(prev => ({ ...prev, visible: false }));
      })
      .on("click", (_event, d) => {
        window.open(`https://www.binance.com/en/trade/${d.id}_USDT`, "_blank");
      });

    // ── Force simulation ─────────────────────────────────────────────────────
    // - forceCenter: gentle pull toward screen center
    // - forceManyBody: mild repulsion so large bubbles don't stack
    // - forceCollide: prevents overlap, respects each bubble's radius
    const sim = d3.forceSimulation<BubbleNode>(nodes)
      .force("center",  d3.forceCenter(dims.w / 2, dims.h / 2 - 30).strength(0.06))
      .force("charge",  d3.forceManyBody<BubbleNode>().strength(-8))
      .force("collide", d3.forceCollide<BubbleNode>(d => d.radius + 3).strength(0.85).iterations(4))
      .alphaDecay(0.018)
      .velocityDecay(0.35)
      .on("tick", () => {
        // Direct DOM update — no React re-render on each tick
        g.attr("transform", d => `translate(${d.x ?? 0},${d.y ?? 0})`);
      });

    simRef.current = sim;
  }, [dims.w, dims.h]);

  // ── WebSocket real-time updates ──────────────────────────────────────────────
  const connectWS = useCallback((maxAbs: number, rScale: (v: number) => number) => {
    wsRef.current?.close();
    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;

    ws.onopen  = () => setWsLive(true);
    ws.onclose = () => setWsLive(false);
    ws.onerror = () => setWsLive(false);

    ws.onmessage = (ev) => {
      try {
        const tickers: any[] = JSON.parse(ev.data);
        if (!Array.isArray(tickers)) return;

        const lookup = new Map(nodesRef.current.map(n => [n.fullId, n]));
        let changed = false;

        tickers.forEach(t => {
          const node = lookup.get(t.s);
          if (!node) return;
          const c = parseFloat(t.c), o = parseFloat(t.o), q = parseFloat(t.q);
          node.priceChange = o > 0 ? (c - o) / o * 100 : 0;
          node.volume      = q;
          node.delta       = q * node.priceChange / 100;
          node.price       = c;
          node.radius      = rScale(q);
          node.color       = bubbleColor(node.delta, maxAbs);
          node.borderColor = bubbleBorderColor(node.delta);
          changed = true;
        });

        if (!changed || !svgRef.current) return;

        // Batch DOM updates every 800 ms to prevent thrashing
        clearTimeout(batchTimer.current);
        batchTimer.current = setTimeout(() => {
          if (!svgRef.current) return;
          const svg = d3.select(svgRef.current);
          nodesRef.current.forEach(node => {
            const grp = svg.selectAll<SVGGElement, BubbleNode>("g.bubble")
              .filter(d => d.id === node.id);
            grp.select(".body").attr("fill", node.color).attr("stroke", node.borderColor);
            grp.select(".glow").attr("stroke", node.borderColor);
            grp.select(".label-change")
              .attr("fill", node.priceChange >= 0 ? "#80cbc4" : "#ef9a9a")
              .text(`${node.priceChange >= 0 ? "+" : ""}${node.priceChange.toFixed(2)}%`);
          });

          // Gentle nudge so collision respects updated radii
          simRef.current?.force("collide",
            d3.forceCollide<BubbleNode>(d => d.radius + 3).strength(0.85).iterations(4)
          );
          simRef.current?.alpha(0.15).restart();
        }, 800);
      } catch { /* ignore */ }
    };
  }, []);

  // ── Main fetch + init effect ────────────────────────────────────────────────
  useEffect(() => {
    if (!open || !svgRef.current || dims.w === 0) return;

    setLoading(true);
    setError("");
    setTooltip({ visible: false, x: 0, y: 0, node: null });

    const controller = new AbortController();

    (async () => {
      try {
        let nodes: BubbleNode[];
        if (timeframe === "24H") {
          nodes = await fetch24H();
        } else {
          nodes = await fetchKlines(timeframe === "1H" ? "1h" : "4h");
        }

        if (controller.signal.aborted) return;

        // Apply sort
        if (sortMode === "change") {
          nodes.sort((a, b) => Math.abs(b.priceChange) - Math.abs(a.priceChange));
        }

        nodesRef.current = nodes;
        setNodeCount(nodes.length);
        initD3(nodes);
        setLoading(false);

        const volumes  = nodes.map(n => n.volume);
        const rScale   = makeRadiusScale(volumes);
        const allDeltas = nodes.map(n => Math.abs(n.delta));
        const maxAbs   = d3.max(allDeltas) ?? 1;
        connectWS(maxAbs, v => rScale(v));
      } catch (e) {
        if (!controller.signal.aborted) {
          setError("Could not reach Binance API. Check your internet connection.");
          setLoading(false);
        }
      }
    })();

    return () => {
      controller.abort();
      simRef.current?.stop();
      wsRef.current?.close();
      clearTimeout(batchTimer.current);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, timeframe, sortMode, dims.w, dims.h]);

  // ── Search filter: fade non-matching bubbles ────────────────────────────────
  useEffect(() => {
    if (!svgRef.current) return;
    const q = search.toLowerCase().trim();
    d3.select(svgRef.current)
      .selectAll<SVGGElement, BubbleNode>("g.bubble")
      .transition().duration(200)
      .style("opacity", d => (!q || d.id.toLowerCase().includes(q)) ? 1 : 0.1);
  }, [search]);

  // ── Tooltip positioning ─────────────────────────────────────────────────────
  const TT_W = 210;
  const ttLeft = tooltip.x + 14 + TT_W > window.innerWidth ? tooltip.x - TT_W - 10 : tooltip.x + 14;
  const ttTop  = Math.min(tooltip.y - 10, window.innerHeight - 220);

  // ── JSX ─────────────────────────────────────────────────────────────────────
  return (
    <>
      {/* ── Left-edge trigger button (below the "Chart" indicators button) ── */}
      <button
        onClick={() => setOpen(v => !v)}
        className="fixed left-0 z-[200] flex flex-col items-center justify-center gap-1.5 transition-all duration-200"
        title="Bubble Chart – Binance flow map"
        style={{
          top: "63%",
          transform: "translateY(-50%)",
          width: 28,
          paddingTop: 14,
          paddingBottom: 14,
          borderRadius: "0 10px 10px 0",
          background: open
            ? "linear-gradient(180deg,#e6007a 0%,#b3005f 100%)"
            : "linear-gradient(180deg,#1a1d2e 0%,#141625 100%)",
          border: "1px solid",
          borderLeft: "none",
          borderColor: open ? "#e6007a" : "#363a59",
          boxShadow: open ? "2px 0 16px rgba(230,0,122,0.4)" : "2px 0 8px rgba(0,0,0,0.4)",
        }}
      >
        {/* Bubble icon */}
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
          <circle cx="12" cy="12" r="5" fill={open ? "#fff" : "#e6007a"} opacity="0.9" />
          <circle cx="5"  cy="7"  r="3" fill={open ? "#fce7f3" : "#7c3aed"} opacity="0.7" />
          <circle cx="19" cy="7"  r="2" fill={open ? "#fce7f3" : "#22d3ee"} opacity="0.7" />
          <circle cx="5"  cy="17" r="2" fill={open ? "#fce7f3" : "#4ade80"} opacity="0.7" />
          <circle cx="19" cy="17" r="3" fill={open ? "#fce7f3" : "#f97316"} opacity="0.7" />
        </svg>
        <span
          className="select-none font-semibold"
          style={{
            writingMode: "vertical-rl",
            transform: "rotate(180deg)",
            fontSize: 8,
            letterSpacing: "0.18em",
            textTransform: "uppercase",
            color: open ? "#fce7f3" : "#475569",
          }}
        >
          Bubble
        </span>
      </button>

      {/* ── Full-screen overlay ─────────────────────────────────────────────── */}
      {open && (
        <div
          className="fixed inset-0 z-[170] overflow-hidden"
          style={{ background: "#0b0c14" }}
        >
          {/* ── Header bar ─────────────────────────────────────────────────── */}
          <div
            className="absolute top-0 left-0 right-0 z-10 flex items-center justify-between px-5 py-2.5 gap-3"
            style={{
              background: "linear-gradient(180deg,rgba(8,9,18,0.98) 0%,transparent 100%)",
              borderBottom: "1px solid rgba(54,58,89,0.4)",
            }}
          >
            {/* Title */}
            <div className="flex items-center gap-2.5 shrink-0">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="5" fill="#e6007a"/>
                <circle cx="5"  cy="7"  r="3" fill="#7c3aed"/>
                <circle cx="19" cy="7"  r="2" fill="#22d3ee"/>
                <circle cx="5"  cy="17" r="2" fill="#4ade80"/>
                <circle cx="19" cy="17" r="3" fill="#f97316"/>
              </svg>
              <div>
                <h1 className="text-white font-bold text-sm tracking-wide leading-none">
                  Binance Bubble Chart
                </h1>
                <p className="text-slate-600 text-[9px] mt-0.5">
                  {nodeCount} pairs · Size = Volume · Color = Buy/Sell flow
                  {wsLive && <span className="ml-1.5 text-emerald-500">● LIVE</span>}
                  {!wsLive && <span className="ml-1.5 text-slate-600">○ connecting…</span>}
                </p>
              </div>
            </div>

            {/* Controls group */}
            <div className="flex items-center gap-2 flex-wrap">

              {/* Timeframe buttons */}
              <div className="flex items-center gap-1 rounded-lg border border-[#363a59] p-0.5">
                {(["1H", "4H", "24H"] as Timeframe[]).map(tf => (
                  <button
                    key={tf}
                    onClick={() => setTimeframe(tf)}
                    className="px-2.5 py-1 rounded-md text-[10px] font-bold transition"
                    style={{
                      background: timeframe === tf ? "#e6007a" : "transparent",
                      color: timeframe === tf ? "#fff" : "#64748b",
                    }}
                  >
                    {tf}
                  </button>
                ))}
              </div>

              {/* Sort buttons */}
              <div className="flex items-center gap-1 rounded-lg border border-[#363a59] p-0.5">
                {(["volume", "change"] as SortMode[]).map(m => (
                  <button
                    key={m}
                    onClick={() => setSortMode(m)}
                    className="px-2.5 py-1 rounded-md text-[10px] font-semibold capitalize transition"
                    style={{
                      background: sortMode === m ? "#3d51ff" : "transparent",
                      color: sortMode === m ? "#fff" : "#64748b",
                    }}
                  >
                    {m === "volume" ? "Volume" : "% Change"}
                  </button>
                ))}
              </div>

              {/* Search */}
              <div className="relative">
                <input
                  type="text"
                  value={search}
                  onChange={e => setSearch(e.target.value)}
                  placeholder="Search BTC…"
                  className="h-7 rounded-lg border border-[#363a59] bg-[#12152a] px-2.5 pr-7 text-[10px] text-white placeholder-slate-600 outline-none focus:border-pink-500 transition"
                  style={{ width: 110 }}
                />
                {search && (
                  <button
                    onClick={() => setSearch("")}
                    className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-500 hover:text-white transition"
                  >
                    <svg width="9" height="9" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
                      <path d="M1 1l8 8M9 1L1 9"/>
                    </svg>
                  </button>
                )}
              </div>

              {/* Color legend */}
              <div className="hidden md:flex items-center gap-3 text-[9px] text-slate-500">
                <div className="flex items-center gap-1">
                  <span className="h-2.5 w-2.5 rounded-full" style={{ background: "#26a69a" }}/>
                  Net Buyers
                </div>
                <div className="flex items-center gap-1">
                  <span className="h-2.5 w-2.5 rounded-full" style={{ background: "#2a2d3e" }}/>
                  Neutral
                </div>
                <div className="flex items-center gap-1">
                  <span className="h-2.5 w-2.5 rounded-full" style={{ background: "#ef5350" }}/>
                  Net Sellers
                </div>
              </div>

              {/* Binance link */}
              <a
                href="https://www.binance.com/en/markets/overview"
                target="_blank"
                rel="noopener noreferrer"
                className="hidden lg:flex items-center gap-1 text-[9px] text-slate-600 hover:text-slate-400 transition"
              >
                Binance Markets ↗
              </a>

              {/* Close */}
              <button
                onClick={() => setOpen(false)}
                className="flex h-8 w-8 items-center justify-center rounded-xl border border-[#363a59] text-slate-400 hover:text-white hover:bg-white/10 transition"
                title="Close (Esc)"
              >
                <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                  <path d="M1 1l12 12M13 1L1 13"/>
                </svg>
              </button>
            </div>
          </div>

          {/* ── Loading overlay ─────────────────────────────────────────────── */}
          {loading && (
            <div className="absolute inset-0 z-20 flex flex-col items-center justify-center gap-4">
              <div className="h-14 w-14 rounded-full border-4 border-pink-500/30 border-t-pink-500 animate-spin" />
              <p className="text-slate-500 text-sm">
                {timeframe !== "24H" ? `Fetching ${timeframe} klines for top 60 pairs…` : "Fetching Binance 24H data…"}
              </p>
            </div>
          )}

          {/* ── Error state ─────────────────────────────────────────────────── */}
          {error && !loading && (
            <div className="absolute inset-0 z-20 flex flex-col items-center justify-center gap-3">
              <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#ef5350" strokeWidth="1.5" strokeLinecap="round">
                <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><circle cx="12" cy="16" r="0.5" fill="#ef5350"/>
              </svg>
              <p className="text-slate-400 text-sm">{error}</p>
              <button
                onClick={() => { setError(""); setLoading(true); setOpen(false); setTimeout(() => setOpen(true), 100); }}
                className="px-4 py-2 rounded-lg bg-pink-600 hover:bg-pink-500 text-white text-xs font-semibold transition"
              >
                Retry
              </button>
            </div>
          )}

          {/* ── SVG canvas ──────────────────────────────────────────────────── */}
          <svg
            ref={svgRef}
            width={dims.w}
            height={dims.h}
            className="absolute inset-0"
            style={{ opacity: loading ? 0 : 1, transition: "opacity 0.4s" }}
          />

          {/* ── Tooltip ─────────────────────────────────────────────────────── */}
          {tooltip.visible && tooltip.node && (
            <div
              className="pointer-events-none fixed z-30 rounded-xl border border-[#363a59] bg-[#0a0c1a]/97 px-3.5 py-3 shadow-2xl backdrop-blur-sm"
              style={{
                left: ttLeft,
                top:  ttTop,
                width: TT_W,
                boxShadow: "0 8px 30px rgba(0,0,0,0.8), 0 0 0 1px rgba(230,0,122,0.2)",
              }}
            >
              {/* Header row */}
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <span
                    className="h-3 w-3 rounded-full shrink-0"
                    style={{ background: tooltip.node.color, boxShadow: `0 0 8px ${tooltip.node.color}` }}
                  />
                  <p className="text-white font-bold text-sm">{tooltip.node.id}<span className="text-slate-500 font-normal text-xs">/USDT</span></p>
                </div>
                <span
                  className="text-xs font-bold"
                  style={{ color: tooltip.node.priceChange >= 0 ? "#4caf50" : "#ef5350" }}
                >
                  {tooltip.node.priceChange >= 0 ? "▲" : "▼"} {Math.abs(tooltip.node.priceChange).toFixed(2)}%
                </span>
              </div>

              {/* Stats grid */}
              <div className="grid grid-cols-2 gap-x-3 gap-y-1.5 text-[10px]">
                <div>
                  <p className="text-slate-600">Price</p>
                  <p className="text-white font-mono font-semibold">${tooltip.node.price.toLocaleString(undefined, { maximumFractionDigits: 4 })}</p>
                </div>
                <div>
                  <p className="text-slate-600">{timeframe} Volume</p>
                  <p className="text-white font-mono font-semibold">{fmtVol(tooltip.node.volume)}</p>
                </div>
                <div>
                  <p className="text-slate-600">Net Flow (Δ)</p>
                  <p className="font-mono font-semibold" style={{ color: tooltip.node.delta >= 0 ? "#4caf50" : "#ef5350" }}>
                    {tooltip.node.delta >= 0 ? "+" : ""}{fmtVol(Math.abs(tooltip.node.delta))}
                  </p>
                </div>
                <div>
                  <p className="text-slate-600">Signal</p>
                  <p className="font-semibold" style={{ color: tooltip.node.delta >= 0 ? "#26a69a" : "#ef5350" }}>
                    {Math.abs(tooltip.node.priceChange) < 0.5 ? "Neutral" : tooltip.node.priceChange >= 0 ? "Bullish" : "Bearish"}
                  </p>
                </div>
              </div>

              <p className="text-[9px] text-slate-700 mt-2 text-center italic">Click to open on Binance ↗</p>
            </div>
          )}

          {/* Bottom hint */}
          <div
            className="absolute bottom-3 left-1/2 text-[9px] text-slate-700 text-center select-none"
            style={{ transform: "translateX(-50%)" }}
          >
            Bubble size = {timeframe} volume · Color intensity = buy/sell flow · Click any bubble to trade on Binance
          </div>
        </div>
      )}
    </>
  );
}
