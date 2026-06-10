import { Tag } from "@/components/ui/Tag";

type Tone = "pink" | "green" | "blue" | "amber";

interface Feature {
  tag: string;
  tone: Tone;
  title: string;
  body: string;
}

const features: Feature[] = [
  {
    tag: "Uniswap v4 Hook",
    tone: "pink",
    title: "Coverage at the pool",
    body: "Attach a policy when you add liquidity. The hook records your entry price, deductible and cap, and prices the premium by current pool risk.",
  },
  {
    tag: "Yield Vault",
    tone: "green",
    title: "Premiums that earn",
    body: "Premiums pool into the insurance vault and route idle capital into an ERC-4626 yield source — Aave v3 / Morpho in production.",
  },
  {
    tag: "Reactive Network",
    tone: "blue",
    title: "Automated settlement",
    body: "A Reactive Smart Contract on Lasna watches swaps, raises premiums on volatility, and settles your claim the moment you exit.",
  },
  {
    tag: "Transparent",
    tone: "amber",
    title: "Every number on-chain",
    body: "Premium, deductible, payout and vault solvency are read live from the contracts. Nothing hidden, nothing off-chain.",
  },
];

/** 2×2 grid with 1px gap created by the parent background showing through. */
export function FeatureGrid() {
  return (
    <div
      className="grid grid-cols-1 gap-px overflow-hidden rounded-[20px] md:grid-cols-2"
      style={{ background: "var(--border)" }}
    >
      {features.map((f) => (
        <div
          key={f.title}
          className="bg-bg p-8 transition-all duration-150 hover:bg-surface"
        >
          <Tag tone={f.tone}>{f.tag}</Tag>
          <h3
            className="mt-4 text-white"
            style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-0.02em" }}
          >
            {f.title}
          </h3>
          <p
            className="mt-2 text-white/45"
            style={{ fontSize: 14, fontWeight: 500, lineHeight: 1.65 }}
          >
            {f.body}
          </p>
        </div>
      ))}
    </div>
  );
}
