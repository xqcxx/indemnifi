"use client";

import { useEffect, useRef, useState } from "react";
import { Check } from "lucide-react";
import { Card } from "@/components/ui/Card";
import { Tag } from "@/components/ui/Tag";
import { Stat } from "@/components/ui/Stat";
import { ComparisonChart } from "@/components/ComparisonChart";
import { useRunScenario, useLastScenarioResult } from "@/hooks/useScenario";
import { fmtToken } from "@/lib/format";
import type { RunResult } from "@/lib/types";

const STEPS = [
  "Entry price set",
  "Alice adds uninsured liquidity",
  "Bob adds insured liquidity",
  "Bob premium enters vault",
  "Vault earns yield",
  "Market moves",
  "Reactive detects risk-state change",
  "Alice exits — absorbs full IL",
  "Bob exits — claim triggered by Reactive",
  "Claim settled from vault",
  "Final comparison ready",
];

const SCENARIOS = [
  { id: 0 as const, label: "Calm", tone: "green" as const, desc: "$2,000 → $2,080" },
  { id: 1 as const, label: "Volatile", tone: "amber" as const, desc: "$2,000 → $2,800" },
  { id: 2 as const, label: "Shock", tone: "pink" as const, desc: "$2,000 → $4,000" },
];

const f = (x: bigint) => Number(x) / 1e18;

export function ScenarioRunner() {
  const { run, running } = useRunScenario();
  const { result: chainResult, refetch } = useLastScenarioResult();

  const [activeStep, setActiveStep] = useState(-1);
  const [result, setResult] = useState<RunResult | null>(null);
  const [animating, setAnimating] = useState(false);
  const timers = useRef<ReturnType<typeof setTimeout>[]>([]);

  useEffect(() => () => timers.current.forEach(clearTimeout), []);

  const animate = (final: RunResult) => {
    setAnimating(true);
    setActiveStep(-1);
    setResult(null);
    timers.current.forEach(clearTimeout);
    timers.current = STEPS.map((_, i) =>
      setTimeout(() => {
        setActiveStep(i);
        if (i === STEPS.length - 1) {
          setResult(final);
          setAnimating(false);
        }
      }, (i + 1) * 320),
    );
  };

  const onRun = async (id: 0 | 1 | 2) => {
    const ok = await run(id);
    if (!ok) return;
    const { data } = await refetch();
    const r = (data as RunResult | undefined) ?? chainResult;
    if (r) animate(r);
  };

  return (
    <div className="flex flex-col gap-6">
      <Card
        eyebrow={<Tag tone="pink">Live demo</Tag>}
        title="Alice vs Bob — IL with and without coverage"
        subtitle="Runs on-chain via DemoScenarioRunner, then reads the settled result."
      >
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          {SCENARIOS.map((s) => (
            <button
              key={s.id}
              onClick={() => onRun(s.id)}
              disabled={animating || running !== null}
              className="rounded-[16px] border border-border bg-bg p-5 text-left transition-all duration-150 hover:border-border-hover disabled:opacity-50"
            >
              <Tag tone={s.tone}>{s.label}</Tag>
              <div className="tnum mt-3 text-white" style={{ fontSize: 16, fontWeight: 800 }}>
                {s.desc}
              </div>
              <div className="mt-1 text-text-muted" style={{ fontSize: 12, fontWeight: 600 }}>
                {running === s.id ? "running on-chain…" : "click to run"}
              </div>
            </button>
          ))}
        </div>
      </Card>

      {activeStep >= 0 && (
        <Card title="Settlement timeline">
          <ol className="space-y-2.5">
            {STEPS.map((step, i) => {
              const done = i <= activeStep;
              return (
                <li key={i} className="flex items-center gap-3">
                  <span
                    className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full transition-all duration-300"
                    style={{ background: done ? "var(--accent)" : "rgba(255,255,255,0.08)" }}
                  >
                    {done ? (
                      <Check className="h-3.5 w-3.5 text-white" strokeWidth={3} />
                    ) : (
                      <span className="tnum text-text-muted" style={{ fontSize: 11, fontWeight: 700 }}>
                        {i + 1}
                      </span>
                    )}
                  </span>
                  <span
                    style={{
                      fontSize: 14,
                      fontWeight: done ? 700 : 500,
                      color: done ? "var(--text)" : "var(--text-muted)",
                    }}
                  >
                    {step}
                  </span>
                </li>
              );
            })}
          </ol>
        </Card>
      )}

      {result && (
        <Card title="Result" subtitle="Bob's net outcome versus uninsured Alice">
          <div className="grid grid-cols-2 gap-6 md:grid-cols-4">
            <Stat label="IL incurred" value={fmtToken(result.aliceIL)} />
            <Stat label="Bob payout" value={fmtToken(result.bobPayout)} accent />
            <Stat label="Bob premium" value={fmtToken(result.bobPremium)} />
            <Stat
              label="Bob advantage"
              value={fmtToken(result.bobAdvantage)}
              valueColor={result.bobAdvantage > 0n ? "var(--success)" : "var(--warning)"}
            />
          </div>
          <div className="mt-8">
            <ComparisonChart
              aliceFinalLoss={f(result.aliceFinalLoss)}
              bobFinalLoss={f(result.bobFinalLoss)}
            />
          </div>
        </Card>
      )}
    </div>
  );
}
