import { cn } from "@/lib/cn";
import type { ReactNode } from "react";

interface PillProps {
  children: ReactNode;
  color?: string; // text + dot color
  className?: string;
}

/** Small status pill with a colored dot — used for policy status, tiers, etc. */
export function Pill({ children, color = "var(--text-2)", className }: PillProps) {
  return (
    <span
      className={cn("inline-flex items-center gap-1.5 rounded-[20px] px-2.5 py-1", className)}
      style={{
        fontSize: 11,
        fontWeight: 700,
        letterSpacing: "0.02em",
        color,
        background: "rgba(255,255,255,0.06)",
      }}
    >
      <span className="h-1.5 w-1.5 rounded-full" style={{ background: color }} />
      {children}
    </span>
  );
}
