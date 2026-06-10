interface Cell {
  label: string;
  value: string;
  accent?: boolean;
}

/** Full-width 3-column stats grid, border-separated cells. */
export function StatsBar({ cells }: { cells: Cell[] }) {
  return (
    <section className="border-y border-border">
      <div className="mx-auto grid max-w-7xl grid-cols-1 sm:grid-cols-3">
        {cells.map((c, i) => (
          <div
            key={c.label}
            className="px-7 py-8 text-center"
            style={{
              borderRight:
                i < cells.length - 1 ? "1px solid var(--border)" : undefined,
            }}
          >
            <div
              className="uppercase text-text-muted"
              style={{ fontSize: 11, fontWeight: 700, letterSpacing: "0.08em" }}
            >
              {c.label}
            </div>
            <div
              className="tnum mt-2 text-white"
              style={{
                fontSize: 40,
                fontWeight: 900,
                letterSpacing: "-0.03em",
                color: c.accent ? "var(--accent)" : undefined,
              }}
            >
              {c.value}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
