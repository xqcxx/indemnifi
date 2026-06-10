import type { ReactNode } from "react";

export function EmptyState({
  title,
  body,
  action,
}: {
  title: string;
  body: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 rounded-[16px] border border-dashed border-border px-6 py-12 text-center">
      <h4 className="text-white" style={{ fontSize: 18, fontWeight: 800 }}>
        {title}
      </h4>
      <p className="max-w-sm text-text-2" style={{ fontSize: 14, fontWeight: 500 }}>
        {body}
      </p>
      {action}
    </div>
  );
}
