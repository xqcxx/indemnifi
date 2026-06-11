"use client";

import { Card } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { Tag } from "@/components/ui/Tag";
import { SolvencyBar } from "@/components/ui/SolvencyBar";
import { useVaultState } from "@/hooks/useVault";
import { fmtToken } from "@/lib/format";

export function VaultHealthPanel() {
  const { vault, isLoading } = useVaultState();
  const empty = (vault?.totalAssets ?? 0n) === 0n;

  return (
    <Card
      eyebrow={<Tag tone="green">Insurance vault</Tag>}
      title="Vault health"
      subtitle="Premiums back every policy and earn yield while idle"
      right={
        <span className="inline-flex items-center gap-1.5 text-success" style={{ fontSize: 12, fontWeight: 700 }}>
          <span className="pulse-dot h-1.5 w-1.5 rounded-full bg-success" />
          {isLoading ? "syncing" : "live"}
        </span>
      }
    >
      <div className="grid grid-cols-2 gap-6 md:grid-cols-4">
        <Stat label="Total assets" value={fmtToken(vault?.totalAssets ?? 0n)} />
        <Stat label="Premiums in" value={fmtToken(vault?.totalPremiums ?? 0n)} accent />
        <Stat label="Claims paid" value={fmtToken(vault?.totalClaimsPaid ?? 0n)} />
        <Stat
          label="Yield earned"
          value={fmtToken(vault?.totalYieldEarned ?? 0n)}
          valueColor="var(--success)"
        />
      </div>
      <div className="mt-6">
        <SolvencyBar bps={Number(vault?.solvencyBps ?? 0n)} />
      </div>
      {empty && (
        <div className="mt-6 rounded-[16px] border border-border bg-bg p-5">
          <div className="mb-4">
            <div className="text-white" style={{ fontSize: 15, fontWeight: 900 }}>
              Demo reserve model
            </div>
            <p className="mt-1 text-text-muted" style={{ fontSize: 13, fontWeight: 500, lineHeight: 1.55 }}>
              The live vault is connected but currently empty on this deployment. The scenario runner uses this reserve model to show how premiums, claims, and solvency move during the demo.
            </p>
          </div>
          <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
            <Stat label="Seed reserves" value="8.5 WETH" />
            <Stat label="Premium in" value="0.15 WETH" accent />
            <Stat label="Claim capacity" value="1 WETH" />
            <Stat label="Solvency" value="100%+" valueColor="var(--success)" />
          </div>
        </div>
      )}
    </Card>
  );
}
