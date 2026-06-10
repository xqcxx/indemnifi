// Display helpers. Monetary/percent values render mono + tabular-nums.

export type RiskTier = 0 | 1 | 2; // CALM | VOLATILE | SHOCK
export type PolicyStatus = 0 | 1 | 2 | 3 | 4; // ACTIVE | PENDING_CLAIM | PAID | EXPIRED | CANCELLED

const num = new Intl.NumberFormat("en-US", { maximumFractionDigits: 4 });

// Format a token amount (premium token = WETH, 18 decimals).
export function fmtToken(amount: bigint, decimals = 18, symbol = "WETH"): string {
  const n = Number(amount) / 10 ** decimals;
  return `${num.format(n)} ${symbol}`;
}

/** Basis points -> "1.50%". */
export function fmtBps(bps: bigint | number): string {
  const v = typeof bps === "bigint" ? Number(bps) : bps;
  return `${(v / 100).toFixed(2)}%`;
}

/** Fraction (0..1) or already-percent number -> "x.x%". */
export function fmtPct(value: number, digits = 1): string {
  return `${(value * 100).toFixed(digits)}%`;
}

/** Truncate an address: 0x1234…abcd */
export function fmtAddr(addr?: string): string {
  if (!addr) return "—";
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

export const tierLabel = (t: RiskTier): "CALM" | "VOLATILE" | "SHOCK" =>
  (["CALM", "VOLATILE", "SHOCK"] as const)[t];

// CALM -> success, VOLATILE -> warning, SHOCK -> accent (magenta = top attention).
export const tierColor = (t: RiskTier): string =>
  t === 0 ? "var(--success)" : t === 1 ? "var(--warning)" : "var(--accent)";

export const tierTone = (t: RiskTier): "green" | "amber" | "pink" =>
  t === 0 ? "green" : t === 1 ? "amber" : "pink";

export const statusLabel = (s: PolicyStatus): string =>
  (["ACTIVE", "PENDING CLAIM", "PAID", "EXPIRED", "CANCELLED"] as const)[s];

export const statusColor = (s: PolicyStatus): string => {
  switch (s) {
    case 0: return "var(--info)";     // ACTIVE
    case 1: return "var(--warning)";  // PENDING_CLAIM
    case 2: return "var(--success)";  // PAID
    default: return "var(--text-muted)"; // EXPIRED / CANCELLED
  }
};

/** Solvency bps -> bar color by the contract thresholds (70% / 85%). */
export function solvencyColor(bps: bigint | number): string {
  const v = typeof bps === "bigint" ? Number(bps) : bps;
  if (v >= 8500) return "var(--success)";
  if (v >= 7000) return "var(--warning)";
  return "var(--accent)";
}
