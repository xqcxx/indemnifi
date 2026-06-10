import { solvencyColor } from "@/lib/format";

interface SolvencyBarProps {
  bps: number;
  showLabel?: boolean;
}

// Solvency bar; color shifts at the contract thresholds (70% pause, 85% resume).
export function SolvencyBar({ bps, showLabel = true }: SolvencyBarProps) {
  const pct = Math.max(0, Math.min(100, bps / 100));
  const color = solvencyColor(bps);
  const label = bps >= 10_000 ? "100%+" : `${(bps / 100).toFixed(0)}%`;
  return (
    <div className="flex flex-col gap-2">
      {showLabel && (
        <div className="flex items-center justify-between">
          <span
            className="uppercase text-text-muted"
            style={{ fontSize: 11, fontWeight: 700, letterSpacing: "0.08em" }}
          >
            Vault solvency
          </span>
          <span className="tnum" style={{ fontWeight: 800, color }}>
            {label}
          </span>
        </div>
      )}
      <div className="h-2 w-full overflow-hidden rounded-full bg-white/8">
        <div
          className="h-full rounded-full transition-all duration-500"
          style={{ width: `${pct}%`, backgroundColor: color }}
        />
      </div>
    </div>
  );
}
