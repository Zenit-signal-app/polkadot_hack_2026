export const PERPETUAL_DEX_ABI = [
  { inputs: [{ name: "_amount", type: "uint256" }], name: "deposit", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "_amount", type: "uint256" }], name: "withdraw", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "_amount", type: "uint256" }, { name: "_positionType", type: "uint8" }, { name: "_leverage", type: "uint8" }], name: "openPosition", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "_amount", type: "uint256" }], name: "increasePosition", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "_amount", type: "uint256" }], name: "closePosition", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "_account", type: "address" }], name: "balanceOf", outputs: [{ type: "uint256" }], stateMutability: "view", type: "function" },
  { inputs: [{ name: "user", type: "address" }], name: "getCurrentPosition", outputs: [{ components: [{ name: "amount", type: "uint256" }, { name: "position", type: "uint8" }, { name: "leverage", type: "uint8" }], type: "tuple" }], stateMutability: "view", type: "function" },
  { inputs: [], name: "getTokenAddress", outputs: [{ type: "address" }], stateMutability: "view", type: "function" },
] as const;
