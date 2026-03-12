import { useEffect, useRef, useState } from "react";
import robotIcon from "../../icon/Gemini_Generated_Image_cdy6yocdy6yocdy6.png";

// ─── Types ────────────────────────────────────────────────────────────────────
interface Message {
  id: number;
  role: "assistant" | "user";
  text: string;
  ts: string;
}

// ─── Smart response engine (placeholder until real AI backend) ────────────────
const GREETINGS = [
  "Hello, trader! I'm **Z7 AI**, your trading assistant. Ask me about market signals, indicators, or trading strategy.",
  "Hey! **Z7 AI** here. I can help you read the Signal Radar, understand indicators, or discuss entry strategies.",
];

function pickGreeting() {
  return GREETINGS[Math.floor(Math.random() * GREETINGS.length)];
}

const CHATBOT_EVENT_NAME = "ai-chatbot-request";
const INDICATOR_GUIDE = `
Here is what the Indicators Panel is telling you:

• **EMA & SMA Chart** – shows price relative to short and long moving averages. Price above both EMAs with EMA12 above EMA26 signals a bullish trend; the reverse signals a bearish trend. The SMA provides a smoother baseline.

• **RSI Chart** – plots momentum on a 0–100 scale. Values below 38 mean a strong short bias, values above 62 mean a strong long bias, and the middle range is neutral.

• **ADX Chart** – measures trend strength, not direction. Higher scores mean a strong trend (use alongside RSI/EMAs to confirm trend direction); values below 38 mean a weak or ranging market.

• **Momentum (12)** – compares price differences over 12 periods. Above 62 → accelerating upward momentum (Long); below 38 → accelerating downward momentum (Short).

• **Footprint History** – shows buying vs selling pressure and footprint volume clusters. Use it to confirm whether aggressive orders are supporting the directional bias shown by the other indicators.

Combining these lets you read the Signal Radar (RSI, EMA cross, SMA, ADX, Momentum) and understand whether the market favors Long, Short, or is neutral.
`.trim();

type IndicatorChatbotPayload = {
  topic: "indicators";
  prompt?: string;
  indicatorId?: string;
  label?: string;
};

const INDICATOR_EXPLANATIONS: Record<string, string> = {
  "ema-sma": "That panel overlays the price with EMA12, EMA26, and SMA14. A strong long signal appears when price stays above EMA12 which sits above EMA26; a bearish short signal surfaces when EMA12 dips below EMA26 and price is below the SMA.",
  "rsi": "RSI values near 100 mean overbought while values near 0 mean oversold. Crossing above 62 suggests a long bias, while slipping below 38 indicates a short bias. Watch for divergence with price for potential reversals.",
  "adx": "ADX tracks trend strength (0–100). Values above ~40 confirm a strong trend, while values under ~25 hint at a choppy or ranging market. Use it with RSI/MAs to decide whether the trend is worth trading.",
  "momentum": "Momentum (12) compares the latest price to its level 12 bars ago. A reading near 100 signals accelerating upward momentum (long), near 0 signals downward momentum (short), and flattening shows cooling momentum.",
  "footprint": "Footprint History highlights where aggressive buying or selling happened across price levels. Look for high volume prints supporting the direction implied by the other indicators before committing.",
};

function buildIndicatorResponse(indicatorId?: string, label?: string) {
  const explanation = indicatorId ? INDICATOR_EXPLANATIONS[indicatorId] : undefined;
  const prefix = label ? `You asked about ${label}. ` : "";
  return `${prefix}${explanation ?? INDICATOR_GUIDE}`;
}

function buildReply(input: string): string {
  const q = input.toLowerCase();

  if (/rsi/.test(q))
    return "RSI (Relative Strength Index) measures momentum. Below **38** → oversold / Short bias. Above **62** → overbought / Long bias. The Signal Radar maps this to a 0–100 scale for quick reading.";

  if (/ema|sma|moving average/.test(q))
    return "EMA & SMA lines show trend direction. When **price > EMA 12 > EMA 26**, the trend is bullish. The EMA Cross score on the Radar reflects the gap between price and the average of EMA 12/26.";

  if (/adx|trend strength/.test(q))
    return "ADX measures **trend strength**, not direction. A high ADX score (>62 on the Radar) means a strong bullish trend. A low score (<38) means a strong bearish trend. Middle range = weak/ranging market.";

  if (/momentum|mtm/.test(q))
    return "Momentum (MTM) shows the speed of price change over 12 periods. Score near **100** → accelerating upward momentum (Long bias). Near **0** → sharp downward momentum (Short bias).";

  if (/radar|signal|indicator/.test(q))
    return "The **Signal Radar** aggregates RSI, EMA Cross, SMA, ADX, and Momentum into a 0–100 score. Each axis represents one indicator. The overall score drives the LONG / NEUTRAL / SHORT label in the center.";

  if (/long|buy|bull/.test(q))
    return "For a **Long entry**, look for: Signal Radar overall score >62, RSI not yet overbought, EMA 12 crossing above EMA 26, positive Momentum. Always set a Stop Loss below a key support level.";

  if (/short|sell|bear/.test(q))
    return "For a **Short entry**, look for: Signal Radar overall score <38, RSI turning down from overbought, EMA 12 crossing below EMA 26, declining Momentum. Manage risk with a Stop Loss above resistance.";

  if (/leverage/.test(q))
    return "Higher leverage amplifies both gains and losses. As a rule of thumb: keep risk per trade to **1–2%** of your capital regardless of leverage. Lower leverage gives more room before liquidation.";

  if (/stop.?loss|sl/.test(q))
    return "A Stop Loss protects your capital. Common approaches: **below/above recent swing high/low**, **1.5× ATR from entry**, or a fixed % away from entry. Always set it *before* you open the position.";

  if (/take.?profit|tp/.test(q))
    return "Take Profit targets can be set at key resistance/support levels or using a **risk-reward ratio** (e.g., 2:1 means TP is twice the distance of your SL from entry).";

  if (/btc|bitcoin/.test(q))
    return "Bitcoin (BTC) is the most liquid crypto market. It often leads altcoin moves. Watch BTC dominance and macro factors (Fed rates, ETF flows) alongside your indicators.";

  if (/eth|ethereum/.test(q))
    return "Ethereum (ETH) follows BTC trends closely but has its own catalysts: Layer 2 activity, staking yields, and DeFi TVL. Higher volatility = larger swings on the Radar.";

  if (/dot|polkadot/.test(q))
    return "Polkadot (DOT) is a smaller cap asset with higher volatility. Signals from the Radar can have sharper swings — consider tighter stops and smaller position sizes relative to BTC/ETH trades.";

  if (/hello|hi|hey|greet/.test(q))
    return "Hey there, trader! How can **Z7 AI** help you today? Ask about indicators, entry signals, risk management, or any crypto pair.";

  if (/thank/.test(q))
    return "Glad I could help! Trade smart, manage your risk, and feel free to ask anything else. 🚀";

  if (/help|what can you do|feature/.test(q))
    return "I can help you with:\n• Reading the **Signal Radar**\n• Understanding **RSI, EMA, SMA, ADX, Momentum**\n• **Entry & exit** strategy tips\n• **Risk management** (SL / TP / leverage)\n• Questions about **BTC, ETH, DOT**\n\nJust ask!";

  return "I'm still learning every nuance of the markets! Could you rephrase, or ask about a specific indicator (RSI, EMA, ADX, Momentum), a strategy (Long/Short), or risk management?";
}

function now() {
  return new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

// ─── Markdown-lite renderer (bold only) ──────────────────────────────────────
function renderMd(text: string) {
  return text.split("\n").map((line, li) => {
    const parts: (string | JSX.Element)[] = [];
    let remaining = line;
    let key = 0;
    while (remaining.length) {
      const s = remaining.indexOf("**");
      if (s === -1) { parts.push(remaining); break; }
      const e = remaining.indexOf("**", s + 2);
      if (e === -1) { parts.push(remaining); break; }
      if (s > 0) parts.push(remaining.slice(0, s));
      parts.push(<strong key={key++} className="font-semibold text-white">{remaining.slice(s + 2, e)}</strong>);
      remaining = remaining.slice(e + 2);
    }
    return (
      <span key={li} className={li > 0 ? "block mt-1" : ""}>
        {parts}
      </span>
    );
  });
}

// ─── Typing indicator ─────────────────────────────────────────────────────────
function TypingDots() {
  return (
    <div className="flex items-center gap-1 px-3 py-2">
      {[0, 1, 2].map((i) => (
        <span
          key={i}
          className="h-1.5 w-1.5 rounded-full bg-cyan-400"
          style={{ animation: `bounce 1.2s ${i * 0.2}s infinite ease-in-out` }}
        />
      ))}
    </div>
  );
}

// ─── Component ───────────────────────────────────────────────────────────────
export default function AIChatbotWidget() {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState<Message[]>([
    { id: 0, role: "assistant", text: pickGreeting(), ts: now() },
  ]);
  const [input, setInput] = useState("");
  const [typing, setTyping] = useState(false);
  const [pulse, setPulse] = useState(true);
  const endRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Stop initial pulse after first open
  useEffect(() => {
    if (open) setPulse(false);
  }, [open]);

  // Auto-scroll on new message
  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, typing]);

  // Focus input when opened
  useEffect(() => {
    if (open) setTimeout(() => inputRef.current?.focus(), 150);
  }, [open]);

  useEffect(() => {
    const pendingTimers: ReturnType<typeof setTimeout>[] = [];
    const handler = (event: Event) => {
      const payload = (event as CustomEvent<IndicatorChatbotPayload>).detail;
      if (!payload || payload.topic !== "indicators") return;
      const timestamp = Date.now();
      const userMsg: Message = {
        id: timestamp,
        role: "user",
        text: payload.prompt ?? "Explain the indicator signals.",
        ts: now(),
      };
      setMessages((prev) => [...prev, userMsg]);
      setOpen(true);
      setTyping(true);
      const timer = setTimeout(() => {
        setTyping(false);
        const assistantMsg: Message = {
          id: timestamp + 1,
          role: "assistant",
          text: buildIndicatorResponse(payload.indicatorId, payload.label),
          ts: now(),
        };
        setMessages((prev) => [...prev, assistantMsg]);
      }, 3000);
      pendingTimers.push(timer);
    };
    window.addEventListener(CHATBOT_EVENT_NAME, handler as EventListener);
    return () => {
      window.removeEventListener(CHATBOT_EVENT_NAME, handler as EventListener);
      pendingTimers.forEach(clearTimeout);
    };
  }, []);

  function send() {
    const text = input.trim();
    if (!text) return;
    const userMsg: Message = { id: Date.now(), role: "user", text, ts: now() };
    setMessages((m) => [...m, userMsg]);
    setInput("");
    setTyping(true);
    setTimeout(
      () => {
        setTyping(false);
        const reply: Message = {
          id: Date.now() + 1,
          role: "assistant",
          text: buildReply(text),
          ts: now(),
        };
        setMessages((m) => [...m, reply]);
      },
      700 + Math.random() * 600,
    );
  }

  function handleKey(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); }
  }

  return (
    <>
      {/* ── Bounce animation keyframes ── */}
      <style>{`
        @keyframes bounce {
          0%, 80%, 100% { transform: translateY(0); opacity: .5; }
          40% { transform: translateY(-5px); opacity: 1; }
        }
        @keyframes z7-pulse {
          0%, 100% { box-shadow: 0 0 0 0 rgba(99,102,241,0.55); }
          50% { box-shadow: 0 0 0 10px rgba(99,102,241,0); }
        }
        @keyframes z7-ring {
          0%   { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
        @keyframes z7-slide-up {
          from { opacity: 0; transform: translateY(16px) scale(0.97); }
          to   { opacity: 1; transform: translateY(0)   scale(1); }
        }
      `}</style>

      {/* ── Chat popup ── */}
      {open && (
        <div
          className="fixed bottom-[88px] right-5 z-[9998] flex flex-col rounded-2xl overflow-hidden shadow-2xl"
          style={{
            width: 340,
            height: 480,
            background: "linear-gradient(160deg,#0b0d20 0%,#0d0f24 100%)",
            border: "1px solid rgba(99,102,241,0.3)",
            boxShadow: "0 0 40px rgba(99,102,241,0.15), 0 20px 60px rgba(0,0,0,0.6)",
            animation: "z7-slide-up 0.22s ease-out both",
          }}
        >
          {/* Header */}
          <div
            className="flex items-center gap-3 px-4 py-3 shrink-0"
            style={{
              background: "linear-gradient(90deg,rgba(61,81,255,0.25) 0%,rgba(99,102,241,0.10) 100%)",
              borderBottom: "1px solid rgba(99,102,241,0.2)",
            }}
          >
            {/* Avatar */}
            <div className="relative shrink-0">
              <div
                className="h-9 w-9 rounded-full overflow-hidden"
                style={{
                  border: "2px solid rgba(99,102,241,0.5)",
                  boxShadow: "0 0 12px rgba(99,102,241,0.4)",
                }}
              >
                <img
                  src={robotIcon}
                  alt="Z7 AI icon"
                  className="h-full w-full object-cover"
                  decoding="async"
                />
              </div>
              <span className="absolute bottom-0 right-0 h-2.5 w-2.5 rounded-full bg-emerald-400 border-2 border-[#0b0d20]" />
            </div>

            <div className="flex-1 min-w-0">
              <div className="text-[13px] font-bold text-white tracking-wide">Z7 AI Assistant</div>
              <div className="text-[10px] text-cyan-400/80">Trading · Online</div>
            </div>

            <button
              onClick={() => setOpen(false)}
              className="text-slate-500 hover:text-white transition-colors p-1 rounded-lg hover:bg-white/5"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
                <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          </div>

          {/* Messages */}
          <div className="flex-1 overflow-y-auto px-3 py-3 space-y-3" style={{ scrollbarWidth: "thin", scrollbarColor: "#1e2240 transparent" }}>
            {messages.map((msg) => (
              <div
                key={msg.id}
                className={`flex gap-2 ${msg.role === "user" ? "flex-row-reverse" : "flex-row"}`}
              >
                {/* Avatar dot */}
                {msg.role === "assistant" && (
                  <div className="shrink-0 h-6 w-6 rounded-full flex items-center justify-center mt-1"
                    style={{ background: "radial-gradient(#1e2045,#090b18)", border: "1px solid rgba(99,102,241,0.4)" }}>
                    <svg viewBox="0 0 20 20" width="14" height="14">
                      <circle cx="10" cy="10" r="7" fill="none" stroke="#22d3ee" strokeWidth="1" strokeOpacity="0.8" />
                      <circle cx="10" cy="10" r="3.5" fill="rgba(61,81,255,0.6)" />
                      <circle cx="10" cy="10" r="1.5" fill="#0b0d1e" />
                    </svg>
                  </div>
                )}

                <div className={`max-w-[80%] ${msg.role === "user" ? "items-end" : "items-start"} flex flex-col gap-0.5`}>
                  <div
                    className="rounded-2xl px-3 py-2 text-[12.5px] leading-relaxed"
                    style={
                      msg.role === "assistant"
                        ? {
                            background: "rgba(99,102,241,0.12)",
                            border: "1px solid rgba(99,102,241,0.2)",
                            color: "#cbd5e1",
                            borderTopLeftRadius: 4,
                          }
                        : {
                            background: "linear-gradient(135deg,#3d51ff,#6366f1)",
                            color: "#fff",
                            borderTopRightRadius: 4,
                          }
                    }
                  >
                    {msg.role === "assistant" ? renderMd(msg.text) : msg.text}
                  </div>
                  <span className="text-[9px] text-slate-600 px-1">{msg.ts}</span>
                </div>
              </div>
            ))}

            {/* Typing indicator */}
            {typing && (
              <div className="flex gap-2">
                <div className="shrink-0 h-6 w-6 rounded-full flex items-center justify-center mt-1"
                  style={{ background: "radial-gradient(#1e2045,#090b18)", border: "1px solid rgba(99,102,241,0.4)" }}>
                  <svg viewBox="0 0 20 20" width="14" height="14">
                    <circle cx="10" cy="10" r="7" fill="none" stroke="#22d3ee" strokeWidth="1" strokeOpacity="0.8" />
                    <circle cx="10" cy="10" r="3.5" fill="rgba(61,81,255,0.6)" />
                    <circle cx="10" cy="10" r="1.5" fill="#0b0d1e" />
                  </svg>
                </div>
                <div className="rounded-2xl px-1 py-1" style={{ background: "rgba(99,102,241,0.12)", border: "1px solid rgba(99,102,241,0.2)", borderTopLeftRadius: 4 }}>
                  <TypingDots />
                </div>
              </div>
            )}
            <div ref={endRef} />
          </div>

          {/* Quick prompts */}
          <div className="shrink-0 px-3 pb-2 flex gap-1.5 flex-wrap">
            {["Signal Radar?", "Long entry?", "Risk management", "What is ADX?"].map((q) => (
              <button
                key={q}
                onClick={() => { setInput(q); setTimeout(() => inputRef.current?.focus(), 50); }}
                className="rounded-full px-2.5 py-1 text-[10px] text-slate-400 hover:text-white transition-colors"
                style={{ background: "rgba(99,102,241,0.1)", border: "1px solid rgba(99,102,241,0.2)" }}
              >
                {q}
              </button>
            ))}
          </div>

          {/* Input */}
          <div
            className="shrink-0 flex items-center gap-2 px-3 py-3"
            style={{ borderTop: "1px solid rgba(99,102,241,0.15)", background: "rgba(99,102,241,0.05)" }}
          >
            <input
              ref={inputRef}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKey}
              placeholder="Ask about indicators…"
              className="flex-1 rounded-xl bg-transparent px-3 py-2 text-[12.5px] text-slate-200 placeholder-slate-600 outline-none"
              style={{ border: "1px solid rgba(99,102,241,0.25)", background: "rgba(0,0,0,0.3)" }}
            />
            <button
              onClick={send}
              disabled={!input.trim()}
              className="h-8 w-8 rounded-xl flex items-center justify-center transition-all disabled:opacity-30"
              style={{ background: "linear-gradient(135deg,#3d51ff,#6366f1)" }}
            >
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <line x1="22" y1="2" x2="11" y2="13" />
                <polygon points="22 2 15 22 11 13 2 9 22 2" />
              </svg>
            </button>
          </div>
        </div>
      )}

      {/* ── Floating trigger button ── */}
      <button
        onClick={() => setOpen((o) => !o)}
        className="fixed bottom-5 right-5 z-[9999] h-14 w-14 rounded-full focus:outline-none"
        style={{
          background: "radial-gradient(circle at 38% 32%, #1e2255 0%, #090c1e 100%)",
          border: "2px solid rgba(99,102,241,0.55)",
          boxShadow: open
            ? "0 0 0 0 transparent, 0 8px 32px rgba(61,81,255,0.5)"
            : "0 8px 32px rgba(61,81,255,0.35)",
          animation: pulse && !open ? "z7-pulse 2s infinite" : undefined,
          transition: "box-shadow 0.3s ease",
        }}
        title="Z7 AI Trading Assistant"
      >
        {/* Spinning outer ring */}
        <svg
          className="absolute inset-0 w-full h-full"
          viewBox="0 0 56 56"
          style={{ animation: "z7-ring 8s linear infinite" }}
        >
          <circle cx="28" cy="28" r="25" fill="none" stroke="rgba(34,211,238,0.35)" strokeWidth="1.2" strokeDasharray="10 5" />
        </svg>

        {/* Inner icon */}
        <div className="relative flex h-full w-full items-center justify-center">
          <img
            src={robotIcon}
            alt="Z7 AI icon"
            className="h-11 w-11 rounded-full object-cover"
            decoding="async"
          />
        </div>

        {/* Unread badge — only shown when closed */}
        {!open && (
          <span
            className="absolute -top-1 -right-1 h-4 w-4 rounded-full flex items-center justify-center text-[8px] font-bold text-white"
            style={{ background: "linear-gradient(135deg,#6366f1,#3d51ff)" }}
          >
            AI
          </span>
        )}
      </button>
    </>
  );
}
