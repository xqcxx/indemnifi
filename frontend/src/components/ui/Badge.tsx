import { cn } from "@/lib/cn";
import type { ReactNode } from "react";

type Tone = "live" | "soon" | "future";

const tones: Record<Tone, { color: string; bg: string; border: string }> = {
  live: {
    color: "var(--success)",
    bg: "rgba(34,197,94,0.12)",
    border: "rgba(34,197,94,0.25)",
  },
  soon: {
    color: "var(--accent)",
    bg: "rgba(251,39,206,0.12)",
    border: "rgba(251,39,206,0.25)",
  },
  future: {
    color: "rgba(255,255,255,0.4)",
    bg: "rgba(255,255,255,0.06)",
    border: "rgba(255,255,255,0.1)",
  },
};

interface BadgeProps {
  children: ReactNode;
  tone?: Tone;
  className?: string;
}

/** Right-side status badge (LIVE / SOON / FUTURE, or policy status). */
export function Badge({ children, tone = "live", className }: BadgeProps) {
  const t = tones[tone];
  return (
    <span
      className={cn("inline-flex items-center rounded-[20px] px-3.5 py-1 uppercase", className)}
      style={{
        fontSize: 11,
        fontWeight: 700,
        letterSpacing: "0.04em",
        color: t.color,
        backgroundColor: t.bg,
        border: `1px solid ${t.border}`,
      }}
    >
      {children}
    </span>
  );
}
