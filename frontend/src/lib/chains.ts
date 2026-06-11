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
  // Canonical Multicall3 — required for wagmi's useReadContracts batching.
  // Without it, batched reads can hang in "pending" and every stat shows 0.
  contracts: {
    multicall3: {
      address: "0xcA11bde05977b3631167028862bE2a173976CA11",
    },
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