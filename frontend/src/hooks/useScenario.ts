"use client";

import { useCallback, useState } from "react";
import {
  useChainId,
  usePublicClient,
  useReadContract,
  useSwitchChain,
  useWriteContract,
} from "wagmi";
import { toast } from "sonner";
import { abis, addresses, isRunnerConfigured, CHAIN_ID } from "@/lib/contracts";
import type { RunResult } from "@/lib/types";

// Last on-chain scenario result from DemoScenarioRunner.
export function useLastScenarioResult() {
  const enabled = isRunnerConfigured();
  const q = useReadContract({
    address: addresses.scenarioRunner,
    abi: abis.scenarioRunner,
    functionName: "getLastResult",
    chainId: CHAIN_ID,
    query: { enabled },
  });
  const ran = useReadContract({
    address: addresses.scenarioRunner,
    abi: abis.scenarioRunner,
    functionName: "ran",
    chainId: CHAIN_ID,
    query: { enabled },
  });
  return {
    result: q.data as RunResult | undefined,
    ran: (ran.data as boolean) ?? false,
    isLoading: q.isLoading,
    configured: enabled,
    refetch: q.refetch,
  };
}

// Run a scenario on-chain (0=CALM, 1=VOLATILE, 2=SHOCK). Owner-only.
export function useRunScenario() {
  const chainId = useChainId();
  const publicClient = usePublicClient({ chainId: CHAIN_ID });
  const { switchChainAsync } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();
  const [running, setRunning] = useState<number | null>(null);

  const run = useCallback(
    async (scenario: 0 | 1 | 2): Promise<boolean> => {
      if (!isRunnerConfigured()) {
        toast.error("Scenario runner address not configured");
        return false;
      }
      if (!publicClient) {
        toast.error("Connect your wallet first");
        return false;
      }
      try {
        setRunning(scenario);
        if (chainId !== CHAIN_ID) await switchChainAsync({ chainId: CHAIN_ID });
        const hash = await writeContractAsync({
          address: addresses.scenarioRunner,
          abi: abis.scenarioRunner,
          functionName: "runScenario",
          args: [scenario],
          chainId: CHAIN_ID,
        });
        toast.loading("Running scenario on-chain…", { id: "scenario" });
        await publicClient.waitForTransactionReceipt({ hash });
        toast.success("Scenario settled", { id: "scenario" });
        return true;
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : "Scenario run failed";
        toast.error(msg.length > 120 ? msg.slice(0, 120) + "…" : msg);
        return false;
      } finally {
        setRunning(null);
      }
    },
    [chainId, switchChainAsync, publicClient, writeContractAsync],
  );

  return { run, running };
}
