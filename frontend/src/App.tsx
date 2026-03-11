import { Routes, Route, NavLink, Link } from "react-router-dom";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { ErrorBoundary } from "./components/ErrorBoundary";
import Trade from "./pages/Trade";
import Rewards from "./pages/Rewards";

function Layout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-[#0d0f18]">
      <header className="border-b border-[#363a59]/50 bg-[#121421]/80 backdrop-blur-sm sticky top-0 z-50 px-6 py-4 flex items-center justify-between">
        <Link to="/" className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-blue-500 to-blue-600 flex items-center justify-center text-white font-bold text-sm">Z</div>
          <span className="text-xl font-semibold text-white">Zenit</span>
          <span className="text-slate-500 text-sm hidden sm:inline">Perpetual DEX</span>
        </Link>
        <nav className="flex items-center gap-1">
          <NavLink
            to="/"
            className={({ isActive }) =>
              `px-4 py-2 rounded-lg transition font-medium ${
                isActive
                  ? "text-white bg-gradient-to-r from-blue-500 to-sky-500 shadow-lg shadow-blue-500/30"
                  : "text-slate-400 hover:text-white hover:bg-[#1e2033]"
              }`
            }
          >
            Trade
          </NavLink>
          <NavLink
            to="/rewards"
            className={({ isActive }) =>
              `px-4 py-2 rounded-lg transition font-medium ${
                isActive
                  ? "text-white bg-gradient-to-r from-blue-500 to-sky-500 shadow-lg shadow-blue-500/30"
                  : "text-slate-400 hover:text-white hover:bg-[#1e2033]"
              }`
            }
          >
            Rewards
          </NavLink>
          <div className="ml-4">
            <ConnectButton />
          </div>
        </nav>
      </header>
      <main className="max-w-7xl mx-auto px-6 py-8">{children}</main>
    </div>
  );
}

export default function App() {
  return (
    <ErrorBoundary>
      <Layout>
        <Routes>
          <Route path="/" element={<Trade />} />
          <Route path="/rewards" element={<Rewards />} />
        </Routes>
      </Layout>
    </ErrorBoundary>
  );
}
