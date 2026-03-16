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

// ─── Stockmap-style trading color palette ─────────────────────────────────────
// Buyers  : deep forest green → vivid bright green  #4caf50
// Sellers : deep blood red    → vivid bright red     #f44336
// Neutral : dark slate                               #1e2128
const GREEN_DIM    = "#0b1f0b";
const GREEN_BRIGHT = "#4caf50";
const RED_DIM      = "#1f0b0b";
const RED_BRIGHT   = "#f44336";
const NEUTRAL_COL  = "#1e2128";

function bubbleColor(delta: number, maxAbs: number): string {
  if (maxAbs === 0 || Math.abs(delta) < maxAbs * 0.03) return NEUTRAL_COL;
  const t = Math.pow(Math.min(Math.abs(delta) / maxAbs, 1), 0.6);
  return delta > 0
    ? d3.interpolateRgb(GREEN_DIM, GREEN_BRIGHT)(t)
    : d3.interpolateRgb(RED_DIM,   RED_BRIGHT)(t);
}

function bubbleBorderColor(delta: number, maxAbs: number): string {
  if (maxAbs === 0 || Math.abs(delta) < maxAbs * 0.03) return "rgba(50,55,70,0.5)";
  const t  = Math.min(Math.abs(delta) / maxAbs, 1);
  const al = (0.45 + t * 0.45).toFixed(2);   // always fairly visible ring
  return delta > 0 ? `rgba(102,187,106,${al})` : `rgba(239,83,80,${al})`;
}

// Neon glow: two stacked drop-shadows — tight bright inner + wide soft halo
// Intensity scales with |delta| so dominant movers glow the strongest
function bubbleGlowFilter(delta: number, maxAbs: number): string {
  if (maxAbs === 0 || Math.abs(delta) < maxAbs * 0.04) return "none";
  const t      = Math.min(Math.abs(delta) / maxAbs, 1);
  const inner  = Math.round(2 + t * 6);     // tight core  2 → 8 px
  const outer  = Math.round(8 + t * 14);    // wide halo   8 → 22 px
  const alIn   = (0.55 + t * 0.40).toFixed(2);  // 0.55 → 0.95
  const alOut  = (0.12 + t * 0.20).toFixed(2);  // 0.12 → 0.32
  if (delta > 0) {
    return `drop-shadow(0 0 ${inner}px rgba(76,175,80,${alIn})) ` +
           `drop-shadow(0 0 ${outer}px rgba(76,175,80,${alOut}))`;
  }
  return `drop-shadow(0 0 ${inner}px rgba(244,67,54,${alIn})) ` +
         `drop-shadow(0 0 ${outer}px rgba(244,67,54,${alOut}))`;
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
    borderColor: bubbleBorderColor(deltas[i], maxAbs),
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
    borderColor: bubbleBorderColor(d.delta, maxAbs),
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

  // ── D3 draw/init (Stockmap-style: dense pack, 3-line text, green/red) ────────
  const initD3 = useCallback((nodes: BubbleNode[]) => {
    const svg = d3.select(svgRef.current!);
    svg.selectAll("*").remove();

    const maxAbsDelta = d3.max(nodes.map(n => Math.abs(n.delta))) ?? 1;
    const FONT = "'Inter','SF Pro Text',-apple-system,BlinkMacSystemFont,sans-serif";

    const defs = svg.append("defs");

    // ── CSS: smooth radius/fill transitions + text-shadow for all labels ─────
    // CSS transitions on SVG attributes are supported in all modern browsers.
    // cubic-bezier spring gives a slight overshoot bounce when radius changes.
    defs.append("style").text(`
      .bubble .body,
      .bubble .ring,
      .bubble .shine,
      .bubble .glass,
      .bubble .vignette {
        transition: r 0.48s cubic-bezier(0.34,1.56,0.64,1);
      }
      .bubble .body {
        transition: r 0.48s cubic-bezier(0.34,1.56,0.64,1),
                    fill 0.5s ease,
                    stroke 0.5s ease;
      }
      .bubble text {
        filter: drop-shadow(0 1px 3px rgba(0,0,0,0.92))
                drop-shadow(0 0  6px rgba(0,0,0,0.6));
        font-family: ${FONT};
      }
    `);

    // ── Background grid pattern (cyberpunk digital space feel) ───────────────
    const gridPat = defs.append("pattern")
      .attr("id",           "bg-grid")
      .attr("width",        "44")
      .attr("height",       "44")
      .attr("patternUnits", "userSpaceOnUse");
    // Horizontal line
    gridPat.append("line")
      .attr("x1", "0").attr("y1", "44").attr("x2", "44").attr("y2", "44")
      .attr("stroke", "rgba(255,255,255,0.035)").attr("stroke-width", "0.5");
    // Vertical line
    gridPat.append("line")
      .attr("x1", "44").attr("y1", "0").attr("x2", "44").attr("y2", "44")
      .attr("stroke", "rgba(255,255,255,0.035)").attr("stroke-width", "0.5");

    // Paint the grid before any bubble (pointer-events none so it doesn't block)
    svg.append("rect")
      .attr("width",  dims.w)
      .attr("height", dims.h)
      .attr("fill",   "url(#bg-grid)")
      .attr("pointer-events", "none");

    // ── Per-bubble fill gradients: vivid bright center → deep dark edge ───────
    // 3-stop radial: very bright at top-left (light) → base color → near-black edge
    nodes.forEach(n => {
      const base    = d3.color(n.color) ?? d3.rgb(30, 33, 40);
      const lighter = (base as d3.RGBColor).brighter(1.1).formatRgb();  // vivid highlight
      const darker  = (base as d3.RGBColor).darker(2.2).formatRgb();    // deep shadow edge

      const fg = defs.append("radialGradient")
        .attr("id", `fill-${n.id}`)
        .attr("cx", "40%").attr("cy", "36%").attr("r", "70%");
      fg.append("stop").attr("offset",  "0%").attr("stop-color", lighter).attr("stop-opacity", "1");
      fg.append("stop").attr("offset", "45%").attr("stop-color", n.color).attr("stop-opacity", "1");
      fg.append("stop").attr("offset","100%").attr("stop-color", darker).attr("stop-opacity", "1");
    });

    // Shared specular highlight (white lens-flare applied on top of every bubble)
    const sg = defs.append("radialGradient").attr("id", "shine-shared")
      .attr("cx", "30%").attr("cy", "26%").attr("r", "45%");
    sg.append("stop").attr("offset",  "0%").attr("stop-color", "rgba(255,255,255,0.45)");
    sg.append("stop").attr("offset", "50%").attr("stop-color", "rgba(255,255,255,0.05)");
    sg.append("stop").attr("offset","100%").attr("stop-color", "rgba(255,255,255,0)");

    // Shared vignette (edge darkening)
    const vg = defs.append("radialGradient").attr("id", "vignette-shared")
      .attr("cx", "50%").attr("cy", "50%").attr("r", "50%");
    vg.append("stop").attr("offset", "45%").attr("stop-color", "rgba(0,0,0,0)");
    vg.append("stop").attr("offset","100%").attr("stop-color", "rgba(0,0,0,0.60)");

    // ── One <g> per bubble ───────────────────────────────────────────────────
    const g = svg.selectAll<SVGGElement, BubbleNode>("g.bubble")
      .data(nodes, d => d.id)
      .join("g")
      .attr("class", "bubble")
      .style("cursor", "pointer")
      .style("filter", d => bubbleGlowFilter(d.delta, maxAbsDelta));

    // Coloured ring (prominent Stockmap-style border, reacts to buy/sell state)
    g.append("circle").attr("class", "ring")
      .attr("r",  d => d.radius + 2.5)
      .attr("fill", "none")
      .attr("stroke", d => d.borderColor)
      .attr("stroke-width", 2.2)
      .attr("opacity", 0.80);

    // Main body — gradient fill, no extra stroke (cleaner, glass handles it)
    g.append("circle").attr("class", "body")
      .attr("r",       d => d.radius)
      .attr("fill",    d => `url(#fill-${d.id})`)
      .attr("opacity", 0.95);

    // Specular shine overlay
    g.append("circle").attr("class", "shine")
      .attr("r", d => d.radius).attr("fill", "url(#shine-shared)")
      .attr("pointer-events", "none");

    // Vignette (edge darkening)
    g.append("circle").attr("class", "vignette")
      .attr("r", d => d.radius).attr("fill", "url(#vignette-shared)")
      .attr("pointer-events", "none");

    // ── Glass edge: thin white stroke simulating curved glass surface ─────────
    // stroke-width 0.5, opacity 0.28 — subtle but gives depth
    g.append("circle").attr("class", "glass")
      .attr("r",            d => d.radius - 0.5)
      .attr("fill",         "none")
      .attr("stroke",       "rgba(255,255,255,0.28)")
      .attr("stroke-width", 0.8)
      .attr("pointer-events", "none");

    // ── Helper: compute font sizes + vertical positions for 3-line layout ────
    // layout: [% change] ← top  |  [TICKER] ← center  |  [v/vol] ← bottom
    // When radius < 30: only ticker, centered
    // When radius 30-42: ticker + % change
    // When radius > 42: all 3 lines
    const tickerFS  = (r: number) => Math.max(9,  Math.min(r * 0.40, 26));
    const subFS     = (r: number) => Math.max(7,  Math.min(r * 0.26, 14));
    const lineGap   = (r: number) => tickerFS(r) * 1.15 + subFS(r) * 0.5;

    // ── % change — top line ───────────────────────────────────────────────────
    g.append("text").attr("class", "label-top")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "middle")
      .attr("fill", d => d.priceChange >= 0 ? "#81c784" : "#e57373")
      .attr("font-family", FONT)
      .attr("font-weight", "600")
      .style("font-size",      d => `${subFS(d.radius)}px`)
      .style("pointer-events", "none")
      .attr("y", d => d.radius >= 30 ? -lineGap(d.radius) : 9999)
      .style("display",        d => d.radius < 30 ? "none" : "")
      .text(d => `${d.priceChange >= 0 ? "▲" : "▼"} ${Math.abs(d.priceChange).toFixed(2)}%`);

    // ── Ticker — center ───────────────────────────────────────────────────────
    g.append("text").attr("class", "label-ticker")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "middle")
      .attr("fill", "rgba(255,255,255,0.97)")
      .attr("font-family", FONT)
      .attr("font-weight", "800")
      .style("font-size",       d => `${tickerFS(d.radius)}px`)
      .style("letter-spacing",  "0.03em")
      .style("text-transform",  "uppercase")
      .style("pointer-events",  "none")
      .style("display",         d => d.radius < 20 ? "none" : "")
      // Shift ticker up when showing 3 lines so all 3 fit
      .attr("y", d => d.radius >= 42 ? -subFS(d.radius) * 0.35 : 0)
      .text(d => d.id);

    // ── Volume — bottom line (shown when radius ≥ 30 px) ─────────────────────
    g.append("text").attr("class", "label-vol")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "middle")
      .attr("fill", "rgba(210,220,230,0.70)")
      .attr("font-family", FONT)
      .attr("font-weight", "400")
      .style("font-size",      d => `${subFS(d.radius)}px`)
      .style("pointer-events", "none")
      // text-shadow is applied via the shared CSS rule in defs <style>
      .attr("y", d => d.radius >= 30 ? lineGap(d.radius) - subFS(d.radius) * 0.5 : 9999)
      .style("display",        d => d.radius < 30 ? "none" : "")
      .text(d => `v/${fmtVol(d.volume)}`);

    // ── Hover / click ─────────────────────────────────────────────────────────
    // On hover: maximise both glow layers so the bubble blazes with colour
    const hoverGlow = (d: BubbleNode) =>
      d.delta >= 0
        ? "drop-shadow(0 0 10px rgba(76,175,80,0.95)) drop-shadow(0 0 24px rgba(76,175,80,0.45))"
        : "drop-shadow(0 0 10px rgba(244,67,54,0.95)) drop-shadow(0 0 24px rgba(244,67,54,0.45))";

    const expandAll = (sel: d3.Selection<SVGGElement, BubbleNode, any, any>,
                       d: BubbleNode, scale: number, dur: number) => {
      const r = d.radius * scale;
      sel.select(".body")   .transition().duration(dur).attr("r", r);
      sel.select(".ring")   .transition().duration(dur).attr("r", r + 2.5);
      sel.select(".shine")  .transition().duration(dur).attr("r", r);
      sel.select(".glass")  .transition().duration(dur).attr("r", r - 0.5);
      sel.select(".vignette").transition().duration(dur).attr("r", r);
    };

    g.on("mouseenter", function (event, d) {
        d3.select(this).transition().duration(100).style("filter", hoverGlow(d));
        d3.select(this).select(".ring").transition().duration(100).attr("opacity", 1);
        expandAll(d3.select(this), d, 1.09, 100);
        setTooltip({ visible: true, x: event.clientX, y: event.clientY, node: d });
      })
      .on("mousemove", (event) => {
        setTooltip(prev => ({ ...prev, x: event.clientX, y: event.clientY }));
      })
      .on("mouseleave", function (_event, d) {
        d3.select(this).transition().duration(180)
          .style("filter", bubbleGlowFilter(d.delta, maxAbsDelta));
        d3.select(this).select(".ring").transition().duration(180).attr("opacity", 0.80);
        expandAll(d3.select(this), d, 1.0, 180);
        setTooltip(prev => ({ ...prev, visible: false }));
      })
      .on("click", (_event, d) => {
        window.open(`https://www.binance.com/en/trade/${d.id}_USDT`, "_blank");
      });

    // ── Force simulation — elastic bounce + fluid motion + gravity ──────────
    const cx = dims.w / 2;
    const cy = dims.h / 2 - 20;

    // 1) Attraction: forceRadial pulls every node toward the centre with
    //    gentle spring-like behaviour — bubbles drift inward if displaced
    //    but never clump to a single pixel. forceCenter is kept at minimal
    //    strength just to prevent drift of the whole cluster.
    // 2) Collision Elasticity: forceCollide at medium strength (0.78) with
    //    generous padding (radius + 3) — combined with low velocityDecay
    //    (0.18) this means kinetic energy is preserved after collision,
    //    producing visible bounce instead of dead-stop.
    // 3) Fluid Motion: a custom "brownian" force injects tiny random
    //    velocity perturbations every tick, simulating molecular jitter.
    //    alphaDecay is very low (0.005) so the simulation never truly
    //    "freezes" — bubbles keep gently floating and rearranging.

    const brownianForce = () => {
      const jitterStrength = 0.15;
      const force: d3.Force<BubbleNode, undefined> & { initialize?: (n: BubbleNode[]) => void } = () => {
        nodes.forEach(n => {
          n.vx = (n.vx ?? 0) + (Math.random() - 0.5) * jitterStrength;
          n.vy = (n.vy ?? 0) + (Math.random() - 0.5) * jitterStrength;
        });
      };
      force.initialize = () => {};
      return force as d3.Force<BubbleNode, undefined>;
    };

    const sim = d3.forceSimulation<BubbleNode>(nodes)
      // Gravity — gentle radial spring pulling everything toward center
      .force("radial",  d3.forceRadial<BubbleNode>(0, cx, cy).strength(0.035))
      // Nudge entire cluster centroid so it doesn't wander off-screen
      .force("center",  d3.forceCenter(cx, cy).strength(0.02))
      // Mild repulsion so same-size bubbles don't perfectly overlap
      .force("charge",  d3.forceManyBody<BubbleNode>().strength(-4))
      // Elastic collision — padding gives breathing room, moderate
      // strength lets kinetic energy bounce back through velocity
      .force("collide", d3.forceCollide<BubbleNode>(d => d.radius + 3)
                           .strength(0.78).iterations(4))
      // Fluid: tiny random velocity perturbations every tick
      .force("brownian", brownianForce())
      // Keep simulation alive much longer so it never feels static
      .alphaDecay(0.005)
      .alphaMin(0.008)
      // Low velocity damping → energy preserved → elastic bounce feel
      .velocityDecay(0.18)
      .on("tick", () => {
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

        const lookup  = new Map(nodesRef.current.map(n => [n.fullId, n]));
        // Track which nodes had a volume spike for pulse animation
        const spiked: string[] = [];
        let changed = false;

        tickers.forEach(t => {
          const node = lookup.get(t.s);
          if (!node) return;
          const c = parseFloat(t.c), o = parseFloat(t.o), q = parseFloat(t.q);
          const prevRadius     = node.radius;
          node.priceChange     = o > 0 ? (c - o) / o * 100 : 0;
          node.volume          = q;
          node.delta           = q * node.priceChange / 100;
          node.price           = c;
          node.radius          = rScale(q);
          node.color           = bubbleColor(node.delta, maxAbs);
          node.borderColor     = bubbleBorderColor(node.delta, maxAbs);
          // Volume spike: radius grew > 18% — trigger pulse animation
          if (node.radius > prevRadius * 1.18 && node.radius > prevRadius + 4) {
            spiked.push(node.id);
          }
          changed = true;
        });

        if (!changed || !svgRef.current) return;

        // Batch DOM updates every 800 ms to prevent thrashing
        clearTimeout(batchTimer.current);
        batchTimer.current = setTimeout(() => {
          if (!svgRef.current) return;
          const svg       = d3.select(svgRef.current);
          const newMaxAbs = d3.max(nodesRef.current.map(n => Math.abs(n.delta))) ?? 1;
          const subFS     = (r: number) => Math.max(7, Math.min(r * 0.26, 14));
          const tickerFS  = (r: number) => Math.max(9, Math.min(r * 0.40, 26));
          const lineGap   = (r: number) => tickerFS(r) * 1.15 + subFS(r) * 0.5;

          nodesRef.current.forEach(node => {
            const grp      = svg.selectAll<SVGGElement, BubbleNode>("g.bubble")
              .filter(d => d.id === node.id);
            const isSpiked = spiked.includes(node.id);

            // Update fill gradient stops
            const baseCol = d3.color(node.color);
            if (baseCol) {
              const lighter = (baseCol as d3.RGBColor).brighter(0.55).formatRgb();
              const darker  = (baseCol as d3.RGBColor).darker(1.4).formatRgb();
              svg.select(`#fill-${node.id} stop:nth-child(1)`).attr("stop-color", lighter);
              svg.select(`#fill-${node.id} stop:nth-child(2)`).attr("stop-color", node.color);
              svg.select(`#fill-${node.id} stop:nth-child(3)`).attr("stop-color", darker);
            }

            // Update stroke colors
            grp.select(".body").attr("stroke", node.borderColor);
            grp.select(".ring").attr("stroke", node.borderColor);

            // Update glow
            grp.style("filter", bubbleGlowFilter(node.delta, newMaxAbs));

            // Update text labels
            grp.select(".label-top")
              .attr("fill", node.priceChange >= 0 ? "#81c784" : "#e57373")
              .attr("y",    node.radius >= 30 ? -lineGap(node.radius) : 9999)
              .style("display", node.radius < 30 ? "none" : "")
              .text(`${node.priceChange >= 0 ? "▲" : "▼"} ${Math.abs(node.priceChange).toFixed(2)}%`);

            grp.select(".label-ticker")
              .attr("y", node.radius >= 42 ? -subFS(node.radius) * 0.35 : 0);

            grp.select(".label-vol")
              .attr("y",    node.radius >= 30 ? lineGap(node.radius) - subFS(node.radius) * 0.5 : 9999)
              .style("display", node.radius < 30 ? "none" : "")
              .text(`v/${fmtVol(node.volume)}`);

            // ── Volume spike animation ─────────────────────────────────────
            if (isSpiked) {
              const peak = node.radius * 1.32;
              grp.select(".body")
                .transition().duration(200).ease(d3.easeQuadOut).attr("r", peak)
                .transition().duration(420).ease(d3.easeBounceOut).attr("r", node.radius);
              grp.select(".ring")
                .transition().duration(200).attr("r", peak + 2.5).attr("opacity", 1)
                .transition().duration(420).attr("r", node.radius + 2.5).attr("opacity", 0.80);
              grp.select(".shine")
                .transition().duration(200).attr("r", peak)
                .transition().duration(420).attr("r", node.radius);
              grp.select(".glass")
                .transition().duration(200).attr("r", peak - 0.5)
                .transition().duration(420).attr("r", node.radius - 0.5);
              grp.select(".vignette")
                .transition().duration(200).attr("r", peak)
                .transition().duration(420).attr("r", node.radius);
            } else {
              grp.select(".body").attr("r", node.radius);
              grp.select(".ring").attr("r", node.radius + 2.5);
              grp.select(".shine").attr("r", node.radius);
              grp.select(".glass").attr("r", node.radius - 0.5);
              grp.select(".vignette").attr("r", node.radius);
            }
          });

          // Re-apply collide with updated radii + give a visible energy kick
          // so the newly-resized bubbles bounce apart elastically
          simRef.current?.force("collide",
            d3.forceCollide<BubbleNode>(d => d.radius + 3).strength(0.78).iterations(4)
          );
          simRef.current?.alpha(0.25).restart();
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
          style={{ background: "#000000" }}
        >
          {/* Pure black — no grid, matches Stockmap style */}

          {/* ── Header bar ─────────────────────────────────────────────────── */}
          <div
            className="absolute top-0 left-0 right-0 z-10 flex items-center justify-between px-5 py-2.5 gap-3"
            style={{
              background: "linear-gradient(180deg,rgba(0,0,0,0.97) 0%,rgba(0,0,0,0.7) 70%,transparent 100%)",
              borderBottom: "1px solid rgba(76,175,80,0.15)",
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
              <div className="hidden md:flex items-center gap-3 text-[9px]" style={{ color: "#556677" }}>
                <div className="flex items-center gap-1.5">
                  <span className="h-2.5 w-2.5 rounded-full" style={{
                    background: "#4caf50",
                    boxShadow: "0 0 6px rgba(76,175,80,0.65)",
                  }}/>
                  <span style={{ color: "#81c784" }}>Net Buyers</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <span className="h-2.5 w-2.5 rounded-full" style={{ background: "#1e2128" }}/>
                  Neutral
                </div>
                <div className="flex items-center gap-1.5">
                  <span className="h-2.5 w-2.5 rounded-full" style={{
                    background: "#f44336",
                    boxShadow: "0 0 6px rgba(244,67,54,0.65)",
                  }}/>
                  <span style={{ color: "#e57373" }}>Net Sellers</span>
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
              <div className="h-14 w-14 rounded-full border-4 animate-spin"
                style={{ borderColor: "rgba(76,175,80,0.15)", borderTopColor: "#4caf50",
                  boxShadow: "0 0 18px rgba(76,175,80,0.3)" }} />
              <p className="text-sm" style={{ color: "#81c784" }}>
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
          {tooltip.visible && tooltip.node && (() => {
            const n       = tooltip.node;
            const isBull  = n.delta >= 0;
            const accentC = isBull ? "#4caf50" : "#f44336";
            const accentS = isBull ? "rgba(76,175,80,0.18)" : "rgba(244,67,54,0.18)";
            return (
              <div
                className="pointer-events-none fixed z-30 rounded-xl px-3.5 py-3 backdrop-blur-md"
                style={{
                  left:   ttLeft,
                  top:    ttTop,
                  width:  TT_W,
                  background: "rgba(0,0,0,0.88)",
                  border: `1px solid ${accentC}33`,
                  boxShadow: `0 0 0 1px ${accentC}22, 0 12px 40px rgba(0,0,0,0.9), 0 0 30px ${accentC}18`,
                }}
              >
                {/* Accent top bar */}
                <div className="absolute top-0 left-4 right-4 h-[1.5px] rounded-full"
                  style={{ background: `linear-gradient(90deg,transparent,${accentC},transparent)` }} />

                {/* Header row */}
                <div className="flex items-center justify-between mb-2.5">
                  <div className="flex items-center gap-2">
                    <span className="h-3 w-3 rounded-full shrink-0"
                      style={{ background: accentC, boxShadow: `0 0 10px ${accentC}` }} />
                    <p className="text-white font-bold text-sm tracking-wide"
                      style={{ fontFamily: "'Inter',sans-serif" }}>
                      {n.id}
                      <span className="font-normal text-xs" style={{ color: "#445566" }}>/USDT</span>
                    </p>
                  </div>
                  <span className="text-xs font-bold rounded-md px-1.5 py-0.5"
                    style={{ color: accentC, background: accentS }}>
                    {n.priceChange >= 0 ? "▲" : "▼"} {Math.abs(n.priceChange).toFixed(2)}%
                  </span>
                </div>

                {/* Divider */}
                <div className="h-px mb-2" style={{ background: `${accentC}18` }} />

                {/* Stats grid */}
                <div className="grid grid-cols-2 gap-x-3 gap-y-2 text-[10px]"
                  style={{ fontFamily: "'Inter',sans-serif" }}>
                  <div>
                    <p style={{ color: "#445566" }}>Price</p>
                    <p className="text-white font-semibold font-mono">
                      ${n.price.toLocaleString(undefined, { maximumFractionDigits: 4 })}
                    </p>
                  </div>
                  <div>
                    <p style={{ color: "#445566" }}>{timeframe} Volume</p>
                    <p className="text-white font-semibold font-mono">{fmtVol(n.volume)}</p>
                  </div>
                  <div>
                    <p style={{ color: "#445566" }}>Net Flow (Δ)</p>
                    <p className="font-semibold font-mono" style={{ color: accentC }}>
                      {n.delta >= 0 ? "+" : ""}{fmtVol(Math.abs(n.delta))}
                    </p>
                  </div>
                  <div>
                    <p style={{ color: "#445566" }}>Signal</p>
                    <p className="font-bold" style={{ color: accentC }}>
                      {Math.abs(n.priceChange) < 0.5 ? "Neutral" : isBull ? "Bullish" : "Bearish"}
                    </p>
                  </div>
                </div>

                <p className="text-center mt-2.5" style={{ fontSize: 9, color: "#334455" }}>
                  Click to trade on Binance ↗
                </p>
              </div>
            );
          })()}

          {/* Bottom hint */}
          <div
            className="absolute bottom-3 left-1/2 text-[9px] text-center select-none"
            style={{ transform: "translateX(-50%)", color: "rgba(255,255,255,0.15)", letterSpacing: "0.06em" }}
          >
            Bubble size = {timeframe} volume &nbsp;·&nbsp; Color = buy/sell flow &nbsp;·&nbsp; Click any bubble to trade on Binance
          </div>
        </div>
      )}
    </>
  );
}
