export function AnnouncementBanner() {
  return (
    <div className="w-full bg-accent text-white">
      <div className="mx-auto flex max-w-7xl items-center justify-center gap-2 px-7 py-2 text-center">
        <span className="pulse-dot h-1.5 w-1.5 rounded-full bg-white/80" />
        <span
          className="text-xs font-bold"
          style={{ letterSpacing: "0.03em" }}
        >
          Live on Unichain Sepolia × Reactive Lasna — IL insurance for v4 LPs
        </span>
      </div>
    </div>
  );
}
