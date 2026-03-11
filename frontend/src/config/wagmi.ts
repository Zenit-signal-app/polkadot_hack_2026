import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { http } from "wagmi";
import { defineChain } from "viem";

export const polkadotEVMTestnet = defineChain({
  id: 420420417,
  name: "Polkadot EVM Testnet",
  nativeCurrency: { name: "DOT", symbol: "DOT", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://eth-rpc-testnet.polkadot.io/"] },
  },
  blockExplorers: {
    default: {
      name: "Blockscout",
      url: "https://blockscout-testnet.polkadot.io",
    },
  },
});

export const config = getDefaultConfig({
  appName: "Zenit Perpetual DEX",
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || "zenit-perp-dex",
  chains: [polkadotEVMTestnet],
  transports: {
    [polkadotEVMTestnet.id]: http("https://eth-rpc-testnet.polkadot.io/"),
  },
});
