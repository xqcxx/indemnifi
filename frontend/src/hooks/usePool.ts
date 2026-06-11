"use client";

import { useReadContract } from "wagmi";
import { abis, addresses, getPoolId, isConfigured, CHAIN_ID } from "@/lib/contracts";
import type { RiskTier } from "@/lib/format";

// Live risk tier, premium bps, and paused state for the pool.
export function usePoolRisk() {
  const enabled = isConfigured();
  const poolId = enabled ? getPoolId() : undefined;

  const tier = useReadContract({
    address: addresses.hook,
    abi: abis.hook,
    functionName: "getRiskTier",
    args: poolId ? [poolId] : undefined,
    chainId: CHAIN_ID,
    query: { enabled, refetchInterval: 12_000 },
  });

  const premiumBps = useReadContract({
    address: addresses.hook,
    abi: abis.hook,
    functionName: "getCurrentPremiumBps",
    args: poolId ? [poolId] : undefined,
    chainId: CHAIN_ID,
    query: { enabled, refetchInterval: 12_000 },
  });

  const paused = useReadContract({
    address: addresses.hook,
    abi: abis.hook,
    functionName: "isCoveragePaused",
    args: poolId ? [poolId] : undefined,
    chainId: CHAIN_ID,
    query: { enabled, refetchInterval: 12_000 },
  });

  return {
    poolId,
    tier: ((tier.data as number) ?? 0) as RiskTier,
    premiumBps: (premiumBps.data as bigint) ?? 0n,
    paused: (paused.data as boolean) ?? false,
    isLoading: tier.isLoading || premiumBps.isLoading || paused.isLoading,
    configured: enabled,
  };
}

// Live premium quote for a notional amount.
export function usePremiumQuote(notional: bigint) {
  const enabled = isConfigured() && notional > 0n;
  const poolId = isConfigured() ? getPoolId() : undefined;

  const q = useReadContract({
    address: addresses.hook,
    abi: abis.hook,
    functionName: "getPremiumForNotional",
    args: poolId ? [poolId, notional] : undefined,
    chainId: CHAIN_ID,
    query: { enabled },
  });

  return {
    premium: (q.data as bigint) ?? 0n,
    isLoading: q.isLoading,
    isError: q.isError,
  };
}
