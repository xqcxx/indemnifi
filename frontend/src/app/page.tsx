import Link from "next/link";
import { FeatureGrid } from "@/components/FeatureGrid";
import { Roadmap } from "@/components/Roadmap";
import { CTABand } from "@/components/CTABand";
import { VaultHealthPanel } from "@/components/VaultHealthPanel";
import { DashboardStats } from "@/components/DashboardStats";

export default function Home() {
  return (
    <div className="flex flex-col">
      {/* Hero */}
      <section className="noise relative overflow-hidden border-b border-border">
        <div className="mx-auto flex max-w-4xl flex-col items-center gap-6 px-7 py-20 text-center md:py-28">
          <span
            className="rounded-[20px] border px-4 py-1.5"
            style={{
              fontSize: 12,
              fontWeight: 700,
              color: "var(--accent)",
              background: "rgba(251,39,206,0.12)",
              borderColor: "rgba(251,39,206,0.3)",
            }}
          >
            Uniswap v4 Hook × Reactive Network
          </span>

          <h1
            className="text-white"
            style={{
              fontSize: "clamp(44px, 7vw, 72px)",
              fontWeight: 900,
              letterSpacing: "-0.04em",
              lineHeight: 1.05,
            }}
          >
            Insure your liquidity against
            <br />
            <span className="text-accent">impermanent loss.</span>
          </h1>

          <p
            className="max-w-[440px] text-white/50"
            style={{ fontSize: 17, fontWeight: 500, lineHeight: 1.6 }}
          >
            Indemnifi gives Uniswap v4 LPs an explicit, priced promise: if IL
            crosses your deductible, the vault pays out — automatically.
          </p>

          <div className="flex flex-wrap items-center justify-center gap-3">
            <Link href="/app" className="btn-primary px-8 py-3.5 text-base">
              Protect a position
            </Link>
            <Link href="/demo" className="btn-ghost px-8 py-3.5 text-base">
              Watch the demo
            </Link>
          </div>
        </div>
      </section>

      {/* Live stats bar (vault contract) */}
      <DashboardStats />

      {/* Vault health detail (live) */}
      <section className="mx-auto w-full max-w-7xl px-7 py-16">
        <VaultHealthPanel />
      </section>

      {/* Feature grid */}
      <section className="mx-auto w-full max-w-7xl px-7 pb-16">
        <h2
          className="mb-8 text-white"
          style={{ fontSize: 40, fontWeight: 900, letterSpacing: "-0.03em" }}
        >
          How it works
        </h2>
        <FeatureGrid />
      </section>

      {/* Roadmap / status */}
      <section className="mx-auto w-full max-w-7xl px-7 pb-16">
        <h2
          className="mb-8 text-white"
          style={{ fontSize: 40, fontWeight: 900, letterSpacing: "-0.03em" }}
        >
          Status
        </h2>
        <Roadmap />
      </section>

      {/* CTA band */}
      <section className="pb-20">
        <CTABand />
      </section>
    </div>
  );
}
