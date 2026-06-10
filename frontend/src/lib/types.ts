import type { Address, Hex } from "viem";
import type { RiskTier, PolicyStatus } from "@/lib/format";

// Mirrors IIndemnifiHook.Policy (see contracts/src/interfaces/IIndemnifiHook.sol).
export interface Policy {
  owner: Address;
  poolId: Hex;
  token: Address;
  notional: bigint;
  entryPrice: bigint;
  thresholdBps: bigint;
  maxPayout: bigint;
  premiumPaid: bigint;
  createdAt: bigint;
  expiry: bigint;
  status: PolicyStatus;
}

// Tuple shape returned by hook.getPolicy (struct order).
export type PolicyTuple = readonly [
  Address, // owner
  Hex, // poolId
  Address, // token
  bigint, // notional
  bigint, // entryPrice
  bigint, // thresholdBps
  bigint, // maxPayout
  bigint, // premiumPaid
  bigint, // createdAt
  bigint, // expiry
  number, // status
];

export function toPolicy(t: PolicyTuple): Policy {
  return {
    owner: t[0],
    poolId: t[1],
    token: t[2],
    notional: t[3],
    entryPrice: t[4],
    thresholdBps: t[5],
    maxPayout: t[6],
    premiumPaid: t[7],
    createdAt: t[8],
    expiry: t[9],
    status: t[10] as PolicyStatus,
  };
}

// Mirrors DemoScenarioRunner.RunResult.
export interface RunResult {
  scenario: number;
  aliceIL: bigint;
  aliceFinalLoss: bigint;
  bobIL: bigint;
  bobPayout: bigint;
  bobPremium: bigint;
  bobFinalLoss: bigint;
  bobAdvantage: bigint;
  vaultBalance: bigint;
  vaultSolvencyBps: bigint;
  coveragePaused: boolean;
}

export interface VaultState {
  totalAssets: bigint;
  solvencyBps: bigint;
  totalPremiums: bigint;
  totalClaimsPaid: bigint;
  totalYieldEarned: bigint;
  availableForClaims: bigint;
}

export type { RiskTier, PolicyStatus };
