"use client";

import { useAccount, useChainId, useSwitchChain } from "wagmi";
import { CHAIN_ID } from "@/lib/contracts";

// Full-width banner shown when a connected wallet is on the wrong chain.
// Reads still work (they are pinned to Unichain Sepolia), but writes need the
// wallet on the right network.
export function NetworkGuard() {
  const { isConnected } = useAccount();
  const chainId = useChainId();
  const { switchChain, isPending } = useSwitchChain();

  if (!isConnected || chainId === CHAIN_ID) return null;

  return (
    <div className="w-full" style={{ background: "rgba(251,39,206,0.12)", borderBottom: "1px solid rgba(251,39,206,0.3)" }}>
      <div className="mx-auto flex max-w-7xl items-center justify-center gap-3 px-7 py-2 text-center">
        <span className="text-accent" style={{ fontSize: 13, fontWeight: 700 }}>
          You&apos;re on the wrong network. Switch to Unichain Sepolia to claim tokens and create policies.
        </span>
        <button
          onClick={() => switchChain({ chainId: CHAIN_ID })}
          disabled={isPending}
          className="btn-primary px-4 py-1 disabled:opacity-60"
          style={{ fontSize: 12 }}
        >
          {isPending ? "Switching…" : "Switch network"}
        </button>
      </div>
    </div>
  );
}
