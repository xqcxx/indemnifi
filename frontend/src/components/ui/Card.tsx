import { cn } from "@/lib/cn";
import type { ReactNode } from "react";

interface CardProps {
  eyebrow?: ReactNode;
  title?: string;
  subtitle?: string;
  right?: ReactNode;
  hover?: boolean;
  className?: string;
  children: ReactNode;
}

export function Card({
  eyebrow,
  title,
  subtitle,
  right,
  hover = false,
  className,
  children,
}: CardProps) {
  return (
    <div
      className={cn(
        "card p-7 md:p-8",
        hover && "hover:border-border-hover",
        className,
      )}
    >
      {(title || right || eyebrow) && (
        <div className="mb-5 flex items-start justify-between gap-4">
          <div>
            {eyebrow && <div className="mb-2">{eyebrow}</div>}
            {title && (
              <h3
                className="text-white"
                style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-0.02em" }}
              >
                {title}
              </h3>
            )}
            {subtitle && (
              <p
                className="mt-1 text-text-2"
                style={{ fontSize: 13, fontWeight: 500 }}
              >
                {subtitle}
              </p>
            )}
          </div>
          {right}
        </div>
      )}
      {children}
    </div>
  );
}
