import type { Metadata } from "next";
import { DM_Sans } from "next/font/google";
import "./globals.css";
import { Providers } from "@/providers";
import { AnnouncementBanner } from "@/components/AnnouncementBanner";
import { NetworkGuard } from "@/components/NetworkGuard";
import { Nav } from "@/components/Nav";
import { Footer } from "@/components/Footer";

const dmSans = DM_Sans({
  variable: "--font-dm-sans",
  subsets: ["latin"],
  weight: ["500", "700", "800", "900"],
});

export const metadata: Metadata = {
  title: "Indemnifi — IL Insurance for Uniswap v4 LPs",
  description:
    "Indemnifi lets LPs buy explicit impermanent-loss protection. Premiums pool into a yield-earning vault. Reactive Network automates risk monitoring and claim settlement.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className={dmSans.variable}>
        <Providers>
          <AnnouncementBanner />
          <NetworkGuard />
          <Nav />
          <main>{children}</main>
          <Footer />
        </Providers>
      </body>
    </html>
  );
}
