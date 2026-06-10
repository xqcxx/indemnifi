"use client";

import { useState, useCallback } from "react";
import {
  useAccount,
  useChainId,
  usePublicClient,
  useSwitchChain,
  useWriteContract,
} from "wagmi";
import { toast } from "sonner";
import { erc20Abi } from "@/abis";
import {
  abis,
  addresses,
  getPoolKey,
  premiumToken,
  isConfigured,
  CHAIN_ID,
} from "@/lib/contracts";

export interface CreatePolicyArgs {
  notional: bigint;
  thresholdBps: bigint;
  maxPayout: bigint; // 0 = defaults to notional
  expiry: bigint; // 0 = no expiry
  premium: bigint; // quoted premium, sizes the approval
}

type Phase = "idle" | "approving" | "creating" | "done" | "error";

// Create-policy flow: ensure correct chain, approve premium token, createPolicy.
export function useCreatePolicy() {
  const { address } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient({ chainId: CHAIN_ID });
  const { switchChainAsync } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();
  const [phase, setPhase] = useState<Phase>("idle");

  const create = useCallback(
    async (args: CreatePolicyArgs): Promise<boolean> => {
      if (!isConfigured()) {
        toast.error("Contract addresses not configured");
        return false;
      }
      if (!address || !publicClient) {
        toast.error("Connect your wallet first");
        return false;
      }

      const token = premiumToken();
      const key = getPoolKey();

      try {
        if (chainId !== CHAIN_ID) await switchChainAsync({ chainId: CHAIN_ID });

        const allowance = (await publicClient.readContract({
          address: token,
          abi: erc20Abi,
          functionName: "allowance",
          args: [address, addresses.hook],
        })) as bigint;

        if (allowance < args.premium) {
          setPhase("approving");
          const approveHash = await writeContractAsync({
            address: token,
            abi: erc20Abi,
            functionName: "approve",
            args: [addresses.hook, args.premium],
            chainId: CHAIN_ID,
          });
          toast.loading("Approving premium token…", { id: "approve" });
          await publicClient.waitForTransactionReceipt({ hash: approveHash });
          toast.success("Approved", { id: "approve" });
        }

        setPhase("creating");
        const hash = await writeContractAsync({
          address: addresses.hook,
          abi: abis.hook,
          functionName: "createPolicy",
          args: [key, args.notional, args.thresholdBps, args.maxPayout, args.expiry],
          chainId: CHAIN_ID,
        });
        toast.loading("Creating policy…", { id: "create" });
        await publicClient.waitForTransactionReceipt({ hash });
        toast.success("Policy created — you're covered", { id: "create" });

        setPhase("done");
        return true;
      } catch (e: unknown) {
        setPhase("error");
        const msg = e instanceof Error ? e.message : "Transaction failed";
        toast.error(msg.length > 120 ? msg.slice(0, 120) + "…" : msg);
        return false;
      }
    },
    [address, chainId, switchChainAsync, publicClient, writeContractAsync],
  );

  return { create, phase, reset: () => setPhase("idle") };
}
