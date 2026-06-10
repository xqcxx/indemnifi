import Link from "next/link";

export function CTABand() {
  return (
    <div className="mx-7">
      <div className="flex flex-col items-start justify-between gap-6 rounded-[20px] bg-accent px-9 py-11 sm:flex-row sm:items-center">
        <div>
          <h3
            className="text-white"
            style={{ fontSize: 28, fontWeight: 900, letterSpacing: "-0.02em" }}
          >
            Protect your next position.
          </h3>
          <p
            className="mt-1 text-white/70"
            style={{ fontSize: 14, fontWeight: 500 }}
          >
            Buy IL coverage in one transaction. Premiums earn yield while you’re covered.
          </p>
        </div>
        <Link href="/app" className="btn-white px-6 py-3 text-sm">
          Open the app
        </Link>
      </div>
    </div>
  );
}
