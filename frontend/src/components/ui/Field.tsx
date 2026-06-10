import { cn } from "@/lib/cn";
import type { InputHTMLAttributes, ReactNode } from "react";

export function Label({ children }: { children: ReactNode }) {
  return (
    <label
      className="mb-2 block uppercase text-text-muted"
      style={{ fontSize: 11, fontWeight: 700, letterSpacing: "0.08em" }}
    >
      {children}
    </label>
  );
}

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  suffix?: string;
}

export function Input({ suffix, className, ...props }: InputProps) {
  return (
    <div className="relative">
      <input
        className={cn(
          "tnum w-full rounded-[14px] border border-border bg-bg px-4 py-3 text-white outline-none transition-colors focus:border-border-hover",
          className,
        )}
        style={{ fontSize: 16, fontWeight: 700 }}
        {...props}
      />
      {suffix && (
        <span
          className="absolute right-4 top-1/2 -translate-y-1/2 text-text-muted"
          style={{ fontSize: 13, fontWeight: 700 }}
        >
          {suffix}
        </span>
      )}
    </div>
  );
}

interface SliderProps {
  value: number;
  min: number;
  max: number;
  step: number;
  onChange: (v: number) => void;
}

export function Slider({ value, min, max, step, onChange }: SliderProps) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <input
      type="range"
      value={value}
      min={min}
      max={max}
      step={step}
      onChange={(e) => onChange(Number(e.target.value))}
      className="h-1.5 w-full cursor-pointer appearance-none rounded-full outline-none"
      style={{
        background: `linear-gradient(to right, var(--accent) 0%, var(--accent) ${pct}%, rgba(255,255,255,0.12) ${pct}%, rgba(255,255,255,0.12) 100%)`,
      }}
    />
  );
}
