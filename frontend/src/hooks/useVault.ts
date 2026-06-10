"use client";

import { useReadContracts } from "wagmi";
import { abis, addresses, isConfigured, CHAIN_ID } from "@/lib/contracts";
import type { VaultState } from "@/lib/types";

const vaultContract = (fn: string) => ({
  address: addresses.vault,
  abi: abis.vault,
  functionName: fn,
  chainId: CHAIN_ID,
}) as const;

// Live vault state; event hooks invalidate it on premium/claim events.
export function useVaultState() {
  const enabled = isConfigured();

  const query = useReadContracts({
    contracts: [
      vaultContract("totalAssets"),
      vaultContract("solvencyRatioBps"),
      vaultContract("totalPremiums"),
      vaultContract("totalClaimsPaid"),
      vaultContract("totalYieldEarned"),
      vaultContract("availableForClaims"),
    ],
    query: {
      enabled,
      refetchInterval: 12_000,
    },
  });

  const r = query.data;
  const value: VaultState | undefined = r
    ? {
        totalAssets: (r[0].result as bigint) ?? 0n,
        solvencyBps: (r[1].result as bigint) ?? 0n,
        totalPremiums: (r[2].result as bigint) ?? 0n,
        totalClaimsPaid: (r[3].result as bigint) ?? 0n,
        totalYieldEarned: (r[4].result as bigint) ?? 0n,
        availableForClaims: (r[5].result as bigint) ?? 0n,
      }
    : undefined;

  return {
    vault: value,
    isLoading: query.isLoading,
    isError: query.isError,
    configured: enabled,
    refetch: query.refetch,
  };
}
