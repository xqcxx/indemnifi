import { Card } from "@/components/ui/Card";
import { Tag } from "@/components/ui/Tag";

export function ReactiveStatus() {
  return (
    <Card eyebrow={<Tag tone="blue">Reactive Network</Tag>} title="Automated by Lasna">
      <p className="text-text-2" style={{ fontSize: 14, fontWeight: 500, lineHeight: 1.65 }}>
        A Reactive Smart Contract on Reactive Lasna (chain 5318007) subscribes to
        this pool&apos;s swap and exit events. It re-prices premiums on volatility
        and settles claims by calling back into the hook on Unichain Sepolia —
        no keeper, no manual settlement.
      </p>
      <div className="mt-4 inline-flex items-center gap-2 rounded-[20px] bg-white/8 px-3 py-1.5 text-white" style={{ fontSize: 12, fontWeight: 700 }}>
        <span className="pulse-dot h-1.5 w-1.5 rounded-full bg-info" />
        Monitoring live
      </div>
    </Card>
  );
}
