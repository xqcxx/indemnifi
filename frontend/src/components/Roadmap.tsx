import { StatusDot } from "@/components/ui/StatusDot";
import { Badge } from "@/components/ui/Badge";

type Status = "live" | "soon" | "future";

interface Row {
  title: string;
  desc: string;
  status: Status;
}

const rows: Row[] = [
  {
    title: "IL insurance hook + vault",
    desc: "createPolicy, premium pricing, claim settlement, yield-bearing reserves.",
    status: "live",
  },
  {
    title: "Reactive risk monitor",
    desc: "Swap-driven premium re-pricing and automated claim settlement on Lasna.",
    status: "live",
  },
  {
    title: "Live on-chain dashboard",
    desc: "Real-time vault solvency, policy list and event feed via wagmi.",
    status: "soon",
  },
  {
    title: "Production yield routing",
    desc: "Swap the mock yield vault for audited production reserve strategies.",
    status: "future",
  },
];

const label: Record<Status, string> = { live: "Live", soon: "Soon", future: "Future" };

export function Roadmap() {
  return (
    <div className="overflow-hidden rounded-[16px] border border-border">
      {rows.map((r, i) => (
        <div
          key={r.title}
          className="flex items-center justify-between gap-4 px-6 py-5"
          style={{
            borderBottom: i < rows.length - 1 ? "1px solid var(--border)" : undefined,
          }}
        >
          <div className="flex items-center gap-4">
            <StatusDot status={r.status} pulse={r.status === "live"} />
            <div>
              <div className="text-white" style={{ fontSize: 16, fontWeight: 800 }}>
                {r.title}
              </div>
              <div
                className="text-white/40"
                style={{ fontSize: 13, fontWeight: 500 }}
              >
                {r.desc}
              </div>
            </div>
          </div>
          <Badge tone={r.status}>{label[r.status]}</Badge>
        </div>
      ))}
    </div>
  );
}
