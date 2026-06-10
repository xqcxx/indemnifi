"use client";

import { useAccount, useSwitchChain } from "wagmi";
import { CHAIN_ID } from "@/lib/contracts";

/** Shows the active network; warns + offers a one-click switch when the wallet
 *  is on the wrong chain. Renders a neutral "Unichain Sepolia" label otherwise. */
export function NetworkBadge() {
  const { chainId, isConnected } = useAccount();
  const { switchChain, isPending } = useSwitchChain();

  const wrong = isConnected && chainId !== CHAIN_ID;

  if (wrong) {
    return (
      <button
        onClick={() => switchChain({ chainId: CHAIN_ID })}
        disabled={isPending}
        className="inline-flex items-center gap-1.5 rounded-[20px] px-3 py-1.5 disabled:opacity-60"
        style={{
          fontSize: 12,
          fontWeight: 700,
          color: "var(--accent)",
          background: "rgba(251,39,206,0.12)",
          border: "1px solid rgba(251,39,206,0.3)",
        }}
      >
        Wrong network — switch
      </button>
    );
  }

  return (
    <span
      className="hidden items-center gap-1.5 rounded-[20px] bg-white/8 px-3 py-1.5 text-white sm:inline-flex"
      style={{ fontSize: 12, fontWeight: 700 }}
    >
      <span className="pulse-dot h-1.5 w-1.5 rounded-full bg-success" />
      Unichain Sepolia
    </span>
  );
}
