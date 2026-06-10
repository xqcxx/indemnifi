"use client";

import { useAccount, useReadContract, useReadContracts } from "wagmi";
import { abis, addresses, isConfigured, CHAIN_ID } from "@/lib/contracts";
import { toPolicy, type Policy, type PolicyTuple } from "@/lib/types";

// Policies owned by the connected wallet, fully hydrated.
export function usePoliciesForOwner() {
  const { address } = useAccount();
  const enabled = isConfigured() && !!address;

  const ids = useReadContract({
    address: addresses.hook,
    abi: abis.hook,
    functionName: "getPoliciesForOwner",
    args: address ? [address] : undefined,
    chainId: CHAIN_ID,
    query: { enabled, refetchInterval: 15_000 },
  });

  const idList = (ids.data as bigint[] | undefined) ?? [];

  const policies = useReadContracts({
    contracts: idList.map((id) => ({
      address: addresses.hook,
      abi: abis.hook,
      functionName: "getPolicy",
      args: [id],
      chainId: CHAIN_ID,
    })),
    query: { enabled: enabled && idList.length > 0 },
  });

  const items: { id: bigint; policy: Policy }[] = (policies.data ?? [])
    .map((r, i) =>
      r.status === "success"
        ? { id: idList[i], policy: toPolicy(r.result as unknown as PolicyTuple) }
        : null,
    )
    .filter((x): x is { id: bigint; policy: Policy } => x !== null);

  return {
    policies: items,
    ids: idList,
    isLoading: ids.isLoading || policies.isLoading,
    configured: enabled,
    refetch: () => {
      ids.refetch();
      policies.refetch();
    },
  };
}

/** A single policy by id. */
export function usePolicy(id: bigint | undefined) {
  const enabled = isConfigured() && id !== undefined;
  const q = useReadContract({
    address: addresses.hook,
    abi: abis.hook,
    functionName: "getPolicy",
    args: id !== undefined ? [id] : undefined,
    chainId: CHAIN_ID,
    query: { enabled },
  });
  return {
    policy: q.data ? toPolicy(q.data as unknown as PolicyTuple) : undefined,
    isLoading: q.isLoading,
  };
}
