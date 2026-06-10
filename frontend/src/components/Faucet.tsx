"use client";

import { useCallback, useState } from "react";
import {
  useAccount,
  useChainId,
  usePublicClient,
  useReadContract,
  useSwitchChain,
  useWriteContract,
} from "wagmi";
import { isAddress, zeroAddress } from "viem";
import { toast } from "sonner";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { faucetTokenAbi } from "@/abis/faucet";
import { addresses, CHAIN_ID } from "@/lib/contracts";
import { fmtToken } from "@/lib/format";

// A usable token address must be a real, non-zero address. If env vars failed
// to load (stale build cache, missing .env.local), addresses fall back to the
// zero address — sending a tx there would fail, so we block it up front.
function isUsableToken(token: `0x${string}`): boolean {
  return isAddress(token) && token.toLowerCase() !== zeroAddress;
}

function TokenRow({
  token,
  symbol,
  decimals,
}: {
  token: `0x${string}`;
  symbol: string;
  decimals: number;
}) {
  const { address } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient({ chainId: CHAIN_ID });
  const { switchChainAsync } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();
  const [busy, setBusy] = useState(false);

  const balance = useReadContract({
    address: token,
    abi: faucetTokenAbi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    chainId: CHAIN_ID,
    query: { enabled: !!address, refetchInterval: 10_000 },
  });

  const claim = useCallback(async () => {
    if (!address || !publicClient) {
      toast.error("Connect your wallet first");
      return;
    }
    if (!isUsableToken(token)) {
      toast.error(
        `${symbol} address not configured — hard-refresh the page (Cmd/Ctrl+Shift+R). Contract addresses failed to load.`,
        { id: token },
      );
      return;
    }
    try {
      setBusy(true);
      if (chainId !== CHAIN_ID) await switchChainAsync({ chainId: CHAIN_ID });
      const hash = await writeContractAsync({
        address: token,
        abi: faucetTokenAbi,
        functionName: "faucet",
        chainId: CHAIN_ID,
      });
      toast.loading(`Claiming ${symbol}…`, { id: token });
      await publicClient.waitForTransactionReceipt({ hash });
      toast.success(`Claimed ${symbol}`, { id: token });
      balance.refetch();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Claim failed";
      toast.error(msg.includes("CooldownActive") ? `${symbol} faucet on cooldown` : msg.slice(0, 100), {
        id: token,
      });
    } finally {
      setBusy(false);
    }
  }, [address, chainId, switchChainAsync, publicClient, writeContractAsync, token, symbol, balance]);

  return (
    <div className="flex items-center justify-between rounded-[14px] border border-border bg-bg px-4 py-3">
      <div>
        <div className="text-white" style={{ fontSize: 15, fontWeight: 800 }}>
          {symbol}
        </div>
        <div className="tnum text-text-muted" style={{ fontSize: 12, fontWeight: 600 }}>
          balance {fmtToken((balance.data as bigint) ?? 0n, decimals, "")}
        </div>
      </div>
      <Button
        size="sm"
        onClick={claim}
        loading={busy}
        disabled={!address || !isUsableToken(token)}
      >
        Claim
      </Button>
    </div>
  );
}

export function Faucet() {
  return (
    <Card title="Test faucet" subtitle="Claim test tokens to interact with the live contracts">
      <div className="flex flex-col gap-3">
        <TokenRow token={addresses.weth} symbol="WETH" decimals={18} />
        <TokenRow token={addresses.usdc} symbol="USDC" decimals={6} />
      </div>
      <p className="mt-4 text-text-muted" style={{ fontSize: 12, fontWeight: 500 }}>
        Premiums are paid in WETH. Faucet has an 8-hour cooldown per token.
      </p>
    </Card>
  );
}
