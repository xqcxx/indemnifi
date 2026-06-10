import { ScenarioRunner } from "@/components/ScenarioRunner";

export default function DemoPage() {
  return (
    <div className="mx-auto max-w-7xl px-7 py-12">
      <header className="mb-10">
        <h1
          className="text-white"
          style={{ fontSize: 44, fontWeight: 900, letterSpacing: "-0.03em" }}
        >
          Demo
        </h1>
        <p className="mt-2 max-w-2xl text-text-2" style={{ fontSize: 16, fontWeight: 500 }}>
          Watch the full lifecycle: two LPs enter the same pool, the market moves,
          Reactive detects the shift, and the vault settles Bob&apos;s claim while
          Alice eats the loss. Run all three scenarios.
        </p>
      </header>

      <ScenarioRunner />
    </div>
  );
}
