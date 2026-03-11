import { describe, expect, it } from "vitest";

import { polkadotEVMTestnet } from "../wagmi";

describe("defineChain metadata", () => {
  it("keeps the MetaMask-friendly metadata for Polkadot EVM Testnet", () => {
    expect(polkadotEVMTestnet).toMatchObject({
      id: 420420417,
      name: "Polkadot EVM Testnet",
      nativeCurrency: { name: "DOT", symbol: "DOT", decimals: 18 },
    });
    expect(polkadotEVMTestnet.rpcUrls.default.http).toContain("https://eth-rpc-testnet.polkadot.io/");
    expect(polkadotEVMTestnet.blockExplorers?.default?.name).toBe("Blockscout");
    expect(polkadotEVMTestnet.blockExplorers?.default?.url).toBe("https://blockscout-testnet.polkadot.io");
  });
});
