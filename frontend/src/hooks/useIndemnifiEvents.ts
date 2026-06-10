"use client";

import { useState, useCallback } from "react";
import { useWatchContractEvent } from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { abis, addresses, isConfigured, CHAIN_ID } from "@/lib/contracts";

export interface FeedEvent {
  id: string;
  kind:
    | "PolicyCreated"
    | "ClaimPaid"
    | "RiskTierChanged"
    | "PremiumRateUpdated"
    | "CoveragePaused"
    | "CoverageResumed"
    | "SwapObserved";
  label: string;
  detail: string;
  ts: number;
}

const tierName = (t: number) => (["CALM", "VOLATILE", "SHOCK"] as const)[t] ?? "?";

// Watches core hook events: feeds the activity log, invalidates reads, toasts.
export function useIndemnifiEvents(max = 25) {
  const qc = useQueryClient();
  const [feed, setFeed] = useState<FeedEvent[]>([]);
  const enabled = isConfigured();

  const push = useCallback(
    (e: Omit<FeedEvent, "id" | "ts">) => {
      setFeed((prev) =>
        [{ ...e, id: `${Date.now()}-${Math.random()}`, ts: Date.now() }, ...prev].slice(
          0,
          max,
        ),
      );
      // Any state-changing event should refresh on-chain reads.
      qc.invalidateQueries();
    },
    [qc, max],
  );

  useWatchContractEvent({
    address: addresses.hook,
    abi: abis.hook,
    eventName: "PolicyCreated",
    chainId: CHAIN_ID,
    enabled,
    onLogs: (logs) => {
      logs.forEach(() =>
        push({
          kind: "PolicyCreated",
          label: "Policy created",
          detail: "A new LP bought IL coverage",
        }),
      );
      toast.success("New policy created");
    },
  });

  useWatchContractEvent({
    address: addresses.hook,
    abi: abis.hook,
    eventName: "ClaimPaid",
    chainId: CHAIN_ID,
    enabled,
    onLogs: (logs) => {
      logs.forEach(() =>
        push({
          kind: "ClaimPaid",
          label: "Claim paid",
          detail: "The vault settled an IL claim",
        }),
      );
      toast.success("Claim paid from vault");
    },
  });

  useWatchContractEvent({
    address: addresses.hook,
    abi: abis.hook,
    eventName: "RiskTierChanged",
    chainId: CHAIN_ID,
    enabled,
    onLogs: (logs) => {
      for (const log of logs) {
        const a = (log as unknown as { args?: { newTier?: number } }).args;
        push({
          kind: "RiskTierChanged",
          label: "Risk tier changed",
          detail: `Pool moved to ${tierName(a?.newTier ?? 0)}`,
        });
      }
      toast.message("Pool risk tier updated by Reactive");
    },
  });

  useWatchContractEvent({
    address: addresses.hook,
    abi: abis.hook,
    eventName: "PremiumRateUpdated",
    chainId: CHAIN_ID,
    enabled,
    onLogs: () =>
      push({
        kind: "PremiumRateUpdated",
        label: "Premium repriced",
        detail: "Reactive adjusted the premium rate",
      }),
  });

  useWatchContractEvent({
    address: addresses.hook,
    abi: abis.hook,
    eventName: "CoveragePaused",
    chainId: CHAIN_ID,
    enabled,
    onLogs: () => {
      push({
        kind: "CoveragePaused",
        label: "Coverage paused",
        detail: "New policies paused on low solvency",
      });
      toast.warning("Coverage paused for the pool");
    },
  });

  useWatchContractEvent({
    address: addresses.hook,
    abi: abis.hook,
    eventName: "CoverageResumed",
    chainId: CHAIN_ID,
    enabled,
    onLogs: () =>
      push({
        kind: "CoverageResumed",
        label: "Coverage resumed",
        detail: "Vault recovered — policies open again",
      }),
  });

  return { feed, configured: enabled };
}
