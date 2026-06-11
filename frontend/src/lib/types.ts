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

type PolicyStruct = PolicyTuple | Policy;

function field<T>(value: PolicyStruct, index: number, key: keyof Policy): T {
  if (Array.isArray(value)) return value[index] as T;
  return (value as Policy)[key] as T;
}

export function toPolicy(t: PolicyStruct): Policy {
  return {
    owner: field<Address>(t, 0, "owner"),
    poolId: field<Hex>(t, 1, "poolId"),
    token: field<Address>(t, 2, "token"),
    notional: field<bigint>(t, 3, "notional"),
    entryPrice: field<bigint>(t, 4, "entryPrice"),
    thresholdBps: field<bigint>(t, 5, "thresholdBps"),
    maxPayout: field<bigint>(t, 6, "maxPayout"),
    premiumPaid: field<bigint>(t, 7, "premiumPaid"),
    createdAt: field<bigint>(t, 8, "createdAt"),
    expiry: field<bigint>(t, 9, "expiry"),
    status: field<PolicyStatus>(t, 10, "status"),
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
