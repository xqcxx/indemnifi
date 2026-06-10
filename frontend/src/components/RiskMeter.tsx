"use client";

import { Card } from "@/components/ui/Card";
import { Tag } from "@/components/ui/Tag";
import { usePoolRisk } from "@/hooks/usePool";
import { fmtBps, tierLabel, tierColor, tierTone, type RiskTier } from "@/lib/format";

const tiers: RiskTier[] = [0, 1, 2];

export function RiskMeter() {
  const { tier: active, premiumBps: bps, paused } = usePoolRisk();

  return (
    <Card
      eyebrow={<Tag tone={tierTone(active)}>Pool risk · {tierLabel(active)}</Tag>}
      title="Current premium"
      right={
        <span
          className="tnum"
          style={{ fontSize: 28, fontWeight: 900, color: tierColor(active) }}
        >
          {fmtBps(bps)}
        </span>
      }
    >
      <div className="flex gap-1.5">
        {tiers.map((t) => (
          <div
            key={t}
            className="h-2 flex-1 rounded-full transition-colors"
            style={{
              backgroundColor: t <= active ? tierColor(active) : "rgba(255,255,255,0.10)",
            }}
          />
        ))}
      </div>
      <div className="mt-3 flex justify-between text-text-muted" style={{ fontSize: 12, fontWeight: 600 }}>
        <span>CALM 1.5%</span>
        <span>VOLATILE 3%</span>
        <span>SHOCK 7%</span>
      </div>
      {paused && (
        <p className="mt-4 rounded-[12px] px-3 py-2" style={{ fontSize: 13, fontWeight: 700, color: "var(--accent)", background: "rgba(251,39,206,0.10)" }}>
          Coverage is paused — vault solvency is low. New policies are disabled.
        </p>
      )}
    </Card>
  );
}
