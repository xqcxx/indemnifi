"use client";

import { Card } from "@/components/ui/Card";
import { useIndemnifiEvents } from "@/hooks/useIndemnifiEvents";

const dotColor: Record<string, string> = {
  PolicyCreated: "var(--info)",
  ClaimPaid: "var(--success)",
  RiskTierChanged: "var(--warning)",
  PremiumRateUpdated: "var(--warning)",
  CoveragePaused: "var(--accent)",
  CoverageResumed: "var(--success)",
  SwapObserved: "var(--text-muted)",
};

// Live activity log driven by on-chain hook events.
export function EventFeed() {
  const { feed } = useIndemnifiEvents();

  return (
    <Card
      title="Live activity"
      right={
        <span className="inline-flex items-center gap-1.5 text-success" style={{ fontSize: 12, fontWeight: 700 }}>
          <span className="pulse-dot h-1.5 w-1.5 rounded-full bg-success" />
          watching chain
        </span>
      }
    >
      {feed.length === 0 ? (
        <p className="text-text-muted" style={{ fontSize: 14, fontWeight: 500 }}>
          Waiting for the next on-chain event…
        </p>
      ) : (
        <ul className="space-y-3">
          {feed.map((e) => (
            <li key={e.id} className="flex items-start gap-3">
              <span
                className="mt-1.5 h-2 w-2 shrink-0 rounded-full"
                style={{ background: dotColor[e.kind] ?? "var(--text-muted)" }}
              />
              <div>
                <div className="text-white" style={{ fontSize: 14, fontWeight: 800 }}>
                  {e.label}
                </div>
                <div className="text-text-2" style={{ fontSize: 13, fontWeight: 500 }}>
                  {e.detail}
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}
