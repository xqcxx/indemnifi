"use client";

import "@rainbow-me/rainbowkit/styles.css";
import { ReactNode, useState } from "react";
import { WagmiProvider } from "wagmi";
import { http } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import {
  RainbowKitProvider,
  getDefaultConfig,
  darkTheme,
} from "@rainbow-me/rainbowkit";
import { Toaster } from "sonner";
import { unichainSepolia, reactiveLasna } from "@/lib/chains";
import { WALLETCONNECT_PROJECT_ID } from "@/lib/contracts";

const config = getDefaultConfig({
  appName: "Indemnifi",
  projectId: WALLETCONNECT_PROJECT_ID,
  chains: [unichainSepolia, reactiveLasna],
  transports: {
    [unichainSepolia.id]: http("https://sepolia.unichain.org"),
    [reactiveLasna.id]: http("https://lasna-rpc.rnk.dev/"),
  },
  ssr: true,
});

export function Providers({ children }: { children: ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider
          theme={darkTheme({
            accentColor: "#fb27ce",
            accentColorForeground: "#ffffff",
            borderRadius: "large",
            fontStack: "system",
          })}
        >
          {children}
          <Toaster
            theme="dark"
            position="bottom-right"
            toastOptions={{
              style: {
                background: "#111111",
                border: "1px solid rgba(255,255,255,0.08)",
                color: "#ffffff",
                fontWeight: 600,
              },
            }}
          />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
