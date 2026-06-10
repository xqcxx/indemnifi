import { VaultHealthPanel } from "@/components/VaultHealthPanel";
import { EventFeed } from "@/components/EventFeed";
import { ReactiveStatus } from "@/components/ReactiveStatus";

export default function VaultPage() {
  return (
    <div className="mx-auto max-w-7xl px-7 py-12">
      <header className="mb-10">
        <h1
          className="text-white"
          style={{ fontSize: 44, fontWeight: 900, letterSpacing: "-0.03em" }}
        >
          Vault
        </h1>
        <p className="mt-2 text-text-2" style={{ fontSize: 16, fontWeight: 500 }}>
          Premiums pool here and back every policy. Capital earns yield while
          idle; solvency is read live and gates new coverage.
        </p>
      </header>

      <div className="flex flex-col gap-6">
        <VaultHealthPanel />
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <EventFeed />
          <ReactiveStatus />
        </div>
      </div>
    </div>
  );
}
