import Link from "next/link";

const footerLinks = [
  { href: "/app", label: "Protect" },
  { href: "/demo", label: "Demo" },
  { href: "/vault", label: "Vault" },
  { href: "https://dev.reactive.network", label: "Reactive" },
];

export function Footer() {
  return (
    <footer className="border-t border-border">
      <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-4 px-7 py-8 sm:flex-row">
        <span
          className="text-text-muted"
          style={{ fontWeight: 800 }}
        >
          Indemni<span className="text-accent">fi</span>
        </span>
        <nav className="flex items-center gap-5">
          {footerLinks.map((l) => (
            <Link
              key={l.label}
              href={l.href}
              className="text-text-muted transition-all duration-150 hover:text-white/70"
              style={{ fontSize: 13, fontWeight: 600 }}
            >
              {l.label}
            </Link>
          ))}
        </nav>
      </div>
    </footer>
  );
}
