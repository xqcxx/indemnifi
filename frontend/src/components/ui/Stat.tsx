import { cn } from "@/lib/cn";

interface StatProps {
  label: string;
  value: string;
  sub?: string;
  accent?: boolean;
  valueColor?: string;
  align?: "left" | "center";
  className?: string;
}

export function Stat({
  label,
  value,
  sub,
  accent,
  valueColor,
  align = "left",
  className,
}: StatProps) {
  const color = valueColor ?? (accent ? "var(--accent)" : "var(--text)");
  return (
    <div
      className={cn(
        "flex flex-col gap-1.5",
        align === "center" && "items-center text-center",
        className,
      )}
    >
      <span
        className="uppercase text-text-muted"
        style={{ fontSize: 11, fontWeight: 700, letterSpacing: "0.08em" }}
      >
        {label}
      </span>
      <span
        className="tnum"
        style={{ fontSize: 40, fontWeight: 900, letterSpacing: "-0.03em", color }}
      >
        {value}
      </span>
      {sub && (
        <span className="text-text-2" style={{ fontSize: 13, fontWeight: 500 }}>
          {sub}
        </span>
      )}
    </div>
  );
}
