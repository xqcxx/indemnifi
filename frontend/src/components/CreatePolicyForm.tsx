"use client";

import { useState } from "react";
import { parseUnits } from "viem";
import { useAccount } from "wagmi";
import { Card } from "@/components/ui/Card";
import { Label, Input, Slider } from "@/components/ui/Field";
import { Button } from "@/components/ui/Button";
import { usePoolRisk, usePremiumQuote } from "@/hooks/usePool";
import { usePoliciesForOwner } from "@/hooks/usePolicies";
import { useCreatePolicy } from "@/hooks/useCreatePolicy";
import { fmtToken, fmtBps } from "@/lib/format";

export function CreatePolicyForm() {
  const { isConnected } = useAccount();
  const { paused } = usePoolRisk();
  const { refetch } = usePoliciesForOwner();
  const { create, phase } = useCreatePolicy();

  const [notionalStr, setNotionalStr] = useState("1");
  const [thresholdBps, setThresholdBps] = useState(500);
  const [maxPayoutStr, setMaxPayoutStr] = useState("1");

  const safeParse = (s: string): bigint => {
    try {
      return parseUnits(s || "0", 18);
    } catch {
      return 0n;
    }
  };
  const notional = safeParse(notionalStr);
  const maxPayout = safeParse(maxPayoutStr);

  const { premium, isLoading: premiumLoading, isError: premiumError } = usePremiumQuote(notional);

  const busy = phase === "approving" || phase === "creating";
  const disabled =
    !isConnected || paused || notional === 0n || premiumLoading || premium === 0n || busy;

  const onSubmit = async () => {
    const ok = await create({
      notional,
      thresholdBps: BigInt(thresholdBps),
      maxPayout,
      expiry: 0n,
      premium,
    });
    if (ok) refetch();
  };

  return (
    <Card title="Protect a position" subtitle="Buy IL coverage for your liquidity">
      <div className="flex flex-col gap-6">
        <div>
          <Label>Notional (position value)</Label>
          <Input
            value={notionalStr}
            onChange={(e) => setNotionalStr(e.target.value.replace(/[^0-9.]/g, ""))}
            suffix="WETH"
            inputMode="decimal"
          />
        </div>

        <div>
          <Label>Deductible — {fmtBps(thresholdBps)}</Label>
          <Slider value={thresholdBps} min={100} max={2000} step={50} onChange={setThresholdBps} />
          <p className="mt-2 text-text-muted" style={{ fontSize: 12, fontWeight: 500 }}>
            IL below the deductible is uninsured. Lower deductible = more coverage.
          </p>
        </div>

        <div>
          <Label>Max payout (cap)</Label>
          <Input
            value={maxPayoutStr}
            onChange={(e) => setMaxPayoutStr(e.target.value.replace(/[^0-9.]/g, ""))}
            suffix="WETH"
            inputMode="decimal"
          />
        </div>

        <div className="flex items-center justify-between rounded-[14px] border border-border bg-bg px-4 py-3">
          <span className="uppercase text-text-muted" style={{ fontSize: 11, fontWeight: 700, letterSpacing: "0.08em" }}>
            Premium due
          </span>
          <span className="tnum text-accent" style={{ fontSize: 20, fontWeight: 900 }}>
            {premiumLoading ? "quoting..." : fmtToken(premium)}
          </span>
        </div>

        {premiumError && (
          <p className="rounded-[12px] bg-white/5 px-3 py-2 text-text-muted" style={{ fontSize: 12, fontWeight: 600 }}>
            Premium quote is not available yet. Hard-refresh or verify the wallet is on Unichain Sepolia.
          </p>
        )}

        <Button onClick={onSubmit} disabled={disabled} loading={busy} size="lg">
          {phase === "approving"
            ? "Approving…"
            : phase === "creating"
              ? "Creating policy…"
              : premiumLoading
                ? "Quoting premium…"
              : paused
                ? "Coverage paused"
                : !isConnected
                  ? "Connect wallet to protect"
                  : "Create policy"}
        </Button>
      </div>
    </Card>
  );
}
