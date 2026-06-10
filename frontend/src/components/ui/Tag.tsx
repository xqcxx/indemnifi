import { cn } from "@/lib/cn";
import type { ReactNode } from "react";

type Tone = "pink" | "green" | "blue" | "amber" | "neutral";

const tones: Record<Tone, { color: string; bg: string }> = {
  pink: { color: "var(--accent)", bg: "rgba(251,39,206,0.10)" },
  green: { color: "var(--success)", bg: "rgba(34,197,94,0.10)" },
  blue: { color: "var(--info)", bg: "rgba(96,165,250,0.10)" },
  amber: { color: "var(--warning)", bg: "rgba(245,158,11,0.10)" },
  neutral: { color: "rgba(255,255,255,0.6)", bg: "rgba(255,255,255,0.06)" },
};

interface TagProps {
  children: ReactNode;
  tone?: Tone;
  className?: string;
}

/** Tinted eyebrow tag — uppercase, bold, rounded. */
export function Tag({ children, tone = "pink", className }: TagProps) {
  const t = tones[tone];
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-[10px] px-3 py-1 uppercase",
        className,
      )}
      style={{
        fontSize: 11,
        fontWeight: 700,
        letterSpacing: "0.06em",
        color: t.color,
        backgroundColor: t.bg,
      }}
    >
      {children}
    </span>
  );
}
