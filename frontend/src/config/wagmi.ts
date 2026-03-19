import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { http } from "wagmi";
import { fallback } from "viem";
import { defineChain } from "viem";

const POLKADOT_RPC = import.meta.env.VITE_RPC_URL || "https://eth-rpc-testnet.polkadot.io/";
const POLKADOT_RPC_ALT = "https://services.polkadothub-rpc.com/testnet/";

export const polkadotEVMTestnet = defineChain({
  id: 420420417,
  name: "Polkadot Hub TestNet",
  nativeCurrency: { name: "PAS", symbol: "PAS", decimals: 10 },
  rpcUrls: {
    default: { http: [POLKADOT_RPC, POLKADOT_RPC_ALT] },
  },
  blockExplorers: {
    default: {
      name: "Blockscout",
      url: "https://blockscout-testnet.polkadot.io",
    },
  },
});

/** Fallback transport: try primary RPC first, then alternative (helps when "Transaction is temporarily banned"). */
const polkadotTransport = fallback([
  http(POLKADOT_RPC, { retryCount: 2 }),
  http(POLKADOT_RPC_ALT, { retryCount: 2 }),
]);

export const config = getDefaultConfig({
  appName: "Zenit Perpetual DEX",
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || "zenit-perp-dex",
  chains: [polkadotEVMTestnet],
  transports: {
    [polkadotEVMTestnet.id]: polkadotTransport,
  },
});
