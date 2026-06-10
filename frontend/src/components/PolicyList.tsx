"use client";

import { useAccount } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { Card } from "@/components/ui/Card";
import { Pill } from "@/components/ui/Pill";
import { EmptyState } from "@/components/ui/EmptyState";
import { usePoliciesForOwner } from "@/hooks/usePolicies";
import {
  fmtToken,
  fmtBps,
  statusLabel,
  statusColor,
  type PolicyStatus,
} from "@/lib/format";
import type { Policy } from "@/lib/types";

function PolicyCard({ id, policy }: { id: bigint; policy: Policy }) {
  return (
    <div className="rounded-[16px] border border-border bg-bg p-5 transition-colors hover:border-border-hover">
      <div className="mb-4 flex items-center justify-between">
        <span className="tnum text-text-2" style={{ fontSize: 13, fontWeight: 700 }}>
          Policy #{id.toString()}
        </span>
        <Pill color={statusColor(policy.status as PolicyStatus)}>
          {statusLabel(policy.status as PolicyStatus)}
        </Pill>
      </div>
      <div className="grid grid-cols-2 gap-4">
        <Field label="Notional" value={fmtToken(policy.notional)} />
        <Field label="Deductible" value={fmtBps(policy.thresholdBps)} />
        <Field label="Max payout" value={fmtToken(policy.maxPayout)} />
        <Field label="Premium paid" value={fmtToken(policy.premiumPaid)} accent />
      </div>
    </div>
  );
}

function Field({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent?: boolean;
}) {
  return (
    <div>
      <div
        className="uppercase text-text-muted"
        style={{ fontSize: 10, fontWeight: 700, letterSpacing: "0.08em" }}
      >
        {label}
      </div>
      <div
        className="tnum"
        style={{
          fontSize: 18,
          fontWeight: 800,
          color: accent ? "var(--accent)" : "var(--text)",
        }}
      >
        {value}
      </div>
    </div>
  );
}

export function PolicyList() {
  const { isConnected } = useAccount();
  const { policies, isLoading } = usePoliciesForOwner();

  return (
    <Card title="Your policies" subtitle="Coverage held by the connected wallet">
      {!isConnected ? (
        <EmptyState
          title="Connect your wallet"
          body="Connect to see the IL policies you hold and their live status."
          action={<ConnectButton />}
        />
      ) : isLoading ? (
        <div className="space-y-3">
          {[0, 1].map((i) => (
            <div key={i} className="h-28 animate-pulse rounded-[16px] bg-white/5" />
          ))}
        </div>
      ) : policies.length === 0 ? (
        <EmptyState
          title="No policies yet"
          body="Create your first policy to start covering impermanent loss on this pool."
        />
      ) : (
        <div className="space-y-3">
          {policies.map(({ id, policy }) => (
            <PolicyCard key={id.toString()} id={id} policy={policy} />
          ))}
        </div>
      )}
    </Card>
  );
}
