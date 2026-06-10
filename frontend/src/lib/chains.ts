import { defineChain } from "viem";

// Unichain Sepolia — where the hook, vault, and demo runner live.
export const unichainSepolia = defineChain({
  id: 1301,
  name: "Unichain Sepolia",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://sepolia.unichain.org"] },
  },
  blockExplorers: {
    default: { name: "Uniscan", url: "https://unichain-sepolia.blockscout.com" },
  },
  testnet: true,
});

// Reactive Lasna — where the ReactiveRiskMonitor RSC runs. Referenced for
// status display only; the app does not transact here directly.
export const reactiveLasna = defineChain({
  id: 5318007,
  name: "Reactive Lasna",
  nativeCurrency: { name: "REACT", symbol: "REACT", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://lasna-rpc.rnk.dev/"] },
  },
  blockExplorers: {
    default: { name: "Reactscan", url: "https://lasna.reactscan.net" },
  },
  testnet: true,
});
