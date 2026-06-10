"use client";

import { StatsBar } from "@/components/StatsBar";
import { useVaultState } from "@/hooks/useVault";
import { fmtToken } from "@/lib/format";

export function DashboardStats() {
  const { vault } = useVaultState();
  const bps = Number(vault?.solvencyBps ?? 0n);
  const solvency = bps >= 10_000 ? "100%+" : `${(bps / 100).toFixed(0)}%`;

  return (
    <StatsBar
      cells={[
        { label: "Vault assets", value: fmtToken(vault?.totalAssets ?? 0n) },
        { label: "Solvency", value: solvency, accent: true },
        { label: "Yield earned", value: fmtToken(vault?.totalYieldEarned ?? 0n) },
      ]}
    />
  );
}
