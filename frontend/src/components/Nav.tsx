"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { NetworkBadge } from "@/components/NetworkBadge";
import { cn } from "@/lib/cn";

const links = [
  { href: "/", label: "Dashboard" },
  { href: "/app", label: "Protect" },
  { href: "/demo", label: "Demo" },
  { href: "/vault", label: "Vault" },
];

export function Nav() {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-40 border-b border-border bg-bg">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-7">
        <Link
          href="/"
          className="text-xl text-white"
          style={{ fontWeight: 900, letterSpacing: "-0.02em" }}
        >
          Indemni<span className="text-accent">fi</span>
        </Link>

        <nav className="hidden items-center gap-1 md:flex">
          {links.map((l) => {
            const active = pathname === l.href;
            return (
              <Link
                key={l.href}
                href={l.href}
                className={cn(
                  "rounded-[20px] px-3 py-2 transition-all duration-150 hover:bg-white/8",
                  active ? "text-white" : "text-text-2 hover:text-white",
                )}
                style={{ fontSize: 13, fontWeight: 700 }}
              >
                {l.label}
              </Link>
            );
          })}
        </nav>

        <div className="flex items-center gap-2">
          <NetworkBadge />
          <ConnectButton
            accountStatus="address"
            chainStatus="none"
            showBalance={false}
          />
        </div>
      </div>
    </header>
  );
}
