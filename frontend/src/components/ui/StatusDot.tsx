type Status = "live" | "soon" | "future";

const map: Record<Status, { bg: string; ring: string }> = {
  live: { bg: "var(--success)", ring: "rgba(34,197,94,0.2)" },
  soon: { bg: "var(--accent)", ring: "rgba(251,39,206,0.2)" },
  future: { bg: "rgba(255,255,255,0.2)", ring: "transparent" },
};

export function StatusDot({ status, pulse }: { status: Status; pulse?: boolean }) {
  const m = map[status];
  return (
    <span
      className={pulse ? "pulse-dot" : undefined}
      style={{
        display: "inline-block",
        width: 8,
        height: 8,
        borderRadius: "9999px",
        backgroundColor: m.bg,
        boxShadow: `0 0 0 3px ${m.ring}`,
      }}
    />
  );
}
